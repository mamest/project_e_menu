import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_menu_parser.dart';
import '../services/geocoding_service.dart';
import '../services/unsplash_service.dart';
import '../services/auth_service.dart';
import '../models/restaurant.dart';
import 'edit_restaurant_page.dart';
import 'dart:math';

class AdminUploadPage extends StatefulWidget {
  const AdminUploadPage({super.key});

  @override
  State<AdminUploadPage> createState() => _AdminUploadPageState();
}

class _AdminUploadPageState extends State<AdminUploadPage> {
  Uint8List? _pdfBytes;
  String? _fileName;
  bool _isProcessing = false;
  bool _isUploading = false;
  MenuData? _extractedData;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  // Editable menu data stored separately from immutable extracted data
  Map<int, Map<String, dynamic>> _editedCategories = {};
  Map<int, Map<int, Map<String, dynamic>>> _editedItems = {}; // categoryIndex -> itemIndex -> data
  Map<int, Map<int, List<Map<String, dynamic>>>> _editedVariants = {}; // categoryIndex -> itemIndex -> variants

  // Form controllers for editing extracted data
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cuisineTypeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _cuisineTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pdfBytes = file.bytes;
          _fileName = file.name;
          _extractedData = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _processWithAI() async {
    if (_pdfBytes == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final parser = AiMenuParser();
      final menuData = await parser.parseMenuPdf(_pdfBytes!, _fileName!);
      
      setState(() {
        _extractedData = menuData;
        _isProcessing = false;
        
        // Populate form controllers with extracted data
        _nameController.text = menuData.restaurant.name;
        _addressController.text = menuData.restaurant.address;
        _phoneController.text = menuData.restaurant.phone ?? '';
        _emailController.text = menuData.restaurant.email ?? '';
        _descriptionController.text = menuData.restaurant.description ?? '';
        _cuisineTypeController.text = menuData.restaurant.cuisineType ?? '';
        
        // Clear any previous edits
        _editedCategories.clear();
        _editedItems.clear();
        _editedVariants.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu extracted successfully! Review and save to database.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing menu: $e';
        _isProcessing = false;
      });
    }
  }

  // Check for duplicate restaurants within 50 meters
  Future<List<Restaurant>> _checkForDuplicates(double lat, double lon) async {
    final supabase = Supabase.instance.client;
    
    // Calculate bounding box for approximate search (50 meters ~ 0.00045 degrees)
    const radiusInDegrees = 0.00045; // approximately 50 meters
    final minLat = lat - radiusInDegrees;
    final maxLat = lat + radiusInDegrees;
    final minLon = lon - radiusInDegrees;
    final maxLon = lon + radiusInDegrees;

    final response = await supabase
        .from('restaurants')
        .select()
        .gte('latitude', minLat)
        .lte('latitude', maxLat)
        .gte('longitude', minLon)
        .lte('longitude', maxLon);

    final restaurants = (response as List)
        .map((json) => Restaurant.fromJson(json))
        .toList();

    // Filter by exact distance using Haversine formula
    final nearbyRestaurants = restaurants.where((restaurant) {
      final distance = _calculateDistance(lat, lon, restaurant.latitude!, restaurant.longitude!);
      return distance <= 0.05; // 50 meters in km
    }).toList();

    return nearbyRestaurants;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _saveToDatabase() async {
    if (_extractedData == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Geocode the address to get latitude and longitude (use edited address)
      print('Geocoding address: ${_addressController.text.trim()}');
      final coordinates = await GeocodingService.geocodeAddress(
        _addressController.text.trim(),
      );
      final latitude = coordinates?['latitude'];
      final longitude = coordinates?['longitude'];
      print('Geocoded: lat=$latitude, lon=$longitude');

      // Check for duplicate restaurants at this location
      if (latitude != null && longitude != null) {
        final duplicates = await _checkForDuplicates(latitude, longitude);
        if (duplicates.isNotEmpty && mounted) {
          setState(() {
            _isUploading = false;
          });

          // Check if user owns any of the duplicates
          final currentUserId = supabase.auth.currentUser?.id;
          final ownedDuplicates = duplicates
              .where((r) => r.restaurantOwnerUuid == currentUserId)
              .toList();

          if (ownedDuplicates.isEmpty) {
            // User doesn't own any duplicate - only allow cancel
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Restaurant Already Exists'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A restaurant already exists at this location:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...duplicates.map((restaurant) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                restaurant.address,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                    const Text(
                      'You don\'t have permission to edit this restaurant.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return; // Stop the upload process
          }

          // User owns duplicate - allow edit or update menu
          final action = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Your Restaurant Already Exists'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You already have a restaurant at this location:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...ownedDuplicates.map((restaurant) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              restaurant.address,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  const Text('What would you like to do?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'update'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Update Menu from PDF'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Edit Restaurant Info'),
                ),
              ],
            ),
          );

          if (action == 'cancel' || action == null) {
            return; // User cancelled
          } else if (action == 'edit') {
            // Navigate to edit page for the owned duplicate
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRestaurantPage(restaurant: ownedDuplicates.first),
                ),
              );
            }
            return;
          } else if (action == 'update') {
            // Update the existing restaurant's menu with new data
            await _updateExistingMenu(ownedDuplicates.first.id);
            return;
          }
        }
      }

      // Fetch restaurant image from Unsplash (use edited cuisine type)
      final cuisineType = _cuisineTypeController.text.trim();
      print('Fetching image for cuisine: $cuisineType');
      final imageUrl = await UnsplashService.getRestaurantImage(
        cuisineType.isEmpty ? 'restaurant' : cuisineType,
      );
      print('Image URL: $imageUrl');

      // Get the current user's UUID
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to create a restaurant');
      }

      // Insert restaurant (using edited values from controllers)
      final restaurantResponse = await supabase
          .from('restaurants')
          .insert({
            'name': _nameController.text.trim(),
            'address': _addressController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            'cuisine_type': _cuisineTypeController.text.trim().isEmpty ? null : _cuisineTypeController.text.trim(),
            'delivers': _extractedData!.restaurant.delivers,
            'opening_hours': _extractedData!.restaurant.openingHours,
            'payment_methods': _extractedData!.restaurant.paymentMethods,
            'latitude': latitude,
            'longitude': longitude,
            'image_url': imageUrl,
            'restaurant_owner_uuid': currentUser.id,
          })
          .select('id')
          .single();

      final restaurantId = restaurantResponse['id'] as int;

      // Insert categories and items (using edited values where available)
      for (int catIndex = 0; catIndex < _extractedData!.categories.length; catIndex++) {
        final category = _extractedData!.categories[catIndex];
        final categoryResponse = await supabase
            .from('categories')
            .insert({
              'restaurant_id': restaurantId,
              'name': _getCategoryName(catIndex),
              'display_order': category.displayOrder,
            })
            .select('id')
            .single();

        final categoryId = categoryResponse['id'] as int;

        // Insert items
        for (int itemIndex = 0; itemIndex < category.items.length; itemIndex++) {
          final item = category.items[itemIndex];
          final itemResponse = await supabase
              .from('items')
              .insert({
                'category_id': categoryId,
                'name': _getItemName(catIndex, itemIndex),
                'item_number': item.itemNumber ?? '${itemIndex + 1}',
                'price': _getItemPrice(catIndex, itemIndex),
                'description': _getItemDescription(catIndex, itemIndex),
                'available': true,
                'has_variants': item.hasVariants,
              })
              .select('id')
              .single();

          final itemId = itemResponse['id'] as int;

          // Insert variants if present
          if (item.hasVariants && item.variants != null) {
            for (final variant in item.variants!) {
              await supabase.from('item_variants').insert({
                'item_id': itemId,
                'name': variant.name,
                'price': variant.price,
                'display_order': variant.displayOrder,
                'available': true,
              });
            }
          }
        }
      }

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restaurant "${_nameController.text.trim()}" saved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear state and go back
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving to database: $e';
        _isUploading = false;
      });
    }
  }

  Future<void> _updateExistingMenu(int restaurantId) async {
    if (_extractedData == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // First, delete all existing categories and their items for this restaurant
      // (cascading delete should handle items, item_variants)
      await supabase
          .from('categories')
          .delete()
          .eq('restaurant_id', restaurantId);

      // Insert new categories and items from the PDF (using edited values where available)
      for (int catIndex = 0; catIndex < _extractedData!.categories.length; catIndex++) {
        final category = _extractedData!.categories[catIndex];
        final categoryResponse = await supabase
            .from('categories')
            .insert({
              'restaurant_id': restaurantId,
              'name': _getCategoryName(catIndex),
              'display_order': category.displayOrder,
            })
            .select('id')
            .single();

        final categoryId = categoryResponse['id'] as int;

        // Insert items
        for (int itemIndex = 0; itemIndex < category.items.length; itemIndex++) {
          final item = category.items[itemIndex];
          final itemResponse = await supabase
              .from('items')
              .insert({
                'category_id': categoryId,
                'name': _getItemName(catIndex, itemIndex),
                'item_number': item.itemNumber ?? '${itemIndex + 1}',
                'price': _getItemPrice(catIndex, itemIndex),
                'description': _getItemDescription(catIndex, itemIndex),
                'available': true,
                'has_variants': item.hasVariants,
              })
              .select('id')
              .single();

          final itemId = itemResponse['id'] as int;

          // Insert variants if present
          if (item.hasVariants && item.variants != null) {
            for (final variant in item.variants!) {
              await supabase.from('item_variants').insert({
                'item_id': itemId,
                'name': variant.name,
                'price': variant.price,
                'display_order': variant.displayOrder,
                'available': true,
              });
            }
          }
        }
      }

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu updated successfully with new data from PDF!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear state and go back
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating menu: $e';
        _isUploading = false;
      });
    }
  }

  // Get the effective value (edited or original) for category
  String _getCategoryName(int categoryIndex) {
    return _editedCategories[categoryIndex]?['name'] ??
        _extractedData!.categories[categoryIndex].name;
  }

  // Get the effective value (edited or original) for item
  String _getItemName(int categoryIndex, int itemIndex) {
    return _editedItems[categoryIndex]?[itemIndex]?['name'] ??
        _extractedData!.categories[categoryIndex].items[itemIndex].name;
  }

  double? _getItemPrice(int categoryIndex, int itemIndex) {
    return _editedItems[categoryIndex]?[itemIndex]?['price'] ??
        _extractedData!.categories[categoryIndex].items[itemIndex].price;
  }

  String? _getItemDescription(int categoryIndex, int itemIndex) {
    return _editedItems[categoryIndex]?[itemIndex]?['description'] ??
        _extractedData!.categories[categoryIndex].items[itemIndex].description;
  }

  // Edit category dialog
  Future<void> _editCategory(int categoryIndex) async {
    final controller = TextEditingController(text: _getCategoryName(categoryIndex));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _editedCategories[categoryIndex] = {'name': result};
      });
    }
    controller.dispose();
  }

  // Edit item dialog
  Future<void> _editItem(int categoryIndex, int itemIndex) async {
    final item = _extractedData!.categories[categoryIndex].items[itemIndex];
    final nameController = TextEditingController(text: _getItemName(categoryIndex, itemIndex));
    final priceController = TextEditingController(
      text: _getItemPrice(categoryIndex, itemIndex)?.toStringAsFixed(2) ?? '',
    );
    final descController = TextEditingController(text: _getItemDescription(categoryIndex, itemIndex) ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!item.hasVariants)
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                    prefixText: '€',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        if (_editedItems[categoryIndex] == null) {
          _editedItems[categoryIndex] = {};
        }
        _editedItems[categoryIndex]![itemIndex] = {
          'name': nameController.text,
          'price': priceController.text.isEmpty ? null : double.tryParse(priceController.text),
          'description': descController.text.isEmpty ? null : descController.text,
        };
      });
    }

    nameController.dispose();
    priceController.dispose();
    descController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    if (!_authService.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.teal,
          flexibleSpace: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    const Expanded(
                      child: Text(
                        'Upload Menu PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  'Authentication Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please sign in to upload menu PDFs',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        flexibleSpace: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  const Expanded(
                    child: Text(
                      'Upload Menu PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Upload a PDF menu\n'
                      '2. AI will extract restaurant info and menu items\n'
                      '3. Review the extracted data\n'
                      '4. Save to database',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // File picker button
            ElevatedButton.icon(
              onPressed: _isProcessing || _isUploading ? null : _pickPdfFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose PDF Menu'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),

            if (_fileName != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(_fileName!),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _pdfBytes = null;
                        _fileName = null;
                        _extractedData = null;
                        _editedCategories.clear();
                        _editedItems.clear();
                        _editedVariants.clear();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isProcessing || _isUploading ? null : _processWithAI,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isProcessing ? 'Processing with AI...' : 'Extract Menu with AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_extractedData != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Review and Edit Restaurant Information',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Tooltip(
                    message: 'Edit the AI-generated data before saving',
                    child: Icon(Icons.info_outline, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Editable Restaurant info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Restaurant Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.restaurant),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cuisineTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Cuisine Type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_dining),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Categories and items (editable)
              Row(
                children: [
                  Text(
                    'Menu Items (${_extractedData!.categories.length} categories)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Click the edit icons to modify menu items',
                    child: Icon(Icons.edit_outlined, size: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...(_extractedData!.categories.asMap().entries.map((categoryEntry) {
                final catIndex = categoryEntry.key;
                final category = categoryEntry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getCategoryName(catIndex),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editCategory(catIndex),
                          tooltip: 'Edit category name',
                        ),
                      ],
                    ),
                    subtitle: Text('${category.items.length} items'),
                    children: category.items.asMap().entries.map((itemEntry) {
                      final itemIndex = itemEntry.key;
                      final item = itemEntry.value;
                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(_getItemName(catIndex, itemIndex))),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editItem(catIndex, itemIndex),
                              tooltip: 'Edit item',
                            ),
                          ],
                        ),
                        subtitle: _getItemDescription(catIndex, itemIndex) != null
                            ? Text(_getItemDescription(catIndex, itemIndex)!)
                            : null,
                        trailing: item.hasVariants && item.variants != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: item.variants!
                                    .map((v) => Text(
                                          '${v.name}: €${v.price.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 12),
                                        ))
                                    .toList(),
                              )
                            : Text(
                                _getItemPrice(catIndex, itemIndex) != null
                                    ? '€${_getItemPrice(catIndex, itemIndex)!.toStringAsFixed(2)}'
                                    : '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      );
                    }).toList(),
                  ),
                );
              }).toList()),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _saveToDatabase,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isUploading ? 'Saving...' : 'Save to Database'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
          ),
        ),
      ),
    );
  }
}
