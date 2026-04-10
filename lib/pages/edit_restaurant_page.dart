import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/restaurant.dart';
import '../models/deal.dart';
import '../models/menu_item.dart';
import '../services/auth_service.dart';
import '../services/translation_service.dart';
import '../services/html_menu_service.dart';
import '../services/unsplash_service.dart';
import '../utils/payment_utils.dart';
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
  List<Deal> _deals = [];
  bool _isLoading = true;
  bool _isSaving = false;
  final TranslationService _translationService = TranslationService();
  bool _generatingAiMenu = false;
  String? _savedMenuHtmlUrl;
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
    _savedMenuHtmlUrl = widget.restaurant.menuHtmlUrl;
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
          .select('id, name, display_order, image_url, translations')
          .eq('restaurant_id', widget.restaurant.id)
          .order('display_order');

      List<MenuCategory> categories = [];
      for (var catData in categoriesData) {
        // Load items for this category
        final itemsData = await _supabase
            .from('items')
            .select('id, name, item_number, price, description, has_variants, available, translations')
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
            translations: (itemData['translations'] as Map?)?.cast<String, dynamic>() ?? {},
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
          translations: (catData['translations'] as Map?)?.cast<String, dynamic>() ?? {},
        ));
      }

      // Load deals for this restaurant
      final dealsData = await _supabase
          .from('deals')
          .select(
              'id, restaurant_id, title, description, discount_type, discount_value, applies_to, day_of_week, valid_from, valid_until, active, deal_categories(category_id), deal_items(item_id)')
          .eq('restaurant_id', widget.restaurant.id)
          .order('id');
      final List<Deal> deals = (dealsData as List)
          .map((d) => Deal.fromJson(d as Map<String, dynamic>))
          .toList();

      setState(() {
        _categories = categories;
        _deals = deals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorLoadingMenuData(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAndSaveAiMenu() async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noMenuCategoriesLoaded)),
      );
      return;
    }
    setState(() => _generatingAiMenu = true);
    try {
      // Build payload from current local state
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      final payload = {
        'restaurantId': widget.restaurant.id,
        'restaurant': {
          'name': _nameController.text,
          'address': _addressController.text,
          if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text,
          if (_emailController.text.isNotEmpty) 'email': _emailController.text,
          if (_descriptionController.text.isNotEmpty)
            'description': _descriptionController.text,
          if (_cuisineTypeController.text.isNotEmpty)
            'cuisine_type': _cuisineTypeController.text,
          'delivers': _delivers,
          if (_openingHours.isNotEmpty) 'opening_hours': _openingHours,
          if (_paymentMethods.isNotEmpty) 'payment_methods': _paymentMethods,
          if (_imageUrl != null) 'image_url': _imageUrl,
        },
      };

      // 1. Generate HTML via edge function
      final genResponse = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/menu-html'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $anonKey',
          'apikey': anonKey,
        },
        body: jsonEncode(payload),
      );

      if (genResponse.statusCode != 200) {
        throw Exception('Edge function error ${genResponse.statusCode}: ${genResponse.body}');
      }

      final responseMap = jsonDecode(genResponse.body) as Map<String, dynamic>;
      if (responseMap.containsKey('error')) {
        throw Exception('Edge function error: ${responseMap['error']}');
      }

      final htmlContent = responseMap['html'] as String?;
      if (htmlContent == null || htmlContent.isEmpty) {
        throw Exception('Empty HTML returned. Response: $responseMap');
      }

      // 2. Open preview in new tab (as blob so it renders correctly)
      final lang = Localizations.localeOf(context).languageCode;
      final injected = htmlContent.replaceFirst(
        "var lang = (navigator.language || 'en').slice(0, 2).toLowerCase();",
        "var lang = '$lang';",
      );
      final blobBytes = utf8.encode(injected);
      final blob = html.Blob([blobBytes], 'text/html; charset=utf-8');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(blobUrl, '_blank');
      Future.delayed(const Duration(minutes: 2),
          () => html.Url.revokeObjectUrl(blobUrl));

      // 3. Ask owner whether to save
      if (!mounted) return;
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.saveAiMenuDialogTitle),
          content: Text(AppLocalizations.of(context)!.saveAiMenuDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.discard),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: Text(AppLocalizations.of(context)!.save, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldSave != true) return;

      // 4. Upload HTML to Supabase Storage
      final bytes = Uint8List.fromList(utf8.encode(htmlContent));
      final path = '${widget.restaurant.id}/menu.html';

      await _supabase.storage.from('menu-designs').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'text/html; charset=utf-8',
              upsert: true,
            ),
          );

      final publicUrl = _supabase.storage
          .from('menu-designs')
          .getPublicUrl(path);

      // 5. Save URL in restaurant record
      await _supabase
          .from('restaurants')
          .update({'menu_html_url': publicUrl})
          .eq('id', widget.restaurant.id);

      setState(() => _savedMenuHtmlUrl = publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.aiMenuDesignSavedMessage),
            backgroundColor: const Color(0xFF7C3AED),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAiMenu = false);
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

      // Fire-and-forget: translate the restaurant description if it changed
      final desc = _descriptionController.text.isEmpty ? null : _descriptionController.text;
      if (desc != null) {
        _translationService
            .translateItemIfChanged(
              name: '',
              description: desc,
              existing: widget.restaurant.translations,
            )
            .then((translations) async {
          if (translations.isNotEmpty) {
            await _supabase
                .from('restaurants')
                .update({'translations': translations})
                .eq('id', widget.restaurant.id);
          }
        }).catchError((_) {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.restaurantInfoSavedMessage),
            backgroundColor: const Color(0xFF7C3AED),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorSavingData(e.toString());
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
        title: Text(AppLocalizations.of(context)!.addCategoryDialogTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.categoryNameLabel,
            hintText: AppLocalizations.of(context)!.categoryNameHint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.add),
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
        final newCatId = response['id'] as int;
        UnsplashService.getCategoryImage(catName).then((url) {
          if (url != null && mounted) {
            _supabase.from('categories').update({'image_url': url}).eq('id', newCatId);
            setState(() {
              final idx = _categories.indexWhere((c) => c.id == newCatId);
              if (idx >= 0) _categories[idx].imageUrl = url;
            });
          }
        });

        // Translate category name in the background (fire-and-forget)
        _translationService
            .translateCategoryIfChanged(name: catName)
            .then((t) {
          if (t.isNotEmpty) {
            _supabase
                .from('categories')
                .update({'translations': t})
                .eq('id', newCatId);
          }
        }).catchError((_) {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.categoryAdded)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))),
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
        title: Text(AppLocalizations.of(context)!.addItemToCategoryTitle(category.name)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemNumberController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.itemNumberLabel,
                  helperText: AppLocalizations.of(context)!.itemNumberHelperText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.itemNameLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.priceLabel,
                  prefixText: '€ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.descriptionLabel),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.add),
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

        // Translate item in the background (fire-and-forget)
        final newItemId = response['id'] as int;
        final itemName = nameController.text;
        final itemDesc = descController.text.isEmpty ? null : descController.text;
        _translationService
            .translateItemIfChanged(name: itemName, description: itemDesc)
            .then((t) {
          if (t.isNotEmpty) {
            _supabase.from('items').update({'translations': t}).eq('id', newItemId);
          }
        }).catchError((_) {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.itemAdded)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))),
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
        title: Text(AppLocalizations.of(context)!.editCategoryDialogTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.categoryNameLabel,
            hintText: AppLocalizations.of(context)!.categoryNameHint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.save),
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
            translations: category.translations,
          );
        });

        // Translate if name changed (fire-and-forget)
        if (nameController.text != category.name) {
          final catId = category.id;
          final newName = nameController.text;
          _translationService
              .translateCategoryIfChanged(
                  name: newName, existing: category.translations)
              .then((t) {
            if (t.isNotEmpty) {
              _supabase
                  .from('categories')
                  .update({'translations': t})
                  .eq('id', catId);
            }
          }).catchError((_) {});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.categoryUpdated)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteCategoryDialogTitle),
        content: Text(AppLocalizations.of(context)!.deleteCategoryConfirm(category.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
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
            SnackBar(content: Text(AppLocalizations.of(context)!.categoryDeleted)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(MenuCategory category, MenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteItemDialogTitle),
        content: Text(AppLocalizations.of(context)!.deleteItemConfirm(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
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
            SnackBar(content: Text(AppLocalizations.of(context)!.itemDeleted)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))),
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
        title: Text(AppLocalizations.of(context)!.editItemDialogTitle(item.name)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemNumberController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.itemNumberLabel,
                  helperText: AppLocalizations.of(context)!.itemNumberHelperText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.itemNameLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.priceLabel,
                  prefixText: '€ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.descriptionLabel),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.save),
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
            translations: item.translations,
          );
        });

        // Translate if name or description changed (fire-and-forget)
        final newName = nameController.text;
        final newDesc = descController.text.isEmpty ? null : descController.text;
        if (newName != item.name || newDesc != item.description) {
          final itemId = item.id;
          _translationService
              .translateItemIfChanged(
                  name: newName,
                  description: newDesc,
                  existing: item.translations)
              .then((t) {
            if (t.isNotEmpty) {
              _supabase.from('items').update({'translations': t}).eq('id', itemId);
            }
          }).catchError((_) {});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.itemUpdated)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))),
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
          SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))),
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
          title: Text(AppLocalizations.of(context)!.editRestaurant),
          backgroundColor: const Color(0xFF7C3AED),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.accessDeniedTitle,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.accessDeniedMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
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
        flexibleSpace: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                const BackButton(color: Colors.white),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.editRestaurantPageTitle(widget.restaurant.name),
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
              length: 3,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: TabBar(
                        labelColor: const Color(0xFF7C3AED),
                        tabs: [
                          Tab(icon: const Icon(Icons.info_outline), text: AppLocalizations.of(context)!.restaurantInfoTab),
                          Tab(icon: const Icon(Icons.restaurant_menu), text: AppLocalizations.of(context)!.menuTab),
                          Tab(icon: const Icon(Icons.local_offer_outlined), text: AppLocalizations.of(context)!.dealsTab),
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
                            _buildDealsTab(),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.restaurantPhoto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: _autoSuggestImage,
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
                  Text(l10n.noPhotoHint,
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
    final l10n = AppLocalizations.of(context)!;
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
              decoration: InputDecoration(
                labelText: l10n.restaurantName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: l10n.addressLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: l10n.phoneLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.emailLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cuisineTypeController,
              decoration: InputDecoration(
                labelText: l10n.cuisineType,
                border: const OutlineInputBorder(),
                hintText: l10n.cuisineTypeHint,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.descriptionLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.offersDelivery),
              value: _delivers,
              onChanged: (value) => setState(() => _delivers = value),
              activeColor: const Color(0xFF7C3AED),
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
              label: Text(l10n.saveRestaurantInfoButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),
            // ── AI Menu Design Section ──────────────────────────────────
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  l10n.aiMenuDesignTitle,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _savedMenuHtmlUrl != null
                  ? l10n.aiMenuDesignSavedDescription
                  : l10n.aiMenuDesignDescription,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _generatingAiMenu ? null : _generateAndSaveAiMenu,
                  icon: _generatingAiMenu
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_generatingAiMenu
                      ? l10n.generatingLabel
                      : _savedMenuHtmlUrl != null
                          ? l10n.regenerateDesign
                          : l10n.generateDesign),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
                if (_savedMenuHtmlUrl != null) ...
                  [
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final locale = Localizations.localeOf(context).languageCode;
                          await HtmlMenuService.openStoredHtml(_savedMenuHtmlUrl!, locale);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString())),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.viewSaved),
                    ),
                  ],
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneral(e.toString()))));
      }
    }
  }

  Widget _buildMenuTab() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: Text(l10n.addCategoryButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _categories.isEmpty
              ? Center(
                  child: Text(
                    l10n.noCategoriesYetMessage,
                    style: const TextStyle(color: Colors.grey),
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
                        subtitle: Text(l10n.itemCount(category.items.length)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image_search, color: const Color(0xFF7C3AED)),
                              onPressed: () => _pickCategoryImage(category),
                              tooltip: 'Change category photo',
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: const Color(0xFF7C3AED)),
                              onPressed: () => _addItem(category),
                              tooltip: 'Add item',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: const Color(0xFF7C3AED)),
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
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    l10n.noItemsInCategory,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ]
                            : category.items.map((item) {
                                return ListTile(
                                  leading: Checkbox(
                                    value: item.available,
                                    onChanged: (_) => _toggleItemAvailability(item),
                                    activeColor: const Color(0xFF7C3AED),
                                  ),
                                  title: Row(
                                    children: [
                                      if (item.itemNumber != null && item.itemNumber!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7C3AED).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            item.itemNumber!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF6D28D9),
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
                                            : l10n.priceVaries,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: const Color(0xFF7C3AED)),
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

  // ============ DEALS TAB ============

  Widget _buildDealsTab() {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        _deals.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(l10n.noDealYet,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: _deals.map(_buildDealCard).toList(),
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab_add_deal',
            backgroundColor: const Color(0xFF7C3AED),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(l10n.addDeal,
                style: const TextStyle(color: Colors.white)),
            onPressed: () => _showDealDialog(),
          ),
        ),
      ],
    );
  }

  Widget _buildDealCard(Deal deal) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              deal.active ? const Color(0xFF7C3AED) : Colors.grey,
          child:
              const Icon(Icons.local_offer, color: Colors.white, size: 20),
        ),
        title: Text(deal.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_dealSubtitle(deal, l10n)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: deal.active,
              activeColor: const Color(0xFF7C3AED),
              onChanged: (v) => _toggleDealActive(deal, v),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showDealDialog(deal: deal),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.red),
              onPressed: () => _confirmDeleteDeal(deal),
            ),
          ],
        ),
      ),
    );
  }

  String _dealSubtitle(Deal deal, AppLocalizations l10n) {
    final parts = <String>[deal.discountLabel];
    if (deal.dayOfWeek == null || deal.dayOfWeek!.isEmpty) {
      parts.add(l10n.dealEveryDay);
    } else {
      parts.add(
          deal.dayOfWeek!.map((d) => _shortDayName(d, l10n)).join(', '));
    }
    switch (deal.appliesTo) {
      case 'category':
        parts.add(l10n.dealSelectCategories);
        break;
      case 'item':
        parts.add(l10n.dealSelectItems);
        break;
    }
    return parts.join(' · ');
  }

  String _shortDayName(int day, AppLocalizations l10n) {
    switch (day) {
      case 1:
        return l10n.dayMonday.substring(0, 2);
      case 2:
        return l10n.dayTuesday.substring(0, 2);
      case 3:
        return l10n.dayWednesday.substring(0, 2);
      case 4:
        return l10n.dayThursday.substring(0, 2);
      case 5:
        return l10n.dayFriday.substring(0, 2);
      case 6:
        return l10n.daySaturday.substring(0, 2);
      case 7:
        return l10n.daySunday.substring(0, 2);
      default:
        return '';
    }
  }

  Future<void> _reloadDeals() async {
    final data = await _supabase
        .from('deals')
        .select(
            'id, restaurant_id, title, description, discount_type, discount_value, applies_to, day_of_week, valid_from, valid_until, active, deal_categories(category_id), deal_items(item_id)')
        .eq('restaurant_id', widget.restaurant.id)
        .order('id');
    if (mounted) {
      setState(() {
        _deals = (data as List)
            .map((d) => Deal.fromJson(d as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _toggleDealActive(Deal deal, bool active) async {
    try {
      await _supabase
          .from('deals')
          .update({'active': active}).eq('id', deal.id);
      await _reloadDeals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showDealDialog({Deal? deal}) async {
    final result = await _DealFormDialog.show(
      context: context,
      initial: deal,
      categories: _categories,
    );
    if (result == null || !mounted) return;
    await _saveDeal(deal?.id, result);
  }

  Future<void> _saveDeal(
      int? existingId, Map<String, dynamic> data) async {
    try {
      final catIds = List<int>.from(data.remove('_categoryIds') as List);
      final itemIds = List<int>.from(data.remove('_itemIds') as List);

      int dealId;
      if (existingId != null) {
        await _supabase
            .from('deals')
            .update(data)
            .eq('id', existingId);
        dealId = existingId;
      } else {
        data['restaurant_id'] = widget.restaurant.id;
        final resp = await _supabase
            .from('deals')
            .insert(data)
            .select('id')
            .single();
        dealId = resp['id'] as int;
      }

      await _supabase
          .from('deal_categories')
          .delete()
          .eq('deal_id', dealId);
      if (catIds.isNotEmpty) {
        await _supabase.from('deal_categories').insert(
              catIds
                  .map((cid) =>
                      {'deal_id': dealId, 'category_id': cid})
                  .toList(),
            );
      }

      await _supabase
          .from('deal_items')
          .delete()
          .eq('deal_id', dealId);
      if (itemIds.isNotEmpty) {
        await _supabase.from('deal_items').insert(
              itemIds
                  .map((iid) =>
                      {'deal_id': dealId, 'item_id': iid})
                  .toList(),
            );
      }

      await _reloadDeals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.dealSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteDeal(Deal deal) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDealConfirm),
        content: Text(deal.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _deleteDeal(deal.id);
    }
  }

  Future<void> _deleteDeal(int dealId) async {
    try {
      await _supabase.from('deals').delete().eq('id', dealId);
      await _reloadDeals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.dealDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

class MenuCategory {
  final int id;
  final String name;
  final int displayOrder;
  final List<MenuItem> items;
  String? imageUrl;
  Map<String, dynamic> translations;

  MenuCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.items,
    this.imageUrl,
    this.translations = const {},
  });
}

// ============================================================
// DEAL FORM DIALOG
// ============================================================

class _DealFormDialog extends StatefulWidget {
  final Deal? initial;
  final List<MenuCategory> categories;

  const _DealFormDialog({this.initial, required this.categories});

  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    Deal? initial,
    required List<MenuCategory> categories,
  }) =>
      showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) =>
            _DealFormDialog(initial: initial, categories: categories),
      );

  @override
  State<_DealFormDialog> createState() => _DealFormDialogState();
}

class _DealFormDialogState extends State<_DealFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  String _discountType = 'percentage';
  String _appliesTo = 'all';
  final Set<int> _selectedDays = {};
  final Set<int> _selectedCategoryIds = {};
  final Set<int> _selectedItemIds = {};
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      _titleCtrl.text = d.title;
      _descCtrl.text = d.description ?? '';
      _discountType = d.discountType;
      _valueCtrl.text = d.discountValue == d.discountValue.truncateToDouble()
          ? d.discountValue.toInt().toString()
          : d.discountValue.toString();
      _appliesTo = d.appliesTo;
      if (d.dayOfWeek != null) _selectedDays.addAll(d.dayOfWeek!);
      _selectedCategoryIds.addAll(d.categoryIds);
      _selectedItemIds.addAll(d.itemIds);
      _active = d.active;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
          widget.initial == null ? l10n.addDeal : l10n.editDeal),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.dealTitleLabel),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                      labelText: l10n.dealDescriptionLabel),
                ),
                const SizedBox(height: 16),
                Text(l10n.dealDiscountType,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _discountType,
                      decoration:
                          const InputDecoration(isDense: true),
                      items: [
                        DropdownMenuItem(
                            value: 'percentage',
                            child: Text(l10n.discountPercentage)),
                        DropdownMenuItem(
                            value: 'fixed',
                            child: Text(l10n.discountFixedAmount)),
                      ],
                      onChanged: (v) =>
                          setState(() => _discountType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _valueCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.dealDiscountValue,
                        suffixText: _discountType == 'percentage'
                            ? '%'
                            : '\u20ac',
                      ),
                      validator: (v) {
                        final n = double.tryParse(
                            v?.replaceAll(',', '.') ?? '');
                        if (n == null || n <= 0) return '> 0';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(l10n.dealAppliesTo,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _appliesTo,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    DropdownMenuItem(
                        value: 'all', child: Text(l10n.dealAll)),
                    DropdownMenuItem(
                        value: 'category',
                        child: Text(l10n.dealSelectCategories)),
                    DropdownMenuItem(
                        value: 'item',
                        child: Text(l10n.dealSelectItems)),
                  ],
                  onChanged: (v) => setState(() {
                    _appliesTo = v!;
                    _selectedCategoryIds.clear();
                    _selectedItemIds.clear();
                  }),
                ),
                if (_appliesTo == 'category') ...[
                  const SizedBox(height: 8),
                  ...widget.categories.map((cat) => CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(cat.name,
                            style: const TextStyle(fontSize: 14)),
                        value: _selectedCategoryIds.contains(cat.id),
                        activeColor: const Color(0xFF7C3AED),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedCategoryIds.add(cat.id);
                          } else {
                            _selectedCategoryIds.remove(cat.id);
                          }
                        }),
                      )),
                ],
                if (_appliesTo == 'item') ...[
                  const SizedBox(height: 8),
                  ...widget.categories.expand((cat) => [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(0, 8, 0, 4),
                          child: Text(cat.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  fontSize: 12)),
                        ),
                        ...cat.items.map((item) => CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                item.itemNumber != null
                                    ? '${item.itemNumber} ${item.name}'
                                    : item.name,
                                style:
                                    const TextStyle(fontSize: 13),
                              ),
                              value: _selectedItemIds.contains(item.id),
                              activeColor: const Color(0xFF7C3AED),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedItemIds.add(item.id);
                                } else {
                                  _selectedItemIds.remove(item.id);
                                }
                              }),
                            )),
                      ]),
                ],
                const SizedBox(height: 16),
                Text(l10n.dealActiveDays,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    return FilterChip(
                      label: Text(_dayAbbr(day, l10n)),
                      selected: _selectedDays.contains(day),
                      selectedColor: const Color(0xFFEDE9FE),
                      checkmarkColor: const Color(0xFF7C3AED),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      }),
                    );
                  }),
                ),
                if (_selectedDays.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.dealEveryDay,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ),
                const SizedBox(height: 16),
                Row(children: [
                  Text(l10n.dealActive),
                  const Spacer(),
                  Switch(
                    value: _active,
                    activeColor: const Color(0xFF7C3AED),
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED)),
          onPressed: _submit,
          child: Text(l10n.save,
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  String _dayAbbr(int day, AppLocalizations l10n) {
    switch (day) {
      case 1:
        return l10n.dayMonday.substring(0, 2);
      case 2:
        return l10n.dayTuesday.substring(0, 2);
      case 3:
        return l10n.dayWednesday.substring(0, 2);
      case 4:
        return l10n.dayThursday.substring(0, 2);
      case 5:
        return l10n.dayFriday.substring(0, 2);
      case 6:
        return l10n.daySaturday.substring(0, 2);
      case 7:
        return l10n.daySunday.substring(0, 2);
      default:
        return '';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final result = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'discount_type': _discountType,
      'discount_value': double.parse(
          _valueCtrl.text.trim().replaceAll(',', '.')),
      'applies_to': _appliesTo,
      'day_of_week': _selectedDays.isEmpty
          ? null
          : (_selectedDays.toList()..sort()),
      'active': _active,
      '_categoryIds': _selectedCategoryIds.toList(),
      '_itemIds': _selectedItemIds.toList(),
    };
    Navigator.pop(context, result);
  }
}
