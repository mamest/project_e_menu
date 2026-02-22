import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../services/auth_service.dart';
import '../services/unsplash_service.dart';
import '../widgets/unsplash_picker_dialog.dart';

class EditRestaurantPage extends StatefulWidget {
  final Restaurant restaurant;

  const EditRestaurantPage({super.key, required this.restaurant});

  @override
  State<EditRestaurantPage> createState() => _EditRestaurantPageState();
}

class _EditRestaurantPageState extends State<EditRestaurantPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  static const List<String> _weekDays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  static const Map<String, String> _dayLabels = {
    'monday': 'Monday', 'tuesday': 'Tuesday', 'wednesday': 'Wednesday',
    'thursday': 'Thursday', 'friday': 'Friday', 'saturday': 'Saturday', 'sunday': 'Sunday',
  };
  static const List<String> _availablePaymentMethods = [
    'Cash', 'Card', 'EC-Karte', 'PayPal', 'Apple Pay', 'Google Pay', 'Invoice',
  ];

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _descriptionController;
  late TextEditingController _cuisineTypeController;
  late bool _delivers;
  String? _imageUrl;
  Map<String, String> _openingHours = {};
  final Map<String, TextEditingController> _hoursControllers = {};
  List<String> _paymentMethods = [];

  List<MenuCategory> _categories = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.restaurant.name);
    _addressController = TextEditingController(text: widget.restaurant.address);
    _phoneController = TextEditingController(text: widget.restaurant.phone ?? '');
    _emailController = TextEditingController(text: widget.restaurant.email ?? '');
    _descriptionController = TextEditingController(text: widget.restaurant.description ?? '');
    _cuisineTypeController = TextEditingController(text: widget.restaurant.cuisineType ?? '');
    _delivers = widget.restaurant.delivers;
    _imageUrl = widget.restaurant.imageUrl;
    // Opening hours
    final oh = widget.restaurant.openingHours;
    for (final day in _weekDays) {
      final val = oh?[day]?.toString() ?? 'closed';
      _openingHours[day] = val;
      _hoursControllers[day] = TextEditingController(text: val == 'closed' ? '' : val);
    }
    // Payment methods
    _paymentMethods = List<String>.from(widget.restaurant.paymentMethods ?? []);
    _loadMenuData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _cuisineTypeController.dispose();
    for (final c in _hoursControllers.values) c.dispose();
    super.dispose();
  }

  // Natural sort comparison for item numbers (handles "1", "2", "10", "1a", "2b" etc.)
  int _compareItemNumbers(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    // Extract numeric prefix and suffix
    final aMatch = RegExp(r'^(\d+)(.*)$').firstMatch(a);
    final bMatch = RegExp(r'^(\d+)(.*)$').firstMatch(b);

    if (aMatch != null && bMatch != null) {
      final aNum = int.parse(aMatch.group(1)!);
      final bNum = int.parse(bMatch.group(1)!);
      
      if (aNum != bNum) {
        return aNum.compareTo(bNum);
      }
      
      // If numbers are equal, compare suffixes
      final aSuffix = aMatch.group(2) ?? '';
      final bSuffix = bMatch.group(2) ?? '';
      return aSuffix.compareTo(bSuffix);
    }

    // Fallback to string comparison
    return a.compareTo(b);
  }

  Future<void> _loadMenuData() async {
    try {
      // Load categories
      final categoriesData = await _supabase
          .from('categories')
          .select('id, name, display_order, image_url')
          .eq('restaurant_id', widget.restaurant.id)
          .order('display_order');

      List<MenuCategory> categories = [];
      for (var catData in categoriesData) {
        // Load items for this category
        final itemsData = await _supabase
            .from('items')
            .select('id, name, item_number, price, description, has_variants, available')
            .eq('category_id', catData['id'])
            .order('id');

        List<MenuItem> items = (itemsData as List).map<MenuItem>((itemData) {
          return MenuItem(
            id: itemData['id'] as int,
            name: itemData['name'] as String,
            itemNumber: itemData['item_number'] as String?,
            price: itemData['price'] != null ? (itemData['price'] as num).toDouble() : null,
            description: itemData['description'] as String?,
            hasVariants: itemData['has_variants'] as bool? ?? false,
            available: itemData['available'] as bool? ?? true,
          );
        }).toList();
        // Sort items by item_number
        items.sort((a, b) => _compareItemNumbers(a.itemNumber, b.itemNumber));

        categories.add(MenuCategory(
          id: catData['id'] as int,
          name: catData['name'] as String,
          displayOrder: catData['display_order'] as int? ?? 0,
          items: items,
          imageUrl: catData['image_url'] as String?,
        ));
      }

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading menu data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRestaurantInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _supabase.from('restaurants').update({
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
        'cuisine_type': _cuisineTypeController.text.isEmpty ? null : _cuisineTypeController.text,
        'delivers': _delivers,
        'image_url': _imageUrl,
        'opening_hours': _openingHours.isEmpty ? null : Map<String, dynamic>.from(_openingHours),
        'payment_methods': _paymentMethods.isEmpty ? null : _paymentMethods,
      }).eq('id', widget.restaurant.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restaurant information updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Appetizers, Main Dishes',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final response = await _supabase.from('categories').insert({
          'restaurant_id': widget.restaurant.id,
          'name': nameController.text,
          'display_order': _categories.length,
        }).select().single();

        setState(() {
          _categories.add(MenuCategory(
            id: response['id'],
            name: response['name'],
            displayOrder: response['display_order'] ?? 0,
            items: [],
            imageUrl: null,
          ));
        });

        // Auto-suggest a category image in the background
        final catName = nameController.text;
        UnsplashService.getCategoryImage(catName).then((url) {
          if (url != null && mounted) {
            _supabase.from('categories').update({'image_url': url}).eq('id', response['id']);
            setState(() {
              final idx = _categories.indexWhere((c) => c.id == response['id']);
              if (idx >= 0) _categories[idx].imageUrl = url;
            });
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category added!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _addItem(MenuCategory category) async {
    final nameController = TextEditingController();
    final itemNumberController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Item to ${category.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemNumberController,
                decoration: const InputDecoration(
                  labelText: 'Item Number',
                  helperText: 'e.g., 1, 2a, 3b',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '€ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final price = double.tryParse(priceController.text);
        final response = await _supabase.from('items').insert({
          'category_id': category.id,
          'name': nameController.text,
          'item_number': itemNumberController.text.isEmpty ? null : itemNumberController.text,
          'price': price,
          'description': descController.text.isEmpty ? null : descController.text,
          'available': true,
          'has_variants': false,
        }).select().single();

        setState(() {
          category.items.add(MenuItem(
            id: response['id'],
            name: response['name'],
            itemNumber: response['item_number'] as String?,
            price: response['price']?.toDouble(),
            description: response['description'],
            available: response['available'] ?? true,
            hasVariants: false,
          ));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item added!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _editCategory(MenuCategory category) async {
    final nameController = TextEditingController(text: category.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Appetizers, Main Dishes',
          ),
          autofocus: true,
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

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await _supabase.from('categories').update({
          'name': nameController.text,
        }).eq('id', category.id);

        setState(() {
          final index = _categories.indexOf(category);
          _categories[index] = MenuCategory(
            id: category.id,
            name: nameController.text,
            displayOrder: category.displayOrder,
            items: category.items,
            imageUrl: category.imageUrl,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category updated!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}" and all its items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('categories').delete().eq('id', category.id);
        setState(() {
          _categories.remove(category);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(MenuCategory category, MenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('items').delete().eq('id', item.id);
        setState(() {
          category.items.remove(item);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _editItem(MenuCategory category, MenuItem item) async {
    final nameController = TextEditingController(text: item.name);
    final itemNumberController = TextEditingController(text: item.itemNumber ?? '');
    final priceController = TextEditingController(
      text: item.price?.toStringAsFixed(2) ?? '',
    );
    final descController = TextEditingController(text: item.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit: ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemNumberController,
                decoration: const InputDecoration(
                  labelText: 'Item Number',
                  helperText: 'e.g., 1, 2a, 3b',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '€ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
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

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final price = priceController.text.isEmpty 
            ? null 
            : double.tryParse(priceController.text);
        
        await _supabase.from('items').update({
          'name': nameController.text,
          'item_number': itemNumberController.text.isEmpty ? null : itemNumberController.text,
          'price': price,
          'description': descController.text.isEmpty ? null : descController.text,
        }).eq('id', item.id);

        setState(() {
          final index = category.items.indexOf(item);
          category.items[index] = MenuItem(
            id: item.id,
            name: nameController.text,
            itemNumber: itemNumberController.text.isEmpty ? null : itemNumberController.text,
            price: price,
            description: descController.text.isEmpty ? null : descController.text,
            available: item.available,
            hasVariants: item.hasVariants,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleItemAvailability(MenuItem item) async {
    try {
      final newAvailability = !item.available;
      await _supabase.from('items').update({
        'available': newAvailability,
      }).eq('id', item.id);

      setState(() {
        item.available = newAvailability;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is the owner
    final isOwner = _authService.currentUser?.id == widget.restaurant.restaurantOwnerUuid;

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Restaurant'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'You do not have permission to edit this restaurant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
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
        flexibleSpace: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                const BackButton(color: Colors.white),
                Expanded(
                  child: Text(
                    'Edit: ${widget.restaurant.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: const TabBar(
                        labelColor: Colors.teal,
                        tabs: [
                          Tab(icon: Icon(Icons.info_outline), text: 'Restaurant Info'),
                          Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: TabBarView(
                          children: [
                            _buildRestaurantInfoTab(),
                            _buildMenuTab(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _openUnsplashPicker() async {
    final query = '${_cuisineTypeController.text.trim()} food restaurant'.trim();
    final picked = await UnsplashPickerDialog.show(context, initialQuery: query.isEmpty ? 'restaurant food' : query);
    if (picked != null && mounted) setState(() => _imageUrl = picked);
  }

  Future<void> _autoSuggestImage() async {
    final query = '${_cuisineTypeController.text.trim()} food restaurant'.trim();
    setState(() => _isSaving = true);
    final url = await UnsplashService.getRestaurantImage(query.isEmpty ? 'restaurant food' : query);
    if (mounted) setState(() { _imageUrl = url; _isSaving = false; });
  }

  Widget _buildEditImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Restaurant Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: _autoSuggestImage,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Auto-suggest'),
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: _openUnsplashPicker,
              icon: const Icon(Icons.image_search, size: 16),
              label: const Text('Browse Unsplash'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_imageUrl != null && _imageUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(height: 160, color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (_, __, ___) => Container(
                height: 160, color: Colors.grey[200],
                child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
              ),
            ),
          )
        else
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 6),
                  Text('No photo — tap "Auto-suggest" or "Browse Unsplash"',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRestaurantInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red[800])),
              ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Restaurant Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cuisineTypeController,
              decoration: const InputDecoration(
                labelText: 'Cuisine Type',
                border: OutlineInputBorder(),
                hintText: 'e.g., Italian, Chinese, Mexican',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Offers Delivery'),
              value: _delivers,
              onChanged: (value) => setState(() => _delivers = value),
              activeColor: Colors.teal,
            ),
            const SizedBox(height: 16),
            _buildOpeningHoursSection(),
            const SizedBox(height: 16),
            _buildPaymentMethodsSection(),
            const SizedBox(height: 16),
            _buildEditImageSection(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRestaurantInfo,
              icon: const Icon(Icons.save),
              label: const Text('Save Restaurant Info'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpeningHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Opening Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _weekDays.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final isOpen = (_openingHours[day] ?? 'closed') != 'closed';
              return Column(
                children: [
                  if (i > 0) Divider(height: 1, color: Colors.grey[200]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(_dayLabels[day]!, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        Switch(
                          value: isOpen,
                          onChanged: (v) => setState(() {
                            if (v) {
                              _openingHours[day] = '09:00–22:00';
                              _hoursControllers[day]!.text = '09:00–22:00';
                            } else {
                              _openingHours[day] = 'closed';
                              _hoursControllers[day]!.text = '';
                            }
                          }),
                          activeColor: Colors.teal,
                        ),
                        const SizedBox(width: 8),
                        if (isOpen)
                          Expanded(
                            child: TextFormField(
                              controller: _hoursControllers[day],
                              decoration: const InputDecoration(
                                hintText: '09:00–22:00',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              onChanged: (v) => _openingHours[day] = v,
                            ),
                          )
                        else
                          const Expanded(
                            child: Text('Closed', style: TextStyle(color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _availablePaymentMethods.map((method) {
            final selected = _paymentMethods.contains(method);
            return FilterChip(
              label: Text(method),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _paymentMethods.add(method);
                } else {
                  _paymentMethods.remove(method);
                }
              }),
              selectedColor: Colors.teal.withOpacity(0.2),
              checkmarkColor: Colors.teal,
              labelStyle: TextStyle(
                color: selected ? Colors.teal[800] : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pickCategoryImage(MenuCategory category) async {
    final picked = await UnsplashPickerDialog.show(
      context,
      initialQuery: 'food ${category.name}',
    );
    if (picked != null && mounted) {
      try {
        await _supabase.from('categories').update({'image_url': picked}).eq('id', category.id);
        setState(() => category.imageUrl = picked);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildMenuTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _categories.isEmpty
              ? const Center(
                  child: Text(
                    'No categories yet. Add one to get started!',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            // Category image thumbnail
                            if (category.imageUrl != null && category.imageUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    category.imageUrl!,
                                    width: 40,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text('${category.items.length} items'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image_search, color: Colors.teal),
                              onPressed: () => _pickCategoryImage(category),
                              tooltip: 'Change category photo',
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.green),
                              onPressed: () => _addItem(category),
                              tooltip: 'Add item',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editCategory(category),
                              tooltip: 'Edit category',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(category),
                              tooltip: 'Delete category',
                            ),
                          ],
                        ),
                        children: category.items.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No items in this category',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ]
                            : category.items.map((item) {
                                return ListTile(
                                  leading: Checkbox(
                                    value: item.available,
                                    onChanged: (_) => _toggleItemAvailability(item),
                                    activeColor: Colors.teal,
                                  ),
                                  title: Row(
                                    children: [
                                      if (item.itemNumber != null && item.itemNumber!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            item.itemNumber!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal[700],
                                            ),
                                          ),
                                        ),
                                      Expanded(child: Text(item.name)),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (item.description != null)
                                        Text(item.description!),
                                      Text(
                                        item.price != null
                                            ? '€${item.price!.toStringAsFixed(2)}'
                                            : 'Price varies',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _editItem(category, item),
                                        tooltip: 'Edit item',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteItem(category, item),
                                        tooltip: 'Delete item',
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class MenuCategory {
  final int id;
  final String name;
  final int displayOrder;
  final List<MenuItem> items;
  String? imageUrl;

  MenuCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.items,
    this.imageUrl,
  });
}
