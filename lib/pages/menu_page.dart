import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';
import '../services/pdf_service.dart';
import '../services/unsplash_service.dart';

class MenuPage extends StatefulWidget {
  final Restaurant restaurant;

  const MenuPage({super.key, required this.restaurant});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Category> categories = [];
  bool loading = true;
  String? errorMessage;
  late final Cart cart;

  @override
  void initState() {
    super.initState();
    cart = CartManager().getCartForRestaurant(widget.restaurant.id);
    _loadMenu();
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

  Future<void> _loadMenu() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select(
              'id, name, display_order, image_url, items(id, name, item_number, price, description, available, has_variants, item_variants(id, name, price, display_order))')
          .eq('restaurant_id', widget.restaurant.id)
          .order('display_order');

      if (response is List) {
        final cats = response.map((c) {
          final items = (c['items'] as List?)?.map((i) {
                final variants = (i['item_variants'] as List?)
                        ?.map((v) =>
                            ItemVariant.fromJson(v as Map<String, dynamic>))
                        .toList() ??
                    [];
                variants
                    .sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
                return MenuItem.fromJson(i as Map<String, dynamic>, variants);
              }).toList() ??
              [];
          // Sort items by item_number
          items.sort((a, b) => _compareItemNumbers(a.itemNumber, b.itemNumber));
          return Category(
            id: c['id'] as int,
            name: c['name'] as String,
            items: items,
            imageUrl: c['image_url'] as String?,
          );
        }).toList();

        // Filter out empty categories
        final nonEmptyCats = cats.where((cat) => cat.items.isNotEmpty).toList();

        // Sort categories by the minimum item_number in each category
        nonEmptyCats.sort((a, b) {
          // Get first (minimum) item number from each category
          final aMinNum = a.items.isNotEmpty ? a.items.first.itemNumber : null;
          final bMinNum = b.items.isNotEmpty ? b.items.first.itemNumber : null;
          return _compareItemNumbers(aMinNum, bMinNum);
        });

        setState(() {
          categories = nonEmptyCats;
          loading = false;
        });
        _loadCategoryImages();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading menu: $e';
        loading = false;
      });
    }
  }

  // One solid accent color per category
  static const List<Color> _kCategoryColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0D9488), // teal
    Color(0xFFF59E0B), // amber
    Color(0xFFE11D48), // rose
    Color(0xFF10B981), // emerald
    Color(0xFF7C3AED), // violet
    Color(0xFF2563EB), // blue
    Color(0xFFDB2777), // pink
  ];

  Future<void> _loadCategoryImages() async {
    // Only fetch from Unsplash for categories that have no image_url from the DB
    final needsImage = categories.where((c) => c.imageUrl == null || c.imageUrl!.isEmpty).toList();
    if (needsImage.isEmpty) return;
    final updated = await Future.wait(
      categories.map((cat) async {
        if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) return cat;
        final img = await UnsplashService.getCategoryImage(cat.name);
        return cat.copyWith(imageUrl: img);
      }),
    );
    if (mounted) setState(() => categories = updated);
  }

  Widget _buildCategoryTile(Category cat, int idx) {
    final Color color = _kCategoryColors[idx % _kCategoryColors.length];
    final availableItems = cat.items.where((i) => i.available).toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: idx == 0,
          tilePadding: EdgeInsets.zero,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          title: _buildCategoryHeader(cat, color, availableItems.length),
          children: availableItems.map((item) => _buildItemTile(item, color)).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(Category cat, Color color, int count) {
    return SizedBox(
      height: 90,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cat.imageUrl != null)
            Image.network(
              cat.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: color),
            )
          else
            Container(color: color),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withOpacity(0.25), color.withOpacity(0.80)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 52, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  cat.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
                  ),
                  child: Text('$count items',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(MenuItem item, Color catColor) {
    if (item.hasVariants && item.variants.isNotEmpty) {
      return _buildVariantItem(item, catColor);
    }
    return _buildSimpleItem(item, catColor);
  }

  Widget _buildSimpleItem(MenuItem item, Color catColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Row(children: [
        if (item.itemNumber != null && item.itemNumber!.isNotEmpty) ...[  
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(item.itemNumber!,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
        Expanded(
            child: Text(item.name,
                style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      subtitle: item.description?.isNotEmpty == true ? Text(item.description!) : null,
      trailing: item.price != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('\u20ac${item.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.add_shopping_cart, color: catColor),
                onPressed: () {
                  setState(() {
                    cart.addItem(CartItem(
                      itemId: item.id,
                      itemName: item.name,
                      itemNumber: item.itemNumber,
                      variantId: null,
                      variantName: null,
                      price: item.price!,
                      quantity: 1,
                    ));
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${item.name} added to cart'),
                    duration: const Duration(seconds: 1),
                  ));
                },
              ),
            ])
          : null,
    );
  }

  Widget _buildVariantItem(MenuItem item, Color catColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (item.itemNumber != null && item.itemNumber!.isNotEmpty) ...[  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: catColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(item.itemNumber!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ],
                Expanded(
                    child: Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15))),
              ]),
              if (item.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(item.description!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
            ],
          ),
        ),
        ...item.variants.map((variant) => ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
              title: Text(variant.name, style: const TextStyle(fontSize: 14)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('\u20ac${variant.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon:
                      Icon(Icons.add_shopping_cart, color: catColor, size: 20),
                  onPressed: () {
                    setState(() {
                      cart.addItem(CartItem(
                        itemId: item.id,
                        itemName: item.name,
                        itemNumber: item.itemNumber,
                        variantId: variant.id,
                        variantName: variant.name,
                        price: variant.price,
                        quantity: 1,
                      ));
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text('${item.name} (${variant.name}) added to cart'),
                      duration: const Duration(seconds: 1),
                    ));
                  },
                ),
              ]),
            )),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Divider(),
        ),
      ],
    );
  }

  void _showRestaurantInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.restaurant.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.restaurant.description != null) ...[
                Text(widget.restaurant.description!,
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
              ],
              _buildInfoRow(
                  Icons.location_on, 'Address', widget.restaurant.address),
              if (widget.restaurant.phone != null)
                _buildInfoRow(Icons.phone, 'Phone', widget.restaurant.phone!),
              if (widget.restaurant.email != null)
                _buildInfoRow(Icons.email, 'Email', widget.restaurant.email!),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.delivery_dining,
                      size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    widget.restaurant.delivers
                        ? 'Delivery available'
                        : 'No delivery',
                    style: TextStyle(
                      color: widget.restaurant.delivers
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.restaurant.openingHours != null) ...[
                const SizedBox(height: 16),
                const Text('Opening Hours:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ..._buildOpeningHours(),
              ],
              if (widget.restaurant.paymentMethods != null &&
                  widget.restaurant.paymentMethods!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Payment Methods:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.restaurant.paymentMethods!.map((method) {
                    return Chip(
                      label: Text(method),
                      backgroundColor: Colors.teal.shade50,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOpeningHours() {
    if (widget.restaurant.openingHours == null) return [];

    final days = [
      {'label': 'Monday', 'key': 'monday'},
      {'label': 'Tuesday', 'key': 'tuesday'},
      {'label': 'Wednesday', 'key': 'wednesday'},
      {'label': 'Thursday', 'key': 'thursday'},
      {'label': 'Friday', 'key': 'friday'},
      {'label': 'Saturday', 'key': 'saturday'},
      {'label': 'Sunday', 'key': 'sunday'},
    ];

    final todayIndex = DateTime.now().weekday - 1;

    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final dayLabel = entry.value['label']!;
      final dayKey = entry.value['key']!;
      final hours = widget.restaurant.openingHours![dayKey];
      final isToday = index == todayIndex;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                dayLabel,
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.teal : Colors.black87,
                ),
              ),
            ),
            Text(
              hours?.toString() ?? 'Closed',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? Colors.teal
                    : (hours == 'Closed' ? Colors.red : Colors.black87),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Cart',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (cart.items.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                setState(() {
                                  cart.clear();
                                });
                              });
                            },
                            child: const Text('Clear All'),
                          ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: cart.items.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_cart_outlined,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('Your cart is empty',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: cart.items.length,
                              itemBuilder: (context, index) {
                                final cartItem = cart.items[index];
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (cartItem.itemNumber != null && cartItem.itemNumber!.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      margin: const EdgeInsets.only(right: 6),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [Colors.purple.shade400, Colors.deepPurple.shade500],
                                                        ),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        cartItem.itemNumber!,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  Expanded(
                                                    child: Text(
                                                      cartItem.itemName,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (cartItem.variantName != null)
                                                Text(
                                                  cartItem.variantName!,
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 14),
                                                ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [Colors.green.shade400, Colors.teal.shade500],
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '€${cartItem.price.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle_outline),
                                              onPressed: () {
                                                setModalState(() {
                                                  setState(() {
                                                    cart.decreaseQuantity(
                                                        cartItem);
                                                  });
                                                });
                                              },
                                            ),
                                            Text(
                                              '${cartItem.quantity}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_outline),
                                              onPressed: () {
                                                setModalState(() {
                                                  setState(() {
                                                    cart.increaseQuantity(
                                                        cartItem);
                                                  });
                                                });
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red),
                                              onPressed: () {
                                                setModalState(() {
                                                  setState(() {
                                                    cart.removeItem(cartItem);
                                                  });
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (cart.items.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '€${cart.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  foreground: Paint()
                                    ..shader = LinearGradient(
                                      colors: [Colors.green.shade600, Colors.teal.shade600],
                                    ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0))),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.deepPurple.shade400, Colors.purple.shade500],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Checkout functionality coming soon!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            child: const Text('Proceed to Checkout',
                                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          color: Colors.teal,
          child: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.restaurant.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.restaurant.address,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      onPressed: () async {
                        if (categories.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Menu is still loading...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        try {
                          await PdfService.generateMenuPdf(widget.restaurant, categories);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error generating PDF: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                      tooltip: 'Download Menu PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      onPressed: () {
                        _showRestaurantInfo(context);
                      },
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart, color: Colors.white),
                          onPressed: () {
                            _showCart(context);
                          },
                        ),
                        if (cart.itemCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '${cart.itemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          color: const Color(0xFFF5F7FA),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(errorMessage!, textAlign: TextAlign.center),
                    ))
                  : categories.isEmpty
                      ? const Center(child: Text('No menu items found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: categories.length,
                          itemBuilder: (context, idx) =>
                              _buildCategoryTile(categories[idx], idx),
                        ),
        ),
      ),
    );
  }
}
