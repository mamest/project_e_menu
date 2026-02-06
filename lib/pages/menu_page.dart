import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';
import '../services/pdf_service.dart';

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

  Future<void> _loadMenu() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select(
              'id, name, display_order, items(id, name, price, description, available, has_variants, item_variants(id, name, price, display_order))')
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
          return Category(
            id: c['id'] as int,
            name: c['name'] as String,
            items: items,
          );
        }).toList();

        setState(() {
          categories = cats;
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading menu: $e';
        loading = false;
      });
    }
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
                                              Text(
                                                cartItem.itemName,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              if (cartItem.variantName != null)
                                                Text(
                                                  cartItem.variantName!,
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 14),
                                                ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '€${cartItem.price.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    color: Colors.teal,
                                                    fontWeight:
                                                        FontWeight.bold),
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
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
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
                            backgroundColor: Colors.teal,
                          ),
                          child: const Text('Proceed to Checkout',
                              style: TextStyle(fontSize: 16)),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.restaurant.name),
            Text(
              widget.restaurant.address,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
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
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showRestaurantInfo(context);
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
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
                      color: Colors.red,
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
      body: loading
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
                      itemCount: categories.length,
                      itemBuilder: (context, idx) {
                        final cat = categories[idx];
                        return ExpansionTile(
                          initiallyExpanded: idx == 0,
                          title: Text(
                            cat.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: cat.items
                              .where((item) => item.available)
                              .map((item) {
                            if (item.hasVariants && item.variants.isNotEmpty) {
                              // Item with variants (sizes)
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        32, 16, 32, 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16),
                                        ),
                                        if (item.description != null &&
                                            item.description!.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              item.description!,
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  ...item.variants.map((variant) => ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 48, vertical: 4),
                                        title: Text(variant.name,
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '€${variant.price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_shopping_cart,
                                                  size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  cart.addItem(CartItem(
                                                    itemId: item.id,
                                                    itemName: item.name,
                                                    variantId: variant.id,
                                                    variantName: variant.name,
                                                    price: variant.price,
                                                    quantity: 1,
                                                  ));
                                                });
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        '${item.name} (${variant.name}) added to cart'),
                                                    duration: const Duration(
                                                        seconds: 1),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      )),
                                  const Divider(indent: 32, endIndent: 32),
                                ],
                              );
                            } else {
                              // Regular item without variants
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 8),
                                title: Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                subtitle: item.description != null &&
                                        item.description!.isNotEmpty
                                    ? Text(item.description!)
                                    : null,
                                trailing: item.price != null
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '€${item.price!.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.add_shopping_cart),
                                            onPressed: () {
                                              setState(() {
                                                cart.addItem(CartItem(
                                                  itemId: item.id,
                                                  itemName: item.name,
                                                  variantId: null,
                                                  variantName: null,
                                                  price: item.price!,
                                                  quantity: 1,
                                                ));
                                              });
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      '${item.name} added to cart'),
                                                  duration: const Duration(
                                                      seconds: 1),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            }
                          }).toList(),
                        );
                      },
                    ),
    );
  }
}
