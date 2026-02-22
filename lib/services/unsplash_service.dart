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
      // Always start with 'food' to ensure food-related images
      String query = 'food restaurant';
      if (cuisineType != null && cuisineType.isNotEmpty) {
        query = 'food $cuisineType restaurant';
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

  /// Search Unsplash for multiple photos matching a query.
  /// Returns a list of maps with keys: url, thumbUrl, photographer, photographerUrl.
  static Future<List<Map<String, String>>> searchImages(String query, {int count = 12}) async {
    try {
      final unsplashApiKey = dotenv.env['UNSPLASH_ACCESS_KEY'];
      if (unsplashApiKey == null || unsplashApiKey.isEmpty) return [];

      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
          'https://api.unsplash.com/search/photos?query=$encodedQuery&per_page=$count&orientation=landscape');

      final response = await http.get(url, headers: {
        'Authorization': 'Client-ID $unsplashApiKey',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        return results.map<Map<String, String>>((photo) {
          return {
            'url': photo['urls']['regular'] as String? ?? '',
            'thumbUrl': photo['urls']['small'] as String? ?? '',
            'photographer': photo['user']['name'] as String? ?? 'Unknown',
            'photographerUrl': photo['user']['links']['html'] as String? ?? '',
          };
        }).where((p) => p['url']!.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch an image URL for a menu category (e.g. "Starters", "Pizza", "Drinks").
  /// Uses English search terms on Unsplash.
  static Future<String?> getCategoryImage(String categoryName) async {
    try {
      final unsplashApiKey = dotenv.env['UNSPLASH_ACCESS_KEY'];
      if (unsplashApiKey == null || unsplashApiKey.isEmpty) {
        return _getCategoryPlaceholder(categoryName);
      }

      // Always prepend "food" so we get relevant results
      final query = Uri.encodeComponent('food $categoryName');
      final url = Uri.parse(
          'https://api.unsplash.com/photos/random?query=$query&orientation=landscape');

      final response = await http.get(url, headers: {
        'Authorization': 'Client-ID $unsplashApiKey',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['urls']['regular'] as String?;
      }
      return _getCategoryPlaceholder(categoryName);
    } catch (e) {
      return _getCategoryPlaceholder(categoryName);
    }
  }

  static String _getCategoryPlaceholder(String categoryName) {
    final seed = categoryName.toLowerCase().replaceAll(' ', '-');
    return 'https://picsum.photos/seed/food-$seed/600/200';
  }

  /// Returns a placeholder image URL based on cuisine type
  static String _getPlaceholderImage(String? cuisineType) {
    // Use picsum.photos as a fallback (or could use a local asset)
    final seed = cuisineType?.hashCode ?? 'restaurant';
    return 'https://picsum.photos/seed/$seed/800/600';
  }
}
