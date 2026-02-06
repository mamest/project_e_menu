import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  /// Geocode an address to get latitude and longitude using Nominatim (OpenStreetMap)
  /// Returns a map with 'latitude' and 'longitude' keys, or null if geocoding fails
  static Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      // Use Nominatim (OpenStreetMap) geocoding service (free, no API key required)
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'EMenuApp/1.0', // Nominatim requires a user agent
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          final result = results[0];
          return {
            'latitude': double.parse(result['lat'] as String),
            'longitude': double.parse(result['lon'] as String),
          };
        }
      }

      print('Geocoding failed for address: $address');
      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }
}
