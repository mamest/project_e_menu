import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../services/auth_service.dart';

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

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _descriptionController;
  late TextEditingController _cuisineTypeController;
  late bool _delivers;

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
    super.dispose();
  }

  Future<void> _loadMenuData() async {
    try {
      // Load categories
      final categoriesData = await _supabase
          .from('categories')
          .select('id, name, display_order')
          .eq('restaurant_id', widget.restaurant.id)
          .order('display_order');

      List<MenuCategory> categories = [];
      for (var catData in categoriesData) {
        // Load items for this category
        final itemsData = await _supabase
            .from('items')
            .select('id, name, price, description, has_variants, available')
            .eq('category_id', catData['id'])
            .order('id');

        List<MenuItem> items = (itemsData as List).map<MenuItem>((itemData) {
          return MenuItem(
            id: itemData['id'] as int,
            name: itemData['name'] as String,
            price: itemData['price'] != null ? (itemData['price'] as num).toDouble() : null,
            description: itemData['description'] as String?,
            hasVariants: itemData['has_variants'] as bool? ?? false,
            available: itemData['available'] as bool? ?? true,
          );
        }).toList();

        categories.add(MenuCategory(
          id: catData['id'] as int,
          name: catData['name'] as String,
          displayOrder: catData['display_order'] as int? ?? 0,
          items: items,
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
          ));
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
          'price': price,
          'description': descController.text.isEmpty ? null : descController.text,
          'available': true,
          'has_variants': false,
        }).select().single();

        setState(() {
          category.items.add(MenuItem(
            id: response['id'],
            name: response['name'],
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
          'price': price,
          'description': descController.text.isEmpty ? null : descController.text,
        }).eq('id', item.id);

        setState(() {
          final index = category.items.indexOf(item);
          category.items[index] = MenuItem(
            id: item.id,
            name: nameController.text,
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
                        title: Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text('${category.items.length} items'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                  title: Text(item.name),
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

  MenuCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.items,
  });
}
