import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
import '../services/unsplash_service.dart';

class CreateRestaurantPage extends StatefulWidget {
  const CreateRestaurantPage({super.key});

  @override
  State<CreateRestaurantPage> createState() => _CreateRestaurantPageState();
}

class _CreateRestaurantPageState extends State<CreateRestaurantPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _errorMessage;

  // Restaurant info controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cuisineTypeController = TextEditingController();
  bool _delivers = false;

  // Categories and items structure
  List<CategoryData> _categories = [];

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

  void _addCategory() {
    setState(() {
      _categories.add(CategoryData(
        name: 'New Category ${_categories.length + 1}',
        items: [],
      ));
    });
  }

  void _removeCategory(int index) {
    setState(() {
      _categories.removeAt(index);
    });
  }

  void _editCategory(int index) async {
    final controller = TextEditingController(text: _categories[index].name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category Name'),
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
        _categories[index].name = result;
      });
    }
    controller.dispose();
  }

  void _addItem(int categoryIndex) {
    setState(() {
      final itemCount = _categories[categoryIndex].items.length + 1;
      _categories[categoryIndex].items.add(ItemData(
        name: 'New Item',
        itemNumber: '$itemCount',
        price: 0.0,
        description: '',
      ));
    });
  }

  void _removeItem(int categoryIndex, int itemIndex) {
    setState(() {
      _categories[categoryIndex].items.removeAt(itemIndex);
    });
  }

  void _editItem(int categoryIndex, int itemIndex) async {
    final item = _categories[categoryIndex].items[itemIndex];
    final nameController = TextEditingController(text: item.name);
    final itemNumberController = TextEditingController(text: item.itemNumber);
    final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
    final descController = TextEditingController(text: item.description);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: itemNumberController,
                decoration: const InputDecoration(
                  labelText: 'Item Number',
                  border: OutlineInputBorder(),
                  helperText: 'e.g., 1, 2a, 3b',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price *',
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
        item.itemNumber = itemNumberController.text;
        item.name = nameController.text;
        item.price = double.tryParse(priceController.text) ?? 0.0;
        item.description = descController.text;
      });
    }

    itemNumberController.dispose();
    nameController.dispose();
    priceController.dispose();
    descController.dispose();
  }

  /// Build a smart search query based on cuisine type and menu items
  String _buildImageSearchQuery() {
    final cuisineType = _cuisineTypeController.text.trim();
    
    // Common food keywords that help identify the type of food
    final foodKeywords = <String>[
      'pizza', 'pasta', 'burger', 'sushi', 'ramen', 'noodles',
      'steak', 'seafood', 'fish', 'chicken', 'beef', 'pork',
      'salad', 'soup', 'curry', 'rice', 'tacos', 'burrito',
      'sandwich', 'dessert', 'cake', 'coffee', 'breakfast',
      'pancake', 'waffle', 'barbecue', 'bbq', 'grill', 'vegetarian',
      'vegan', 'dim sum', 'dumplings', 'tempura', 'teriyaki',
      'lasagna', 'risotto', 'paella', 'tapas', 'schnitzel',
      'kebab', 'falafel', 'hummus', 'pho', 'pad thai', 'biryani'
    ];

    // Collect keywords from menu items and categories
    final foundKeywords = <String>{};
    
    for (var category in _categories) {
      final categoryLower = category.name.toLowerCase();
      
      // Check category name for keywords
      for (var keyword in foodKeywords) {
        if (categoryLower.contains(keyword)) {
          foundKeywords.add(keyword);
        }
      }
      
      // Check item names for keywords
      for (var item in category.items) {
        final itemLower = item.name.toLowerCase();
        for (var keyword in foodKeywords) {
          if (itemLower.contains(keyword)) {
            foundKeywords.add(keyword);
          }
        }
      }
    }

    // Build the search query
    String query = 'restaurant food';
    
    if (cuisineType.isNotEmpty) {
      query = '$cuisineType food';
    }
    
    // Add up to 2 most relevant food keywords
    if (foundKeywords.isNotEmpty) {
      final keywords = foundKeywords.take(2).join(' ');
      query = cuisineType.isNotEmpty 
          ? '$cuisineType $keywords food' 
          : '$keywords restaurant food';
    }
    
    return query;
  }

  Future<void> _saveRestaurant() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate at least one category with one item
    if (_categories.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one category';
      });
      return;
    }

    bool hasItems = false;
    for (var category in _categories) {
      if (category.items.isNotEmpty) {
        hasItems = true;
        break;
      }
    }

    if (!hasItems) {
      setState(() {
        _errorMessage = 'Please add at least one item to a category';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Get current user
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to create a restaurant');
      }

      // Geocode the address
      final coordinates = await GeocodingService.geocodeAddress(_addressController.text.trim());
      final latitude = coordinates?['latitude'];
      final longitude = coordinates?['longitude'];

      // Fetch restaurant image based on cuisine type and menu items
      final searchQuery = _buildImageSearchQuery();
      print('Fetching image with query: $searchQuery');
      final imageUrl = await UnsplashService.getRestaurantImage(searchQuery);

      // Insert restaurant
      final cuisineType = _cuisineTypeController.text.trim();
      final restaurantResponse = await supabase
          .from('restaurants')
          .insert({
            'name': _nameController.text.trim(),
            'address': _addressController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            'cuisine_type': cuisineType.isEmpty ? null : cuisineType,
            'delivers': _delivers,
            'latitude': latitude,
            'longitude': longitude,
            'image_url': imageUrl,
            'restaurant_owner_uuid': currentUser.id,
          })
          .select('id')
          .single();

      final restaurantId = restaurantResponse['id'] as int;

      // Insert categories and items
      for (int catIndex = 0; catIndex < _categories.length; catIndex++) {
        final category = _categories[catIndex];
        
        // Skip empty categories
        if (category.items.isEmpty) continue;

        final categoryResponse = await supabase
            .from('categories')
            .insert({
              'restaurant_id': restaurantId,
              'name': category.name,
              'display_order': catIndex,
            })
            .select('id')
            .single();

        final categoryId = categoryResponse['id'] as int;

        // Insert items
        for (final item in category.items) {
          await supabase.from('items').insert({
            'category_id': categoryId,
            'name': item.name,
            'item_number': item.itemNumber.trim().isEmpty ? null : item.itemNumber.trim(),
            'price': item.price,
            'description': item.description.isEmpty ? null : item.description,
            'available': true,
            'has_variants': false,
          });
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restaurant "${_nameController.text.trim()}" created successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating restaurant: $e';
        _isLoading = false;
      });
    }
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
                        'Create Restaurant',
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
                  'Please sign in to create a restaurant',
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
                      'Create Restaurant',
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Create your restaurant menu from scratch. Add categories and items to build your complete menu.',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Restaurant Information Section
                  Text(
                    'Restaurant Information',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Restaurant Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.restaurant),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Restaurant name is required';
                              }
                              return null;
                            },
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
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Address is required';
                              }
                              return null;
                            },
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
                              hintText: 'E.g., Italian, Chinese, Mexican',
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
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Offers Delivery'),
                            value: _delivers,
                            onChanged: (value) {
                              setState(() {
                                _delivers = value;
                              });
                            },
                            secondary: const Icon(Icons.delivery_dining),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Menu Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Menu Categories & Items',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_categories.isEmpty)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.category_outlined, size: 48, color: Colors.orange.shade700),
                            const SizedBox(height: 12),
                            Text(
                              'No categories yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add at least one category with items to create your menu',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Display categories
                  ...List.generate(_categories.length, (catIndex) {
                    final category = _categories[catIndex];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                category.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editCategory(catIndex),
                              tooltip: 'Edit category',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _removeCategory(catIndex),
                              tooltip: 'Delete category',
                            ),
                          ],
                        ),
                        subtitle: Text('${category.items.length} items'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (category.items.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      'No items in this category',
                                      style: TextStyle(color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ...List.generate(category.items.length, (itemIndex) {
                                  final item = category.items[itemIndex];
                                  return ListTile(
                                    title: Row(
                                      children: [
                                        if (item.itemNumber.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              item.itemNumber,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[700],
                                              ),
                                            ),
                                          ),
                                        Expanded(child: Text(item.name)),
                                        Text(
                                          '€${item.price.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    subtitle: item.description.isNotEmpty
                                        ? Text(item.description)
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          onPressed: () => _editItem(catIndex, itemIndex),
                                          tooltip: 'Edit item',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                          onPressed: () => _removeItem(catIndex, itemIndex),
                                          tooltip: 'Delete item',
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _addItem(catIndex),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Item'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

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

                  const SizedBox(height: 24),

                  // Save button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveRestaurant,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Creating Restaurant...' : 'Create Restaurant'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Data classes for managing categories and items
class CategoryData {
  String name;
  List<ItemData> items;

  CategoryData({
    required this.name,
    required this.items,
  });
}

class ItemData {
  String name;
  String itemNumber;
  double price;
  String description;

  ItemData({
    required this.name,
    required this.itemNumber,
    required this.price,
    required this.description,
  });
}
