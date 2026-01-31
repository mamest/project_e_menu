import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:convert';
import 'dart:math';

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

  // Location filter states
  final TextEditingController _addressController = TextEditingController();
  double? userLatitude;
  double? userLongitude;
  double radiusKm = 5.0;
  bool _filterByLocation = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Get GPS location first, then load restaurants
    await _getCurrentLocation(showSnackbar: false);
    // Pass location to load only nearby restaurants
    if (userLatitude != null && userLongitude != null && _filterByLocation) {
      await _loadRestaurants(
        latitude: userLatitude!,
        longitude: userLongitude!,
        radiusKm: radiusKm,
      );
    } else {
      await _loadRestaurants();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  // ============ DATA LOADING ============

  // Calculate bounding box for server-side filtering
  Map<String, double> _calculateBoundingBox(
      double lat, double lon, double radiusKm) {
    // Earth's radius in kilometers
    const earthRadius = 6371.0;

    // Calculate latitude range (simpler calculation)
    final latDelta = (radiusKm / earthRadius) * (180 / pi);

    // Calculate longitude range (accounts for latitude)
    final lonDelta =
        (radiusKm / (earthRadius * cos(lat * pi / 180))) * (180 / pi);

    return {
      'minLat': lat - latDelta,
      'maxLat': lat + latDelta,
      'minLon': lon - lonDelta,
      'maxLon': lon + lonDelta,
    };
  }

  Future<void> _loadRestaurants({
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl != null &&
          supabaseKey != null &&
          supabaseUrl.isNotEmpty &&
          supabaseKey.isNotEmpty) {
        var query = Supabase.instance.client.from('restaurants').select(
            'id, name, address, email, phone, description, image_url, cuisine_type, delivers, opening_hours, payment_methods, latitude, longitude');

        // Apply server-side location filtering with bounding box
        if (latitude != null && longitude != null && radiusKm != null) {
          final bbox = _calculateBoundingBox(latitude, longitude, radiusKm);
          query = query
              .gte('latitude', bbox['minLat']!)
              .lte('latitude', bbox['maxLat']!)
              .gte('longitude', bbox['minLon']!)
              .lte('longitude', bbox['maxLon']!);
        }

        final response = await query.order('name');

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

  // ============ FILTERING ============

  List<Restaurant> _applyFilters() {
    if (selectedCuisineTypes.isEmpty &&
        selectedPaymentMethods.isEmpty &&
        filterDeliveryOnly == null &&
        !_filterByLocation) {
      return restaurants;
    }

    return restaurants.where((restaurant) {
      // Location filtering is now handled server-side via bounding box
      // We only need to apply precise distance filtering for edge cases
      if (_filterByLocation && userLatitude != null && userLongitude != null) {
        final distance = restaurant.distanceFrom(userLatitude, userLongitude);
        if (distance == null || distance > radiusKm) return false;
      }

      if (selectedCuisineTypes.isNotEmpty) {
        if (restaurant.cuisineType == null ||
            !selectedCuisineTypes.contains(restaurant.cuisineType)) {
          return false;
        }
      }

      if (filterDeliveryOnly == true && !restaurant.delivers) {
        return false;
      }

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

  // ============ GPS LOCATION ============

  Future<void> _getCurrentLocation({bool showSnackbar = true}) async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
        });
        if (showSnackbar) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Location services are disabled. Please enable them.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoadingLocation = false;
          });
          if (showSnackbar) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
        });
        if (showSnackbar) {
          _showPermissionDeniedDialog();
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLatitude = position.latitude;
        userLongitude = position.longitude;
        _filterByLocation = true;
        _isLoadingLocation = false;
        _addressController.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });

      // Reload restaurants with server-side filtering
      if (!mounted) return;
      await _loadRestaurants(
        latitude: userLatitude!,
        longitude: userLongitude!,
        radiusKm: radiusKm,
      );

      if (!mounted) return;
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using your current location'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
      });
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location permission to show nearby restaurants. '
          'Please enable location permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ============ GEOCODING ============

  Future<List<Map<String, dynamic>>> _getAddressSuggestions(
      String query) async {
    if (query.isEmpty || query.length < 3) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5&addressdetails=1');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterMenuApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results
            .map((result) => {
                  'display_name': result['display_name'] as String,
                  'lat': double.parse(result['lat']),
                  'lon': double.parse(result['lon']),
                })
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
    return [];
  }

  Future<void> _geocodeAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an address')),
      );
      return;
    }

    final coordPattern = RegExp(r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$');
    final match = coordPattern.firstMatch(address);

    if (match != null) {
      setState(() {
        userLatitude = double.parse(match.group(1)!);
        userLongitude = double.parse(match.group(2)!);
        _filterByLocation = true;
      });
      // Reload with server-side filtering
      await _loadRestaurants(
        latitude: userLatitude!,
        longitude: userLongitude!,
        radiusKm: radiusKm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location filter applied')),
      );
      return;
    }

    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterMenuApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lon = double.parse(results[0]['lon']);

          setState(() {
            userLatitude = lat;
            userLongitude = lon;
            _filterByLocation = true;
          });

          // Reload with server-side filtering
          await _loadRestaurants(
            latitude: userLatitude!,
            longitude: userLongitude!,
            radiusKm: radiusKm,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location filter applied')),
          );
          return;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Address not found. Try entering coordinates instead.')),
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geocoding error: ${e.toString()}')),
      );
      return;
    }

    if (!mounted) return;
    _showGeocodingFailedDialog();
  }

  void _showGeocodingFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geocoding Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Please enter coordinates in format: latitude, longitude'),
            SizedBox(height: 8),
            Text('Example: 52.520007, 13.404954'),
            SizedBox(height: 16),
            Text(
                'Or search for your address on Google Maps and copy the coordinates.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ============ EXTERNAL ACTIONS ============

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

  // ============ MAIN BUILD ============

  @override
  Widget build(BuildContext context) {
    final displayRestaurants = _applyFilters();

    return Scaffold(
      appBar: _buildAppBar(),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade50, Colors.cyan.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _buildBody(displayRestaurants),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }

  Widget _buildBody(List<Restaurant> displayRestaurants) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    if (restaurants.isEmpty) {
      return const Center(child: Text('No restaurants found'));
    }

    return Column(
      children: [
        if (showFilters) _buildFilterPanel(),
        Expanded(
          child: displayRestaurants.isEmpty
              ? const Center(child: Text('No restaurants match filters'))
              : ListView.builder(
                  itemCount: displayRestaurants.length,
                  itemBuilder: (context, index) =>
                      _buildRestaurantCard(displayRestaurants[index]),
                ),
        ),
      ],
    );
  }

  // ============ RESTAURANT CARD ============

  Widget _buildRestaurantCard(Restaurant restaurant) {
    final restaurantCart = CartManager().getCartForRestaurant(restaurant.id);
    final hasItems = restaurantCart.items.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.teal.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MenuPage(restaurant: restaurant),
              ),
            );
            setState(() {});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (restaurant.imageUrl != null)
                _buildRestaurantImage(restaurant),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRestaurantHeader(
                        restaurant, hasItems, restaurantCart),
                    if (restaurant.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        restaurant.description!,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildRestaurantDetails(restaurant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantImage(Restaurant restaurant) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: Image.network(
        restaurant.imageUrl!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 180,
          color: Colors.grey[300],
          child: const Icon(Icons.restaurant, size: 64, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader(
      Restaurant restaurant, bool hasItems, Cart restaurantCart) {
    return Row(
      children: [
        Expanded(
          child: Text(
            restaurant.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
        ),
        if (hasItems) _buildCartBadge(restaurantCart),
        if (restaurant.delivers) _buildDeliveryBadge(),
      ],
    );
  }

  Widget _buildCartBadge(Cart cart) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_cart, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${cart.itemCount}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [Colors.green, Colors.lightGreen]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'Delivery',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRestaurantDetails(Restaurant restaurant) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _buildAddressRow(restaurant),
          if (restaurant.phone != null) ...[
            const SizedBox(height: 4),
            _buildPhoneRow(restaurant),
          ],
          if (restaurant.getTodayHours() != null) ...[
            const SizedBox(height: 4),
            _buildHoursRow(restaurant),
          ],
          if (restaurant.paymentMethods != null &&
              restaurant.paymentMethods!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPaymentMethods(restaurant),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressRow(Restaurant restaurant) {
    return InkWell(
      onTap: () => _launchMaps(restaurant.address),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              restaurant.address,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneRow(Restaurant restaurant) {
    return InkWell(
      onTap: () => _launchPhone(restaurant.phone!),
      child: Row(
        children: [
          const Icon(Icons.phone, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            restaurant.phone!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursRow(Restaurant restaurant) {
    return InkWell(
      onTap: () => _showOpeningHours(context, restaurant),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            'Today: ${restaurant.getTodayHours()}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(Restaurant restaurant) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: restaurant.paymentMethods!.map((method) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade300, Colors.purple.shade500],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            method,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============ FILTER PANEL ============

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
          _buildFilterHeader(),
          const SizedBox(height: 12),
          _buildLocationFilter(),
          const SizedBox(height: 12),
          _buildDeliveryFilter(),
          const SizedBox(height: 12),
          if (cuisineTypes.isNotEmpty) ...[
            _buildCuisineFilter(cuisineTypes),
            const SizedBox(height: 12),
          ],
          if (paymentMethods.isNotEmpty) _buildPaymentFilter(paymentMethods),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Row(
      children: [
        const Text(
          'Filters',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (selectedCuisineTypes.isNotEmpty ||
            selectedPaymentMethods.isNotEmpty ||
            filterDeliveryOnly != null ||
            _filterByLocation)
          TextButton(
            onPressed: () {
              setState(() {
                selectedCuisineTypes.clear();
                selectedPaymentMethods.clear();
                filterDeliveryOnly = null;
                _filterByLocation = false;
                _addressController.clear();
                userLatitude = null;
                userLongitude = null;
              });
            },
            child: const Text('Clear All'),
          ),
      ],
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Location',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: _addressController,
                  suggestionsCallback: (search) =>
                      _getAddressSuggestions(search),
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Enter address or coordinates',
                        prefixIcon:
                            const Icon(Icons.location_on, color: Colors.teal),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _geocodeAddress(),
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading:
                          const Icon(Icons.location_on, color: Colors.teal),
                      title: Text(
                        suggestion['display_name'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  },
                  onSelected: (suggestion) async {
                    setState(() {
                      userLatitude = suggestion['lat'];
                      userLongitude = suggestion['lon'];
                      _filterByLocation = true;
                      _addressController.text = suggestion['display_name'];
                    });
                    // Reload with server-side filtering
                    await _loadRestaurants(
                      latitude: userLatitude!,
                      longitude: userLongitude!,
                      radiusKm: radiusKm,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Location filter applied')),
                    );
                  },
                  emptyBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No addresses found. Try entering coordinates like: 52.520007, 13.404954'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                tooltip: 'Use current location',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Radius: '),
              Expanded(
                child: Slider(
                  value: radiusKm,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: '${radiusKm.toStringAsFixed(0)} km',
                  activeColor: Colors.teal,
                  onChanged: (value) {
                    setState(() {
                      radiusKm = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    // Reload with new radius when user finishes sliding
                    if (_filterByLocation &&
                        userLatitude != null &&
                        userLongitude != null) {
                      await _loadRestaurants(
                        latitude: userLatitude!,
                        longitude: userLongitude!,
                        radiusKm: radiusKm,
                      );
                    }
                  },
                ),
              ),
              Text('${radiusKm.toStringAsFixed(0)} km'),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _geocodeAddress,
            icon: const Icon(Icons.search),
            label: const Text('Apply Location Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
          if (_filterByLocation) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                const Text('Location filter active',
                    style: TextStyle(fontSize: 12, color: Colors.green)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    setState(() {
                      _filterByLocation = false;
                      _addressController.clear();
                      userLatitude = null;
                      userLongitude = null;
                    });
                    // Reload all restaurants without filtering
                    await _loadRestaurants();
                  },
                  child: const Text('Remove', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryFilter() {
    return SwitchListTile(
      title: const Text('Delivery Only'),
      value: filterDeliveryOnly ?? false,
      onChanged: (value) {
        setState(() {
          filterDeliveryOnly = value ? true : null;
        });
      },
      activeColor: Colors.teal,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCuisineFilter(Set<String> cuisineTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cuisine Type',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
      ],
    );
  }

  Widget _buildPaymentFilter(Set<String> paymentMethods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Methods',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    );
  }
}
