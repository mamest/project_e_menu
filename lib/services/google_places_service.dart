import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Data returned by a Google Places text search.
class GooglePlaceCandidate {
  final String placeId;
  final String name;
  final String address;
  final double? rating;
  final int? userRatingCount;

  const GooglePlaceCandidate({
    required this.placeId,
    required this.name,
    required this.address,
    this.rating,
    this.userRatingCount,
  });

  factory GooglePlaceCandidate.fromJson(Map<String, dynamic> json) {
    return GooglePlaceCandidate(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      userRatingCount: json['userRatingCount'] as int?,
    );
  }
}

/// Proxies calls to the Google Places API (New) through the
/// `google-places-proxy` Supabase edge function so the API key stays
/// server-side.
class GooglePlacesService {
  late final String _supabaseUrl;
  late final String _supabaseAnonKey;

  GooglePlacesService()
      : _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '',
        _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  Uri get _proxyUri =>
      Uri.parse('$_supabaseUrl/functions/v1/google-places-proxy');

  Map<String, String> _headers({String? userJwt}) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${userJwt ?? _supabaseAnonKey}',
        'apikey': _supabaseAnonKey,
      };

  /// Searches Google for up to 5 place candidates matching [query].
  Future<List<GooglePlaceCandidate>> searchPlace(String query) async {
    final response = await http.post(
      _proxyUri,
      headers: _headers(),
      body: jsonEncode({'action': 'search', 'query': query}),
    );

    if (response.statusCode != 200) {
      throw Exception('Places search failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['candidates'] as List? ?? [];
    return list
        .map((e) => GooglePlaceCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches full details for [placeId] and writes them into
  /// `restaurants.google_data` for [restaurantId].
  ///
  /// [userJwt] must be the restaurant owner's session JWT so that the
  /// Supabase RLS policy allows the update.
  ///
  /// Returns the cached `google_data` map on success.
  Future<Map<String, dynamic>> fetchAndCache({
    required String placeId,
    required int restaurantId,
    required String userJwt,
  }) async {
    final response = await http.post(
      _proxyUri,
      headers: _headers(userJwt: userJwt),
      body: jsonEncode({
        'action': 'fetch_and_cache',
        'placeId': placeId,
        'restaurantId': restaurantId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Places fetch failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['googleData'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Returns a temporary photo URI for the given [photoName] (e.g.
  /// `places/{id}/photos/{ref}`). The URI expires after a short time and
  /// must not be persisted.
  Future<String?> getPhotoUri(String photoName) async {
    final response = await http.post(
      _proxyUri,
      headers: _headers(),
      body: jsonEncode({'action': 'get_photo_uri', 'photoName': photoName}),
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['photoUri'] as String?;
  }
}
