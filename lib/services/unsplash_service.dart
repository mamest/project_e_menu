import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UnsplashService {
  static String get _proxyBaseUrl {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    return '$supabaseUrl/functions/v1/unsplash-proxy';
  }

  static Map<String, String> get _headers {
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    return {
      'Authorization': 'Bearer $anonKey',
      'apikey': anonKey,
    };
  }

  static bool get _isConfigured {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    return supabaseUrl.isNotEmpty && anonKey.isNotEmpty;
  }

  /// Fetch a random image URL from Unsplash based on cuisine type.
  /// Routes through the Supabase unsplash-proxy edge function so the
  /// Unsplash API key never reaches the browser.
  static Future<String?> getRestaurantImage(String? cuisineType) async {
    try {
      if (!_isConfigured) {
        print('Supabase not configured, using placeholder');
        return _getPlaceholderImage(cuisineType);
      }

      // Build search query based on cuisine type
      String query = 'food restaurant';
      if (cuisineType != null && cuisineType.isNotEmpty) {
        query = 'food $cuisineType restaurant';
      }

      final url = Uri.parse(_proxyBaseUrl).replace(queryParameters: {
        'action': 'random',
        'query': query,
      });

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['urls']['regular'] as String?;
        if (imageUrl != null) return imageUrl;
      }

      print('Failed to fetch Unsplash image via proxy: ${response.statusCode}');
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
      if (!_isConfigured) return [];

      final url = Uri.parse(_proxyBaseUrl).replace(queryParameters: {
        'action': 'search',
        'query': query,
        'count': '$count',
      });

      final response = await http.get(url, headers: _headers);

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
  static Future<String?> getCategoryImage(String categoryName) async {
    try {
      if (!_isConfigured) return _getCategoryPlaceholder(categoryName);

      final url = Uri.parse(_proxyBaseUrl).replace(queryParameters: {
        'action': 'random',
        'query': 'food $categoryName',
      });

      final response = await http.get(url, headers: _headers);

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

  static String _getPlaceholderImage(String? cuisineType) {
    final seed = cuisineType?.hashCode ?? 'restaurant';
    return 'https://picsum.photos/seed/$seed/800/600';
  }
}
