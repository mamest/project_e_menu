import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
import '../services/translation_service.dart';
import '../services/unsplash_service.dart';
import '../utils/payment_utils.dart';
import '../widgets/unsplash_picker_dialog.dart';

class CreateRestaurantPage extends StatefulWidget {
  const CreateRestaurantPage({super.key});

  @override
  State<CreateRestaurantPage> createState() => _CreateRestaurantPageState();
}

class _CreateRestaurantPageState extends State<CreateRestaurantPage> {
  static const List<String> _weekDays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  static const List<String> _availablePaymentMethods = [
    'Cash', 'Card', 'EC-Karte', 'PayPal', 'Apple Pay', 'Google Pay', 'Invoice',
  ];

  String _getDayLabel(String day, AppLocalizations l10n) {
    switch (day) {
      case 'monday': return l10n.dayMonday;
      case 'tuesday': return l10n.dayTuesday;
      case 'wednesday': return l10n.dayWednesday;
      case 'thursday': return l10n.dayThursday;
      case 'friday': return l10n.dayFriday;
      case 'saturday': return l10n.daySaturday;
      case 'sunday': return l10n.daySunday;
      default: return day;
    }
  }

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
  String? _selectedImageUrl;
  bool _imageFetching = false;
  Map<String, String> _openingHours = {};
  final Map<String, TextEditingController> _hoursControllers = {};
  List<String> _paymentMethods = [];

  // Categories and items structure
  List<CategoryData> _categories = [];

  @override
  void initState() {
    super.initState();
    for (final day in _weekDays) {
      _openingHours[day] = 'closed';
      _hoursControllers[day] = TextEditingController();
    }
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

  /// Auto-fetch a restaurant image from Unsplash based on current form content.
  Future<void> _autoFetchImage() async {
    final query = _buildImageSearchQuery();
    setState(() => _imageFetching = true);
    final url = await UnsplashService.getRestaurantImage(query);
    if (mounted) setState(() { _selectedImageUrl = url; _imageFetching = false; });
  }

  /// Open the Unsplash picker so the owner can choose a different photo.
  Future<void> _openUnsplashPicker() async {
    final query = _buildImageSearchQuery();
    final picked = await UnsplashPickerDialog.show(context, initialQuery: query);
    if (picked != null && mounted) setState(() => _selectedImageUrl = picked);
  }

  Future<void> _pickCategoryImage(int catIndex) async {
    final category = _categories[catIndex];
    final picked = await UnsplashPickerDialog.show(
      context,
      initialQuery: 'food ${category.name}',
    );
    if (picked != null && mounted) {
      setState(() => _categories[catIndex].imageUrl = picked);
    }
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
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _categories[index].name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editCategoryNameDialogTitle),
        content: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.categoryNameLabel,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
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
    final l10n = AppLocalizations.of(context)!;
    final item = _categories[categoryIndex].items[itemIndex];
    final nameController = TextEditingController(text: item.name);
    final itemNumberController = TextEditingController(text: item.itemNumber);
    final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
    final descController = TextEditingController(text: item.description);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editMenuItemDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: itemNumberController,
                decoration: InputDecoration(
                  labelText: l10n.itemNumberLabel,
                  border: const OutlineInputBorder(),
                  helperText: l10n.itemNumberHelperText,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.itemNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: l10n.priceLabel,
                  border: const OutlineInputBorder(),
                  prefixText: '€',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: l10n.descriptionLabel,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
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

  Widget _buildOpeningHoursSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.openingHoursSection, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          child: Text(_getDayLabel(day, l10n), style: const TextStyle(fontWeight: FontWeight.w500)),
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
                          activeColor: const Color(0xFF7C3AED),
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
                          Expanded(
                            child: Text(l10n.closed, style: const TextStyle(color: Colors.grey)),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.paymentMethodsSection, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _availablePaymentMethods.map((method) {
            final selected = _paymentMethods.contains(method);
            return FilterChip(
              label: Text(localizePaymentMethod(method, l10n)),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _paymentMethods.add(method);
                } else {
                  _paymentMethods.remove(method);
                }
              }),
              selectedColor: const Color(0xFF7C3AED).withOpacity(0.2),
              checkmarkColor: const Color(0xFF7C3AED),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF5B21B6) : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.restaurantPhoto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_imageFetching)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
            else ...[
              TextButton.icon(
                onPressed: _autoFetchImage,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.autoSuggest),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _openUnsplashPicker,
                icon: const Icon(Icons.image_search, size: 16),
                label: Text(l10n.browseUnsplash),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedImageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _selectedImageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(height: 160, color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: Colors.grey[200],
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
                  Text(l10n.noPhotoYetHint,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
      ],
    );
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
    final l10n = AppLocalizations.of(context)!;
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate at least one category with one item
    if (_categories.isEmpty) {
      setState(() {
        _errorMessage = l10n.pleaseAddCategory;
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
        _errorMessage = l10n.pleaseAddItem;
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

      // Use the already-selected image or fetch one now if not yet picked
      String? imageUrl = _selectedImageUrl;
      if (imageUrl == null) {
        final searchQuery = _buildImageSearchQuery();
        imageUrl = await UnsplashService.getRestaurantImage(searchQuery);
      }

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
            'opening_hours': _openingHours.values.every((v) => v == 'closed') ? null : Map<String, dynamic>.from(_openingHours),
            'payment_methods': _paymentMethods.isEmpty ? null : _paymentMethods,
          })
          .select('id')
          .single();

      final restaurantId = restaurantResponse['id'] as int;

      // Pre-translate all categories and items in one AI call
      final translationService = TranslationService();
      Map<String, Map<String, dynamic>> translationMaps = {};
      try {
        final entries = <Map<String, dynamic>>[];
        // Include restaurant description in the translation batch
        final restaurantDesc = _descriptionController.text.trim();
        if (restaurantDesc.isNotEmpty) {
          entries.add({'id': 'restaurant_desc', 'name': '', 'description': restaurantDesc});
        }
        for (int ci = 0; ci < _categories.length; ci++) {
          final cat = _categories[ci];
          if (cat.items.isEmpty) continue;
          entries.add({'id': 'cat_$ci', 'name': cat.name});
          for (int ii = 0; ii < cat.items.length; ii++) {
            final item = cat.items[ii];
            final e = <String, dynamic>{'id': 'item_${ci}_$ii', 'name': item.name};
            if (item.description.isNotEmpty) e['description'] = item.description;
            entries.add(e);
          }
        }
        if (entries.isNotEmpty) {
          final results = await translationService.translateBatch(entries);
          for (int i = 0; i < entries.length; i++) {
            final id = entries[i]['id'] as String;
            if (results[i].isNotEmpty) translationMaps[id] = results[i];
          }
        }
      } catch (_) {} // translation failure must not block save

      // Apply restaurant description translations
      final restaurantTranslations = translationMaps['restaurant_desc'] ?? {};
      if (restaurantTranslations.isNotEmpty) {
        try {
          await supabase
              .from('restaurants')
              .update({'translations': restaurantTranslations})
              .eq('id', restaurantId);
        } catch (_) {}
      }

      // Insert categories and items
      for (int catIndex = 0; catIndex < _categories.length; catIndex++) {
        final category = _categories[catIndex];
        
        // Skip empty categories
        if (category.items.isEmpty) continue;

        final catTranslations = translationMaps['cat_$catIndex'] ?? {};
        final categoryResponse = await supabase
            .from('categories')
            .insert({
              'restaurant_id': restaurantId,
              'name': category.name,
              'display_order': catIndex,
              if (category.imageUrl != null) 'image_url': category.imageUrl,
              if (catTranslations.isNotEmpty) 'translations': catTranslations,
            })
            .select('id')
            .single();

        final categoryId = categoryResponse['id'] as int;

        // Insert items
        for (int itemIndex = 0; itemIndex < category.items.length; itemIndex++) {
          final item = category.items[itemIndex];
          final itemTranslations = translationMaps['item_${catIndex}_$itemIndex'] ?? {};
          await supabase.from('items').insert({
            'category_id': categoryId,
            'name': item.name,
            'item_number': item.itemNumber.trim().isEmpty ? null : item.itemNumber.trim(),
            'price': item.price,
            'description': item.description.isEmpty ? null : item.description,
            'available': true,
            'has_variants': false,
            if (itemTranslations.isNotEmpty) 'translations': itemTranslations,
          });
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.restaurantCreatedMessage(_nameController.text.trim())),
            backgroundColor: const Color(0xFF7C3AED),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = l10n.errorCreatingRestaurant(e.toString());
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Check if user is logged in
    if (!_authService.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF7C3AED),
          flexibleSpace: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: Text(
                        l10n.createRestaurantTitle,
                        style: const TextStyle(
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
                  l10n.authRequiredTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.pleaseSignInToCreate,
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
                  label: Text(l10n.goBack),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
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
        backgroundColor: const Color(0xFF7C3AED),
        flexibleSpace: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Text(
                      l10n.createRestaurantTitle,
                      style: const TextStyle(
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
                    color: const Color(0xFFEDE9FE),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: const Color(0xFF6D28D9)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.createRestaurantInfoText,
                              style: TextStyle(color: const Color(0xFF6D28D9)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Restaurant Information Section
                  Text(
                    l10n.restaurantInformation,
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
                            decoration: InputDecoration(
                              labelText: l10n.restaurantNameAsterisk,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.restaurant),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.restaurantNameRequiredError;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: l10n.addressAsterisk,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.location_on),
                            ),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.addressRequiredError;
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
                                  decoration: InputDecoration(
                                    labelText: l10n.phoneLabel,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.phone),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: l10n.emailLabel,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.email),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cuisineTypeController,
                            decoration: InputDecoration(
                              labelText: l10n.cuisineType,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.local_dining),
                              hintText: l10n.cuisineTypeHint,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Restaurant image preview
                          _buildImageSection(),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: l10n.descriptionLabel,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.description),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: Text(l10n.offersDelivery),
                            value: _delivers,
                            onChanged: (value) {
                              setState(() {
                                _delivers = value;
                              });
                            },
                            secondary: const Icon(Icons.delivery_dining),
                          ),
                          const SizedBox(height: 16),
                          _buildOpeningHoursSection(),
                          const SizedBox(height: 16),
                          _buildPaymentMethodsSection(),
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
                        l10n.menuCategoriesAndItems,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addCategoryButton),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
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
                              l10n.noCategoriesCardTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.noCategoriesCardHint,
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.image_search, size: 20, color: const Color(0xFF7C3AED)),
                              onPressed: () => _pickCategoryImage(catIndex),
                              tooltip: 'Change category photo',
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
                        subtitle: Text(l10n.itemCount(category.items.length)),
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
                                      l10n.noItemsInCategory,
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
                                              color: const Color(0xFF7C3AED).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              item.itemNumber,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF6D28D9),
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
                                  label: Text(l10n.addItemButton),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF7C3AED),
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
                    label: Text(_isLoading ? l10n.creatingRestaurant : l10n.createRestaurantTitle),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: const Color(0xFF7C3AED),
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
  String? imageUrl;

  CategoryData({
    required this.name,
    required this.items,
    this.imageUrl,
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
