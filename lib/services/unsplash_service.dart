import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UnsplashService {
  /// Fetch a random image URL from Unsplash based on cuisine type
  /// Returns the image URL or null if fetching fails
  static Future<String?> getRestaurantImage(String? cuisineType) async {
    try {
      final unsplashApiKey = dotenv.env['UNSPLASH_ACCESS_KEY'];
      
      // If no API key, return a placeholder
      if (unsplashApiKey == null || unsplashApiKey.isEmpty) {
        print('No Unsplash API key found, using placeholder');
        return _getPlaceholderImage(cuisineType);
      }

      // Build search query based on cuisine type
      String query = 'restaurant food';
      if (cuisineType != null && cuisineType.isNotEmpty) {
        query = '$cuisineType food restaurant';
      }

      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
          'https://api.unsplash.com/photos/random?query=$encodedQuery&orientation=landscape');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Client-ID $unsplashApiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Get the regular size image URL
        final imageUrl = data['urls']['regular'] as String?;
        if (imageUrl != null) {
          return imageUrl;
        }
      }

      print('Failed to fetch Unsplash image: ${response.statusCode}');
      return _getPlaceholderImage(cuisineType);
    } catch (e) {
      print('Error fetching Unsplash image: $e');
      return _getPlaceholderImage(cuisineType);
    }
  }

  /// Returns a placeholder image URL based on cuisine type
  static String _getPlaceholderImage(String? cuisineType) {
    // Use picsum.photos as a fallback (or could use a local asset)
    final seed = cuisineType?.hashCode ?? 'restaurant';
    return 'https://picsum.photos/seed/$seed/800/600';
  }
}
