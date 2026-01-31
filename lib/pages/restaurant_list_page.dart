import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cart.dart';
import '../models/restaurant.dart';
import 'menu_page.dart';

class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key});

  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  List<Restaurant> restaurants = [];
  List<Restaurant> filteredRestaurants = [];
  bool loading = true;
  String? errorMessage;

  // Filter states
  Set<String> selectedCuisineTypes = {};
  Set<String> selectedPaymentMethods = {};
  bool? filterDeliveryOnly;
  bool showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl != null &&
          supabaseKey != null &&
          supabaseUrl.isNotEmpty &&
          supabaseKey.isNotEmpty) {
        final response = await Supabase.instance.client
            .from('restaurants')
            .select(
                'id, name, address, email, phone, description, image_url, cuisine_type, delivers, opening_hours, payment_methods')
            .order('name');

        if (response is List) {
          setState(() {
            restaurants = response
                .map((r) => Restaurant.fromJson(r as Map<String, dynamic>))
                .toList();
            loading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Supabase not configured. Please check .env file.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading restaurants: $e';
        loading = false;
      });
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchMaps(String address) async {
    final Uri uri = Uri.https(
        'www.google.com', '/maps/search/', {'api': '1', 'query': address});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showOpeningHours(BuildContext context, Restaurant restaurant) {
    if (restaurant.openingHours == null) return;

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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${restaurant.name} - Opening Hours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: days.asMap().entries.map((entry) {
            final index = entry.key;
            final dayLabel = entry.value['label']!;
            final dayKey = entry.value['key']!;
            final hours = restaurant.openingHours![dayKey];
            final isToday = index == todayIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      dayLabel,
                      style: TextStyle(
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
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
          }).toList(),
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

  List<Restaurant> _applyFilters() {
    if (selectedCuisineTypes.isEmpty &&
        selectedPaymentMethods.isEmpty &&
        filterDeliveryOnly == null) {
      return restaurants;
    }

    return restaurants.where((restaurant) {
      // Filter by cuisine type
      if (selectedCuisineTypes.isNotEmpty) {
        if (restaurant.cuisineType == null ||
            !selectedCuisineTypes.contains(restaurant.cuisineType)) {
          return false;
        }
      }

      // Filter by delivery
      if (filterDeliveryOnly == true && !restaurant.delivers) {
        return false;
      }

      // Filter by payment methods
      if (selectedPaymentMethods.isNotEmpty) {
        if (restaurant.paymentMethods == null ||
            !selectedPaymentMethods
                .any((method) => restaurant.paymentMethods!.contains(method))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Set<String> _getAvailableCuisineTypes() {
    return restaurants
        .where((r) => r.cuisineType != null)
        .map((r) => r.cuisineType!)
        .toSet();
  }

  Set<String> _getAvailablePaymentMethods() {
    final allMethods = <String>{};
    for (final restaurant in restaurants) {
      if (restaurant.paymentMethods != null) {
        allMethods.addAll(restaurant.paymentMethods!);
      }
    }
    return allMethods;
  }

  @override
  Widget build(BuildContext context) {
    final displayRestaurants = _applyFilters();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Restaurant',
            style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                showFilters = !showFilters;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.cyan.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(errorMessage!, textAlign: TextAlign.center),
                  ))
                : restaurants.isEmpty
                    ? const Center(child: Text('No restaurants found'))
                    : Column(
                        children: [
                          if (showFilters) _buildFilterPanel(),
                          Expanded(
                            child: displayRestaurants.isEmpty
                                ? const Center(
                                    child: Text('No restaurants match filters'))
                                : ListView.builder(
                                    itemCount: displayRestaurants.length,
                                    itemBuilder: (context, index) {
                                      final restaurant =
                                          displayRestaurants[index];
                                      final restaurantCart = CartManager()
                                          .getCartForRestaurant(restaurant.id);
                                      final hasItems =
                                          restaurantCart.items.isNotEmpty;

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white,
                                                Colors.teal.shade50
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            onTap: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      MenuPage(
                                                          restaurant:
                                                              restaurant),
                                                ),
                                              );
                                              // Refresh the list to update cart badges
                                              setState(() {});
                                            },
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Restaurant Image
                                                if (restaurant.imageUrl != null)
                                                  ClipRRect(
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(16),
                                                      topRight:
                                                          Radius.circular(16),
                                                    ),
                                                    child: Image.network(
                                                      restaurant.imageUrl!,
                                                      height: 180,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          Container(
                                                        height: 180,
                                                        color: Colors.grey[300],
                                                        child: const Icon(
                                                          Icons.restaurant,
                                                          size: 64,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              restaurant.name,
                                                              style: TextStyle(
                                                                  fontSize: 22,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .teal
                                                                      .shade800),
                                                            ),
                                                          ),
                                                          if (hasItems)
                                                            Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      right: 8),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          6),
                                                              decoration:
                                                                  BoxDecoration(
                                                                gradient:
                                                                    const LinearGradient(
                                                                  colors: [
                                                                    Colors
                                                                        .orange,
                                                                    Colors
                                                                        .deepOrange
                                                                  ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .orange
                                                                        .withOpacity(
                                                                            0.3),
                                                                    blurRadius:
                                                                        4,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            2),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .shopping_cart,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .white),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Text(
                                                                    '${restaurantCart.itemCount}',
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          if (restaurant
                                                              .delivers)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          6),
                                                              decoration:
                                                                  BoxDecoration(
                                                                gradient:
                                                                    const LinearGradient(
                                                                  colors: [
                                                                    Colors
                                                                        .green,
                                                                    Colors
                                                                        .lightGreen
                                                                  ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .green
                                                                        .withOpacity(
                                                                            0.3),
                                                                    blurRadius:
                                                                        4,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            2),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: const Text(
                                                                  'Delivery',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  )),
                                                            ),
                                                        ],
                                                      ),
                                                      if (restaurant
                                                              .description !=
                                                          null) ...[
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                            restaurant
                                                                .description!,
                                                            style: TextStyle(
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .grey
                                                                    .shade700)),
                                                      ],
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(10),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(0.7),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            InkWell(
                                                              onTap: () =>
                                                                  _launchMaps(
                                                                      restaurant
                                                                          .address),
                                                              child: Row(
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .location_on,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .blue),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Expanded(
                                                                    child: Text(
                                                                        restaurant
                                                                            .address,
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.blue,
                                                                            decoration: TextDecoration.underline)),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            if (restaurant
                                                                    .phone !=
                                                                null) ...[
                                                              const SizedBox(
                                                                  height: 4),
                                                              InkWell(
                                                                onTap: () =>
                                                                    _launchPhone(
                                                                        restaurant
                                                                            .phone!),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(
                                                                        Icons
                                                                            .phone,
                                                                        size:
                                                                            14,
                                                                        color: Colors
                                                                            .blue),
                                                                    const SizedBox(
                                                                        width:
                                                                            4),
                                                                    Text(
                                                                        restaurant
                                                                            .phone!,
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.blue,
                                                                            decoration: TextDecoration.underline)),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                            if (restaurant
                                                                    .getTodayHours() !=
                                                                null) ...[
                                                              const SizedBox(
                                                                  height: 4),
                                                              InkWell(
                                                                onTap: () =>
                                                                    _showOpeningHours(
                                                                        context,
                                                                        restaurant),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(
                                                                        Icons
                                                                            .access_time,
                                                                        size:
                                                                            14,
                                                                        color: Colors
                                                                            .blue),
                                                                    const SizedBox(
                                                                        width:
                                                                            4),
                                                                    Text(
                                                                      'Today: ${restaurant.getTodayHours()}',
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color: Colors
                                                                              .blue,
                                                                          decoration:
                                                                              TextDecoration.underline),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                            if (restaurant
                                                                        .paymentMethods !=
                                                                    null &&
                                                                restaurant
                                                                    .paymentMethods!
                                                                    .isNotEmpty) ...[
                                                              const SizedBox(
                                                                  height: 8),
                                                              Wrap(
                                                                spacing: 6,
                                                                runSpacing: 6,
                                                                children: restaurant
                                                                    .paymentMethods!
                                                                    .map(
                                                                        (method) {
                                                                  return Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            6),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      gradient:
                                                                          LinearGradient(
                                                                        colors: [
                                                                          Colors
                                                                              .purple
                                                                              .shade300,
                                                                          Colors
                                                                              .purple
                                                                              .shade500
                                                                        ],
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              15),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color: Colors
                                                                              .purple
                                                                              .withOpacity(0.3),
                                                                          blurRadius:
                                                                              3,
                                                                          offset: const Offset(
                                                                              0,
                                                                              2),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Text(
                                                                        method,
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight: FontWeight.w500)),
                                                                  );
                                                                }).toList(),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    final cuisineTypes = _getAvailableCuisineTypes();
    final paymentMethods = _getAvailablePaymentMethods();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (selectedCuisineTypes.isNotEmpty ||
                  selectedPaymentMethods.isNotEmpty ||
                  filterDeliveryOnly != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedCuisineTypes.clear();
                      selectedPaymentMethods.clear();
                      filterDeliveryOnly = null;
                    });
                  },
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Delivery filter
          SwitchListTile(
            title: const Text('Delivery Only'),
            value: filterDeliveryOnly ?? false,
            onChanged: (value) {
              setState(() {
                filterDeliveryOnly = value ? true : null;
              });
            },
            activeColor: Colors.teal,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 12),

          // Cuisine type filters
          if (cuisineTypes.isNotEmpty) ...[
            const Text(
              'Cuisine Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cuisineTypes.map((type) {
                final isSelected = selectedCuisineTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCuisineTypes.add(type);
                      } else {
                        selectedCuisineTypes.remove(type);
                      }
                    });
                  },
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Payment method filters
          if (paymentMethods.isNotEmpty) ...[
            const Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: paymentMethods.map((method) {
                final isSelected = selectedPaymentMethods.contains(method);
                return FilterChip(
                  label: Text(method),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedPaymentMethods.add(method);
                      } else {
                        selectedPaymentMethods.remove(method);
                      }
                    });
                  },
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
