// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/restaurant.dart';
import '../models/menu_item.dart';

class HtmlMenuService {
  static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get _anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Calls the menu-html edge function which uses Claude to generate a
  /// beautifully styled HTML menu, then opens it in a new browser tab so
  /// the user can print / save as PDF.
  static Future<void> generateAndOpenHtmlMenu(
    Restaurant restaurant,
    List<Category> categories,
  ) async {
    final url = Uri.parse('$_supabaseUrl/functions/v1/menu-html');

    final payload = {
      'restaurant': {
        'name': restaurant.name,
        'address': restaurant.address,
        if (restaurant.phone != null) 'phone': restaurant.phone,
        if (restaurant.email != null) 'email': restaurant.email,
        if (restaurant.description != null)
          'description': restaurant.description,
        if (restaurant.cuisineType != null)
          'cuisine_type': restaurant.cuisineType,
        'delivers': restaurant.delivers,
        if (restaurant.openingHours != null)
          'opening_hours': restaurant.openingHours,
        if (restaurant.paymentMethods != null)
          'payment_methods': restaurant.paymentMethods,
        if (restaurant.imageUrl != null) 'image_url': restaurant.imageUrl,
      },
      'categories': categories
          .map((cat) => {
                'name': cat.name,
                'items': cat.items
                    .where((item) => item.available)
                    .map((item) => {
                          'name': item.name,
                          if (item.itemNumber != null)
                            'item_number': item.itemNumber,
                          if (item.price != null) 'price': item.price,
                          if (item.description != null)
                            'description': item.description,
                          'has_variants': item.hasVariants,
                          if (item.variants.isNotEmpty)
                            'variants': item.variants
                                .map((v) =>
                                    {'name': v.name, 'price': v.price})
                                .toList(),
                        })
                    .toList(),
              })
          .toList(),
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Edge function returned ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final htmlContent = data['html'] as String?;

    if (htmlContent == null || htmlContent.isEmpty) {
      throw Exception('No HTML returned from edge function');
    }

    // Open as a UTF-8 blob so the browser renders it properly.
    _openHtmlAsBlob(htmlContent);
  }

  /// Fetches HTML from a Supabase Storage URL and opens it as a local blob
  /// so the browser renders it correctly (avoids Content-Type / charset issues).
  static Future<void> openStoredHtml(String storageUrl) async {
    final response = await http.get(Uri.parse(storageUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch stored menu HTML (${response.statusCode})');
    }
    // response.body decodes bytes as latin-1 by default; use bodyBytes + utf8 decode instead.
    final htmlContent = utf8.decode(response.bodyBytes);
    _openHtmlAsBlob(htmlContent);
  }

  /// Creates a UTF-8 HTML blob URL and opens it in a new tab.
  static void _openHtmlAsBlob(String htmlContent) {
    // Encode as UTF-8 bytes so special characters (€, ü, ñ …) survive.
    final bytes = utf8.encode(htmlContent);
    final blob = html.Blob([bytes], 'text/html; charset=utf-8');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(blobUrl, '_blank');
    Future.delayed(const Duration(minutes: 2),
        () => html.Url.revokeObjectUrl(blobUrl));
  }
}
