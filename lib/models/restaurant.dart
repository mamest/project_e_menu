import 'dart:math';

class Restaurant {
  final int id;
  final String name;
  final String address;
  final String? email;
  final String? phone;
  final String? description;
  final String? imageUrl;
  final String? cuisineType;
  final bool delivers;
  final Map<String, dynamic>? openingHours;
  final List<String>? paymentMethods;
  final double? latitude;
  final double? longitude;
  final String? restaurantOwnerUuid;
  final String? menuHtmlUrl;
  final Map<String, dynamic> translations;
  final DateTime? menuUpdatedAt;
  final DateTime? updatedAt;
  final String? googlePlaceId;
  final Map<String, dynamic> googleData;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.email,
    this.phone,
    this.description,
    this.imageUrl,
    this.cuisineType,
    this.delivers = false,
    this.openingHours,
    this.paymentMethods,
    this.latitude,
    this.longitude,
    this.restaurantOwnerUuid,
    this.menuHtmlUrl,
    this.translations = const {},
    this.menuUpdatedAt,
    this.updatedAt,
    this.googlePlaceId,
    this.googleData = const {},
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      cuisineType: json['cuisine_type'] as String?,
      delivers: json['delivers'] as bool? ?? false,
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      paymentMethods: json['payment_methods'] != null
          ? List<String>.from(json['payment_methods'] as List)
          : null,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      restaurantOwnerUuid: json['restaurant_owner_uuid'] as String?,
      menuHtmlUrl: json['menu_html_url'] as String?,
      translations: (json['translations'] as Map?)?.cast<String, dynamic>() ?? {},
      menuUpdatedAt: json['menu_updated_at'] != null
          ? (json['menu_updated_at'] is DateTime
              ? json['menu_updated_at'] as DateTime
              : DateTime.parse(json['menu_updated_at'] as String))
          : null,
      updatedAt: json['updated_at'] != null
          ? (json['updated_at'] is DateTime
              ? json['updated_at'] as DateTime
              : DateTime.parse(json['updated_at'] as String))
          : null,
      googlePlaceId: json['google_place_id'] as String?,
      googleData: (json['google_data'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  /// Returns the localized description for [locale] (e.g. 'en', 'de').
  /// Falls back to the original [description] when no translation is available.
  String? localizedDescription(String locale) {
    if (translations.isEmpty) return description;
    final t = translations[locale] as Map?;
    final localized = t?['description'] as String?;
    if (localized != null && localized.isNotEmpty) return localized;
    return description;
  }

  String? getTodayHours() {
    if (openingHours == null) return null;

    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final today = DateTime.now().weekday - 1; // Monday = 0
    final dayName = days[today];

    final hours = openingHours![dayName];
    return hours is String ? hours : null;
  }

  // Calculate distance in kilometers using Haversine formula
  double? distanceFrom(double? userLat, double? userLon) {
    if (latitude == null ||
        longitude == null ||
        userLat == null ||
        userLon == null) {
      return null;
    }

    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _toRadians(userLat - latitude!);
    final dLon = _toRadians(userLon - longitude!);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(latitude!)) *
            cos(_toRadians(userLat)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}
