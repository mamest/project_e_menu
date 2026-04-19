import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show appLocaleNotifier, setAppLocale;
import '../models/cart.dart';
import '../models/restaurant.dart';
import '../services/auth_service.dart';
import '../utils/payment_utils.dart';
import 'menu_page.dart';
import 'admin_upload_page.dart';
import 'login_page.dart';
import 'edit_restaurant_page.dart';
import 'create_restaurant_page.dart';
import 'subscription_page.dart';

class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key});

  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  List<Restaurant> restaurants = [];
  List<Restaurant> filteredRestaurants = [];
  int _ownerRestaurantCount = 0;
  bool loading = true;
  String? errorMessage;

  // Filter states
  Set<String> selectedCuisineTypes = {};
  Set<String> selectedPaymentMethods = {};
  bool? filterDeliveryOnly;
  bool showFilters = false;
  bool filterFavoritesOnly = false;

  // Favorites
  Set<int> _favoriteIds = {};

  // Location filter states
  final TextEditingController _addressController = TextEditingController();
  double? userLatitude;
  double? userLongitude;
  double radiusKm = 5.0;
  bool _filterByLocation = false;
  bool _isLoadingLocation = false;

  // Auth
  final AuthService _authService = AuthService();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Rebuild the UI whenever the auth state changes (e.g. after OAuth redirect).
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        await _authService.loadProfile();
        if (_authService.isRestaurantOwner) await _loadOwnerRestaurants();
        await _loadFavorites();
      }
      if (event.event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _favoriteIds = {});
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeApp() async {
    // Load profile if already signed in
    if (_authService.isLoggedIn) {
      await _authService.loadProfile();
      if (_authService.isRestaurantOwner) await _loadOwnerRestaurants();
      await _loadFavorites();
    }
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
    // Handle deep link: ?r={restaurantId}
    _handleDeepLink();
  }

  void _handleDeepLink() {
    final idStr = Uri.base.queryParameters['r'];
    if (idStr == null) return;
    final id = int.tryParse(idStr);
    if (id == null) return;
    final target = restaurants.cast<Restaurant?>().firstWhere(
          (r) => r!.id == id,
          orElse: () => null,
        );
    if (target != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MenuPage(restaurant: target)),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
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
            'id, name, address, email, phone, description, image_url, cuisine_type, delivers, opening_hours, payment_methods, latitude, longitude, restaurant_owner_uuid, menu_html_url, menu_updated_at, updated_at, translations, google_place_id, google_data');

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
          errorMessage = AppLocalizations.of(context)!.supabaseNotConfigured;
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = AppLocalizations.of(context)!.errorLoadingRestaurants(e.toString());
        loading = false;
      });
    }
  }

  /// Fetches all restaurants owned by the current user directly from Supabase,
  /// bypassing any location/filter constraints on the main list.
  Future<List<Restaurant>> _loadOwnerRestaurants() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return [];
      final response = await Supabase.instance.client
          .from('restaurants')
          .select('id, name, address, email, phone, description, image_url, cuisine_type, delivers, opening_hours, payment_methods, latitude, longitude, restaurant_owner_uuid, menu_html_url, menu_updated_at, updated_at, translations, google_place_id, google_data')
          .eq('restaurant_owner_uuid', userId)
          .order('name');
      if (response is List) {
        final list = response.map((r) => Restaurant.fromJson(r as Map<String, dynamic>)).toList();
        if (mounted) setState(() => _ownerRestaurantCount = list.length);
        return list;
      }
    } catch (_) {}
    return [];
  }

  // ============ FAVORITES ============

  Future<void> _loadFavorites() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('user_favorites')
          .select('restaurant_id')
          .eq('user_id', userId);
      if (response is List && mounted) {
        setState(() {
          _favoriteIds =
              response.map<int>((r) => r['restaurant_id'] as int).toSet();
        });
      }
    } catch (e) {
      debugPrint('_loadFavorites error: $e');
    }
  }

  Future<void> _toggleFavorite(int restaurantId) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.signInToFavorite)),
      );
      return;
    }
    final isFav = _favoriteIds.contains(restaurantId);
    // Optimistic update
    setState(() {
      if (isFav) {
        _favoriteIds.remove(restaurantId);
      } else {
        _favoriteIds.add(restaurantId);
      }
    });
    try {
      if (isFav) {
        await Supabase.instance.client
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('restaurant_id', restaurantId);
      } else {
        await Supabase.instance.client.from('user_favorites').upsert({
          'user_id': userId,
          'restaurant_id': restaurantId,
        });
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isFav) {
            _favoriteIds.add(restaurantId);
          } else {
            _favoriteIds.remove(restaurantId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // ============ SHARE ============

  Future<void> _shareRestaurant(Restaurant restaurant) async {
    final baseUrl = Uri.base.origin;
    final fullUrl = '$baseUrl/?r=${restaurant.id}';

    String shareUrl = fullUrl;
    try {
      final response = await http.get(
        Uri.parse(
            'https://is.gd/create.php?format=simple&url=${Uri.encodeComponent(fullUrl)}'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.body.startsWith('http')) {
        shareUrl = response.body.trim();
      }
    } catch (_) {
      // Fall back to the full URL if shortening fails
    }

    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.linkCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============ FILTERING ============

  List<Restaurant> _applyFilters() {
    if (selectedCuisineTypes.isEmpty &&
        selectedPaymentMethods.isEmpty &&
        filterDeliveryOnly == null &&
        !_filterByLocation &&
        !filterFavoritesOnly) {
      return restaurants;
    }

    return restaurants.where((restaurant) {
      // Favorites filter
      if (filterFavoritesOnly && !_favoriteIds.contains(restaurant.id)) {
        return false;
      }

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
            SnackBar(
              content: Text(AppLocalizations.of(context)!.locationServicesDisabled),
              duration: const Duration(seconds: 3),
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
              SnackBar(
                content: Text(AppLocalizations.of(context)!.locationPermissionDenied),
                duration: const Duration(seconds: 3),
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.usingCurrentLocation),
            duration: const Duration(seconds: 2),
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
            content: Text(AppLocalizations.of(context)!.errorGettingLocation(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.locationPermissionRequired),
        content: Text(l10n.locationPermissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: Text(l10n.openSettings),
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
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterAddress)),
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
        SnackBar(content: Text(AppLocalizations.of(context)!.locationFilterApplied)),
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
            SnackBar(content: Text(AppLocalizations.of(context)!.locationFilterApplied)),
          );
          return;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.addressNotFound)),
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.geocodingError(e.toString()))),
      );
      return;
    }

    if (!mounted) return;
    _showGeocodingFailedDialog();
  }

  void _showGeocodingFailedDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.geocodingFailed),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.geocodingInstructions),
            const SizedBox(height: 8),
            Text(l10n.geocodingExample),
            const SizedBox(height: 16),
            Text(l10n.geocodingMapsHint),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
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
    final l10n = AppLocalizations.of(context)!;

    final days = [
      {'label': l10n.dayMonday, 'key': 'monday'},
      {'label': l10n.dayTuesday, 'key': 'tuesday'},
      {'label': l10n.dayWednesday, 'key': 'wednesday'},
      {'label': l10n.dayThursday, 'key': 'thursday'},
      {'label': l10n.dayFriday, 'key': 'friday'},
      {'label': l10n.daySaturday, 'key': 'saturday'},
      {'label': l10n.daySunday, 'key': 'sunday'},
    ];

    final todayIndex = DateTime.now().weekday - 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.openingHoursDialog(restaurant.name)),
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
                        color: isToday ? const Color(0xFF7C3AED) : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    hours?.toString() ?? l10n.closed,
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday
                          ? const Color(0xFF7C3AED)
                          : (hours == null ? Colors.red : Colors.black87),
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
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionRequiredDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.subscriptionRequiredTitle),
        content: Text(l10n.subscriptionRequiredMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPage()),
              ).then((_) => setState(() {}));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.viewPlans),
          ),
        ],
      ),
    );
  }

  // ============ EDIT RESTAURANT PICKER ============

  Future<void> _showEditRestaurantPicker(List<Restaurant> myRestaurants) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  AppLocalizations.of(context)!.selectRestaurantToEdit,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: myRestaurants.length,
                  itemBuilder: (_, index) {
                    final r = myRestaurants[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEDE9FE),
                        backgroundImage: r.imageUrl != null ? NetworkImage(r.imageUrl!) : null,
                        child: r.imageUrl == null
                            ? const Icon(Icons.store, color: Color(0xFF7C3AED))
                            : null,
                      ),
                      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(r.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF7C3AED)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditRestaurantPage(restaurant: r),
                          ),
                        );
                        _loadRestaurants();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ============ QR CODE ============
  // TODO(native-apps): When building the Android/iOS app, enable deep linking so
  //   scanning the QR code opens the app directly if it is installed, instead of
  //   falling back to the browser.
  //   Steps required:
  //   1. Add the `app_links` package to pubspec.yaml.
  //   2. In the native app, listen to incoming links and route /?r=<id> to the
  //      correct restaurant's menu screen.
  //   3. Android: declare <intent-filter> with autoVerify=true in AndroidManifest.xml
  //      and host /.well-known/assetlinks.json on APP_BASE_URL domain.
  //   4. iOS: enable Associated Domains (applinks:<domain>) in Entitlements.plist
  //      and host /.well-known/apple-app-site-association on APP_BASE_URL domain.
  //   The QR code URL format (https://<domain>/?r=<id>) already matches and needs
  //   no changes.

  Future<void> _pickRestaurantForQr() async {
    final myRestaurants = await _loadOwnerRestaurants();
    if (!mounted) return;
    if (myRestaurants.length == 1) {
      _showQrCodeDialog(myRestaurants.first);
    } else if (myRestaurants.length > 1) {
      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, sc) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.qr_code, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.generateQrCode,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: myRestaurants.length,
                  itemBuilder: (_, i) {
                    final r = myRestaurants[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEDE9FE),
                        backgroundImage:
                            r.imageUrl != null ? NetworkImage(r.imageUrl!) : null,
                        child: r.imageUrl == null
                            ? const Icon(Icons.store, color: Color(0xFF7C3AED))
                            : null,
                      ),
                      title: Text(r.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(r.address,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.qr_code_2,
                          color: Color(0xFF7C3AED)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQrCodeDialog(r);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
  }

  /// Returns the stable base URL for QR codes.
  /// Prefers APP_BASE_URL from .env so QR codes survive domain / platform changes.
  /// Falls back to the current browser origin for local development only.
  String get _appBaseUrl {
    final configured = dotenv.env['APP_BASE_URL'];
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim().replaceAll(RegExp(r'/$'), '');
    }
    // Fallback: works only in Flutter Web. Native apps should always have APP_BASE_URL set.
    try {
      return Uri.base.origin;
    } catch (_) {
      return '';
    }
  }

  void _showQrCodeDialog(Restaurant restaurant) {
    final url = '$_appBaseUrl/?r=${restaurant.id}';
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.qr_code, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.qrCodeTitle} – ${restaurant.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: SizedBox(
          width: 280,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 2),
              ),
              padding: const EdgeInsets.all(12),
              child: RepaintBoundary(
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 236,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF6D28D9),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1E1E2E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              url,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: Text(l10n.downloadQrCode),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _downloadQrCode(restaurant, url),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQrCode(Restaurant restaurant, String url) async {
    try {
      final qrPainter = QrPainter(
        data: url,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF6D28D9),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF1E1E2E),
        ),
      );

      const size = 1024.0;
      final imageData = await qrPainter.toImageData(size);
      if (imageData == null) return;

      final bytes = imageData.buffer.asUint8List();
      final blob = html.Blob([bytes], 'image/png');
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: objectUrl)
        ..setAttribute(
            'download', '${restaurant.name.replaceAll(' ', '_')}_qr.png')
        ..click();
      html.Url.revokeObjectUrl(objectUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  // ============ FAVORITES SHEET ============

  void _showFavoritesSheet() {
    final favoriteRestaurants = restaurants
        .where((r) => _favoriteIds.contains(r.id))
        .toList();
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.myFavorites,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: favoriteRestaurants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(l10n.noFavoritesYet,
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: favoriteRestaurants.length,
                        itemBuilder: (_, index) {
                          final r = favoriteRestaurants[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEDE9FE),
                              backgroundImage:
                                  r.imageUrl != null ? NetworkImage(r.imageUrl!) : null,
                              child: r.imageUrl == null
                                  ? const Icon(Icons.restaurant, color: Color(0xFF7C3AED))
                                  : null,
                            ),
                            title: Text(r.name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(r.address,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right,
                                color: Color(0xFF7C3AED)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MenuPage(restaurant: r),
                                ),
                              );
                              setState(() {});
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ============ CART COMPARISON ============

  void _showCompareSheet() {
    final activeCarts = CartManager().getActiveCarts();
    // Match active cart restaurant IDs against the loaded restaurants list
    final compareRestaurants = restaurants
        .where((r) => activeCarts.containsKey(r.id))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CompareSheet(
        compareRestaurants: compareRestaurants,
        activeCarts: activeCarts,
        onCartChanged: () => setState(() {}),
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
              colors: [
                const Color(0xFFF5F7FA),
                Colors.purple.shade50.withOpacity(0.3),
                const Color(0xFFEDE9FE).withOpacity(0.4),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _buildBody(displayRestaurants),
        ),
      ),
    );
  }

  // ============ LANGUAGE PICKER ============

  /// Shows the 2-letter code for the currently active locale.
  String _languageLabel(BuildContext context) {
    final code = (appLocaleNotifier.value?.languageCode ??
            Localizations.localeOf(context).languageCode)
        .toUpperCase();
    return code;
  }

  void _showLanguagePicker() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: appLocaleNotifier,
          builder: (_, currentLocale, __) {
            return SimpleDialog(
              title: Text(l10n.selectLanguage),
              children: [
                _LanguageOption(
                  label: '🇩🇪  Deutsch',
                  isSelected: currentLocale?.languageCode == 'de',
                  onTap: () async {
                    await setAppLocale(const Locale('de'));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                _LanguageOption(
                  label: '🇬🇧  English',
                  isSelected: currentLocale?.languageCode == 'en',
                  onTap: () async {
                    await setAppLocale(const Locale('en'));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const Divider(),
                _LanguageOption(
                  label: '⚙️  ${l10n.languageSystemDefault}',
                  isSelected: currentLocale == null,
                  onTap: () async {
                    await setAppLocale(null);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        AppLocalizations.of(context)!.selectRestaurant,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (CartManager().getTotalCartsCount() >= 2)
                        IconButton(
                          icon: const Icon(Icons.compare_arrows),
                          tooltip: AppLocalizations.of(context)!.compareRestaurants,
                          onPressed: () => _showCompareSheet(),
                        ),
                      IconButton(
                        icon: Text(
                          _languageLabel(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        tooltip: AppLocalizations.of(context)!.selectLanguage,
                        onPressed: _showLanguagePicker,
                      ),
                      IconButton(
                        icon: Icon(showFilters ? Icons.filter_list_off : Icons.filter_list),
                        onPressed: () {
                          setState(() {
                            showFilters = !showFilters;
                          });
                        },
                      ),
                      _authService.isLoggedIn
                          ? PopupMenuButton<String>(
                              icon: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: _authService.userAvatarUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          _authService.userAvatarUrl!,
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(Icons.person, color: Color(0xFF7C3AED));
                                          },
                                        ),
                                      )
                                    : const Icon(Icons.person, color: Color(0xFF7C3AED)),
                              ),
                              onSelected: (value) async {
                                if (value == 'logout') {
                                  await _authService.signOut();
                                  setState(() {});
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(AppLocalizations.of(context)!.signedOutSuccessfully)),
                                    );
                                  }
                                } else if (value == 'my_plan') {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SubscriptionPage(),
                                    ),
                                  );
                                  setState(() {}); // refresh role/subscription state
                                } else if (value == 'create_manual') {
                                  if (!_authService.isSubscriptionActive) {
                                    _showSubscriptionRequiredDialog();
                                    return;
                                  }
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CreateRestaurantPage(),
                                    ),
                                  );
                                  if (result == true) _loadRestaurants();
                                } else if (value == 'upload_pdf') {
                                  if (!_authService.isSubscriptionActive) {
                                    _showSubscriptionRequiredDialog();
                                    return;
                                  }
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AdminUploadPage(),
                                    ),
                                  );
                                  if (result == true) _loadRestaurants();
                                } else if (value == 'edit_restaurant') {
                                  final myRestaurants = await _loadOwnerRestaurants();
                                  if (myRestaurants.length == 1 && mounted) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditRestaurantPage(restaurant: myRestaurants.first),
                                      ),
                                    );
                                    _loadRestaurants();
                                  } else if (myRestaurants.length > 1 && mounted) {
                                    await _showEditRestaurantPicker(myRestaurants);
                                  }
                                } else if (value == 'qr_code') {
                                  await _pickRestaurantForQr();
                                } else if (value == 'my_favorites') {
                                  _showFavoritesSheet();
                                }
                              },
                              itemBuilder: (context) {
                                final isOwner = _authService.isRestaurantOwner;
                                final isActive = _authService.isSubscriptionActive;
                                final myRestaurants = restaurants.where(
                                  (r) => r.restaurantOwnerUuid == _authService.currentUser?.id,
                                ).toList();
                                final count = _ownerRestaurantCount > 0 ? _ownerRestaurantCount : myRestaurants.length;
                                return [
                                  // ── User header ──
                                  PopupMenuItem<String>(
                                    enabled: false,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _authService.userName ?? 'User',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _authService.userEmail ?? '',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? const Color(0xFFEDE9FE)
                                                : isOwner
                                                    ? Colors.orange.shade50
                                                    : Colors.blueGrey.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isActive
                                                  ? const Color(0xFFA78BFA)
                                                  : isOwner
                                                      ? Colors.orange.shade300
                                                      : Colors.blueGrey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            isActive
                                                ? AppLocalizations.of(context)!.restaurantOwnerLabel
                                                : isOwner
                                                    ? AppLocalizations.of(context)!.ownerInactiveLabel
                                                    : AppLocalizations.of(context)!.freeCustomerLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isActive
                                                  ? const Color(0xFF6D28D9)
                                                  : isOwner
                                                      ? Colors.orange.shade700
                                                      : Colors.blueGrey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),

                                  // ── Owner-only actions (only when subscription active) ──
                                  if (isActive) ...[
                                    PopupMenuItem<String>(
                                      value: 'create_manual',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit, color: Color(0xFF7C3AED)),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)!.createMenuManually),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'upload_pdf',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.upload_file, color: Color(0xFF7C3AED)),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)!.createMenuWithAI),
                                        ],
                                      ),
                                    ),
                                    if (count > 0)
                                      PopupMenuItem<String>(
                                        value: 'edit_restaurant',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.store, color: Color(0xFF7C3AED)),
                                            const SizedBox(width: 8),
                                            Text(count == 1
                                                ? AppLocalizations.of(context)!.editRestaurant
                                                : AppLocalizations.of(context)!.editRestaurants(count)),
                                            if (count > 1) ...const [
                                              Spacer(),
                                              Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                            ],
                                          ],
                                        ),
                                      ),
                                    if (count > 0)
                                      PopupMenuItem<String>(
                                        value: 'qr_code',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.qr_code, color: Color(0xFF7C3AED)),
                                            const SizedBox(width: 8),
                                            Text(AppLocalizations.of(context)!.generateQrCode),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuDivider(),
                                  ],

                                  // ── Plan management ──
                                  PopupMenuItem<String>(
                                    value: 'my_favorites',
                                    child: Row(
                                      children: [
                                        Icon(
                                          _favoriteIds.isNotEmpty ? Icons.favorite : Icons.favorite_border,
                                          color: _favoriteIds.isNotEmpty ? Colors.red : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)!.myFavorites),
                                        if (_favoriteIds.isNotEmpty) ...[
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${_favoriteIds.length}',
                                              style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),

                                  // ── Plan management ──
                                  PopupMenuItem<String>(
                                    value: 'my_plan',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isActive
                                              ? Icons.verified
                                              : Icons.workspace_premium_outlined,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isActive
                                              ? AppLocalizations.of(context)!.manageSubscription
                                              : isOwner
                                                  ? AppLocalizations.of(context)!.reactivateSubscription
                                                  : AppLocalizations.of(context)!.upgradeToOwner,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem<String>(
                                    value: 'logout',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.logout),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)!.signOut),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.login),
                              tooltip: AppLocalizations.of(context)!.signIn,
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                                if (result == true && mounted) {
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(AppLocalizations.of(context)!.signedInSuccessfully),
                                    ),
                                  );
                                }
                              },
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

    return Column(
      children: [
        if (showFilters) _buildFilterPanel(),
        Expanded(
          child: restaurants.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noRestaurantsFound))
              : displayRestaurants.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context)!.noRestaurantsMatchFilters))
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 8,
      shadowColor: Colors.deepPurple.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.purple.shade50, const Color(0xFFEDE9FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
                    Builder(builder: (ctx) {
                      final desc = restaurant.localizedDescription(
                          Localizations.localeOf(ctx).languageCode);
                      if (desc == null) return const SizedBox.shrink();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            desc,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      );
                    }),
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
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Image.network(
            restaurant.imageUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade200, Colors.purple.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.restaurant, size: 64, color: Colors.white),
            ),
          ),
        ),

      ],
    );
  }

  Widget _buildRestaurantHeader(
      Restaurant restaurant, bool hasItems, Cart restaurantCart) {
    final isFav = _favoriteIds.contains(restaurant.id);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            restaurant.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.purple.shade400],
                ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
            ),
          ),
        ),
        if (hasItems) _buildCartBadge(restaurantCart),
        if (restaurant.delivers) _buildDeliveryBadge(),
        IconButton(
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.red : Colors.grey,
          ),
          tooltip: isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
          onPressed: () => _toggleFavorite(restaurant.id),
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.grey),
          tooltip: l10n.shareRestaurant,
          onPressed: () => _shareRestaurant(restaurant),
        ),
      ],
    );
  }

  Widget _buildCartBadge(Cart cart) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.3),
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
            const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        AppLocalizations.of(context)!.deliveryBadge,
        style: const TextStyle(
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
          const Icon(Icons.location_on, size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              restaurant.address,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7C3AED),
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
          const Icon(Icons.phone, size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 4),
          Text(
            restaurant.phone!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7C3AED),
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
          const Icon(Icons.access_time, size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.todayHours(restaurant.getTodayHours()!),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7C3AED),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.purple.shade500],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payment, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                localizePaymentMethod(method, AppLocalizations.of(context)!),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
          if (_authService.isLoggedIn) ...[
            _buildFavoritesFilter(),
            const SizedBox(height: 12),
          ],
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
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l10n.filters,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (selectedCuisineTypes.isNotEmpty ||
            selectedPaymentMethods.isNotEmpty ||
            filterDeliveryOnly != null ||
            filterFavoritesOnly ||
            _filterByLocation)
          TextButton(
            onPressed: () {
              setState(() {
                selectedCuisineTypes.clear();
                selectedPaymentMethods.clear();
                filterDeliveryOnly = null;
                filterFavoritesOnly = false;
                _filterByLocation = false;
                _addressController.clear();
                userLatitude = null;
                userLongitude = null;
              });
            },
            child: Text(l10n.clearAll),
          ),
      ],
    );
  }

  Widget _buildLocationFilter() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.filterByLocation,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                        hintText: l10n.enterAddressOrCoordinates,
                        prefixIcon:
                            const Icon(Icons.location_on, color: Color(0xFF7C3AED)),
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
                          const Icon(Icons.location_on, color: Color(0xFF7C3AED)),
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
                      SnackBar(content: Text(AppLocalizations.of(context)!.locationFilterApplied)),
                    );
                  },
                  emptyBuilder: (context) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(AppLocalizations.of(context)!.noAddressesFound),
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
                tooltip: AppLocalizations.of(context)!.useCurrentLocation,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l10n.radius),
              Expanded(
                child: Slider(
                  value: radiusKm,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: '${radiusKm.toStringAsFixed(0)} km',
                  activeColor: const Color(0xFF7C3AED),
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
            label: Text(l10n.applyLocationFilter),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
          ),
          if (_filterByLocation) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF7C3AED), size: 16),
                const SizedBox(width: 4),
                Text(l10n.locationFilterActive,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED))),
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
                  child: Text(l10n.remove, style: const TextStyle(fontSize: 12)),
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
      title: Text(AppLocalizations.of(context)!.deliveryOnly),
      value: filterDeliveryOnly ?? false,
      onChanged: (value) {
        setState(() {
          filterDeliveryOnly = value ? true : null;
        });
      },
      activeThumbColor: const Color(0xFF7C3AED),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildFavoritesFilter() {
    return SwitchListTile(
      title: Text(AppLocalizations.of(context)!.favoritesOnly),
      secondary: Icon(
        filterFavoritesOnly ? Icons.favorite : Icons.favorite_border,
        color: filterFavoritesOnly ? Colors.red : Colors.grey,
      ),
      value: filterFavoritesOnly,
      onChanged: (value) {
        setState(() {
          filterFavoritesOnly = value;
        });
      },
      activeThumbColor: Colors.red,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCuisineFilter(Set<String> cuisineTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.cuisineType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              selectedColor: const Color(0xFFDDD6FE),
              checkmarkColor: const Color(0xFF7C3AED),
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
        Text(
          AppLocalizations.of(context)!.paymentMethodsFilter,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              selectedColor: const Color(0xFFDDD6FE),
              checkmarkColor: const Color(0xFF7C3AED),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================================
// Language Option tile for the language picker dialog
// ============================================================

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          if (isSelected)
            const Icon(Icons.check, color: Colors.deepPurple, size: 18),
        ],
      ),
    );
  }
}

// ============================================================
// Cart Comparison Sheet
// ============================================================

class _CompareSheet extends StatefulWidget {
  final List<Restaurant> compareRestaurants;
  final Map<int, Cart> activeCarts;
  final VoidCallback onCartChanged;

  const _CompareSheet({
    required this.compareRestaurants,
    required this.activeCarts,
    required this.onCartChanged,
  });

  @override
  State<_CompareSheet> createState() => _CompareSheetState();
}

class _CompareSheetState extends State<_CompareSheet> {
  Map<int, Cart> _carts = {};
  List<Restaurant> _sorted = [];

  @override
  void initState() {
    super.initState();
    _carts = Map.from(widget.activeCarts);
    _sort();
  }

  void _sort() {
    _sorted = List.from(widget.compareRestaurants);
    // Ascending by total (cheapest first)
    _sorted.sort((a, b) {
      final ta = _carts[a.id]?.total ?? 0;
      final tb = _carts[b.id]?.total ?? 0;
      return ta.compareTo(tb);
    });
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail(BuildContext ctx, Restaurant restaurant, Cart cart) async {
    final l10n = AppLocalizations.of(ctx)!;
    final subject = Uri.encodeComponent(l10n.emailOrderSubject);
    final body = Uri.encodeComponent(
      cart.items.map((item) {
        final variant = item.variantName != null ? ' (${item.variantName})' : '';
        final num = item.itemNumber != null ? '${item.itemNumber}. ' : '';
        return '${item.quantity}x  $num${item.itemName}$variant  –  €${(item.price * item.quantity).toStringAsFixed(2)}';
      }).join('\n') +
          '\n\n${l10n.total} €${cart.total.toStringAsFixed(2)}',
    );
    final uri = Uri.parse('mailto:${restaurant.email}?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade600, Colors.purple.shade400],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.compareTitle,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text(l10n.compareSubtitle,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Vertical list sorted by total desc
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _sorted.length,
                  itemBuilder: (_, index) {
                    final restaurant = _sorted[index];
                    final cart = _carts[restaurant.id]!;
                    final isCheapest = index == 0;
                    return _buildRestaurantCard(context, restaurant, cart, isCheapest);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRestaurantCard(
      BuildContext context, Restaurant restaurant, Cart cart, bool isCheapest) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCheapest
            ? Border.all(color: const Color(0xFF7C3AED), width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: isCheapest
                ? Colors.deepPurple.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: name + total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: isCheapest
                  ? LinearGradient(
                      colors: [Colors.deepPurple.shade400, Colors.purple.shade300])
                  : LinearGradient(
                      colors: [Colors.grey.shade100, Colors.grey.shade50]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCheapest)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Günstigste Auswahl',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      Text(
                        restaurant.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCheapest
                              ? Colors.white
                              : Colors.deepPurple.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.compareItemsCount(cart.itemCount),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isCheapest ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCheapest
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '€${cart.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isCheapest
                          ? Colors.white
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: cart.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}×',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (item.itemNumber != null &&
                                    item.itemNumber!.isNotEmpty)
                                  Text(
                                    '${item.itemNumber}.  ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    item.itemName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (item.variantName != null)
                              Text(
                                item.variantName!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '€${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Contact buttons
          if (restaurant.phone != null || restaurant.email != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  if (restaurant.phone != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchPhone(restaurant.phone!),
                        icon: const Icon(Icons.phone, size: 16),
                        label: Text(l10n.callToOrder,
                            style: const TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (restaurant.phone != null && restaurant.email != null)
                    const SizedBox(width: 8),
                  if (restaurant.email != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _launchEmail(context, restaurant, cart),
                        icon: const Icon(Icons.email_outlined, size: 16),
                        label: Text(l10n.emailToOrder,
                            style: const TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                          side: const BorderSide(color: Color(0xFF7C3AED)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
