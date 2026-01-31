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
    );
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
