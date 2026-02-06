import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MenuData {
  final RestaurantData restaurant;
  final List<CategoryData> categories;

  MenuData({
    required this.restaurant,
    required this.categories,
  });

  factory MenuData.fromJson(Map<String, dynamic> json) {
    return MenuData(
      restaurant: RestaurantData.fromJson(json['restaurant']),
      categories: (json['categories'] as List)
          .map((cat) => CategoryData.fromJson(cat))
          .toList(),
    );
  }
}

class RestaurantData {
  final String name;
  final String address;
  final String? phone;
  final String? email;
  final String? description;
  final String? cuisineType;
  final bool delivers;
  final Map<String, dynamic>? openingHours;
  final List<String>? paymentMethods;

  RestaurantData({
    required this.name,
    required this.address,
    this.phone,
    this.email,
    this.description,
    this.cuisineType,
    this.delivers = false,
    this.openingHours,
    this.paymentMethods,
  });

  factory RestaurantData.fromJson(Map<String, dynamic> json) {
    return RestaurantData(
      name: json['name'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      description: json['description'] as String?,
      cuisineType: json['cuisine_type'] as String?,
      delivers: json['delivers'] as bool? ?? false,
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      paymentMethods: json['payment_methods'] != null
          ? List<String>.from(json['payment_methods'])
          : null,
    );
  }
}

class CategoryData {
  final String name;
  final int displayOrder;
  final List<MenuItemData> items;

  CategoryData({
    required this.name,
    required this.displayOrder,
    required this.items,
  });

  factory CategoryData.fromJson(Map<String, dynamic> json) {
    return CategoryData(
      name: json['name'] as String,
      displayOrder: json['display_order'] as int,
      items: (json['items'] as List)
          .map((item) => MenuItemData.fromJson(item))
          .toList(),
    );
  }
}

class MenuItemData {
  final String name;
  final double? price;
  final String? description;
  final bool hasVariants;
  final List<VariantData>? variants;

  MenuItemData({
    required this.name,
    this.price,
    this.description,
    this.hasVariants = false,
    this.variants,
  });

  factory MenuItemData.fromJson(Map<String, dynamic> json) {
    return MenuItemData(
      name: json['name'] as String,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      description: json['description'] as String?,
      hasVariants: json['has_variants'] as bool? ?? false,
      variants: json['variants'] != null
          ? (json['variants'] as List)
              .map((v) => VariantData.fromJson(v))
              .toList()
          : null,
    );
  }
}

class VariantData {
  final String name;
  final double price;
  final int displayOrder;

  VariantData({
    required this.name,
    required this.price,
    this.displayOrder = 0,
  });

  factory VariantData.fromJson(Map<String, dynamic> json) {
    return VariantData(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }
}

class AiMenuParser {
  final String _supabaseUrl;

  AiMenuParser() : _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';

  /// Parse a PDF menu file and extract structured menu data
  Future<MenuData> parseMenuPdf(Uint8List pdfBytes, String fileName) async {
    try {
      final pdfBase64 = base64Encode(pdfBytes);

      // Call Supabase Edge Function (secure proxy to Anthropic API)
      // This avoids CORS issues and keeps API key secure server-side
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/anthropic-proxy'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pdfBase64': pdfBase64,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed: ${response.statusCode} ${response.body}');
      }

      final responseData = jsonDecode(response.body);

      // Extract the JSON response from Claude
      String textContent = '';
      if (responseData['content'] != null) {
        for (final block in responseData['content']) {
          if (block['type'] == 'text') {
            textContent += block['text'] as String;
          }
        }
      }

      // Parse the JSON response
      final jsonData = _extractJsonFromResponse(textContent);
      return MenuData.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to parse menu: $e');
    }
  }

  String _buildMenuExtractionPrompt() {
    return '''
Please analyze this restaurant menu PDF and extract all the information into a structured JSON format.

Extract the following information:
1. Restaurant details (name, address, phone, email, description, cuisine type, whether they deliver)
2. All menu categories (e.g., Appetizers, Main Courses, Desserts, Drinks)
3. All menu items with their names, prices, and descriptions
4. If items have variants/sizes (e.g., Small/Large), list them

Important guidelines:
- All prices should be in numeric format (e.g., 8.50, not "8,50 €")
- If an item has multiple sizes/variants, set has_variants to true and list each variant
- If opening hours are visible, extract them as day-keyed object (e.g., {"monday": "11:00-22:00"})
- Payment methods as an array if visible

Return ONLY valid JSON in this exact format (no markdown, no code blocks, just the JSON):

{
  "restaurant": {
    "name": "Restaurant Name",
    "address": "Full Address with City",
    "phone": "+49 123 456789",
    "email": "contact@restaurant.com",
    "description": "Brief description of the restaurant",
    "cuisine_type": "Italian",
    "delivers": true,
    "opening_hours": {
      "monday": "11:00-22:00",
      "tuesday": "11:00-22:00",
      "wednesday": "Closed",
      "thursday": "11:00-22:00",
      "friday": "11:00-23:00",
      "saturday": "12:00-23:00",
      "sunday": "12:00-22:00"
    },
    "payment_methods": ["Cash", "Credit Card", "Debit Card"]
  },
  "categories": [
    {
      "name": "Appetizers",
      "display_order": 0,
      "items": [
        {
          "name": "Bruschetta",
          "price": 6.50,
          "description": "Toasted bread with tomatoes and basil",
          "has_variants": false
        },
        {
          "name": "Pizza Margherita",
          "description": "Classic tomato and mozzarella pizza",
          "has_variants": true,
          "variants": [
            {"name": "Small (25cm)", "price": 7.50, "display_order": 0},
            {"name": "Medium (30cm)", "price": 9.50, "display_order": 1},
            {"name": "Large (40cm)", "price": 12.50, "display_order": 2}
          ]
        }
      ]
    }
  ]
}

If any information is not available in the PDF, omit that field or use null.
''';
  }

  Map<String, dynamic> _extractJsonFromResponse(String response) {
    // Remove any markdown code blocks if present
    String cleaned = response.trim();
    
    // Remove markdown JSON code blocks
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    
    cleaned = cleaned.trim();

    // Try to find JSON object boundaries
    final startIndex = cleaned.indexOf('{');
    final endIndex = cleaned.lastIndexOf('}');
    
    if (startIndex == -1 || endIndex == -1) {
      throw Exception('No valid JSON found in response');
    }
    
    cleaned = cleaned.substring(startIndex, endIndex + 1);

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse JSON response: $e\n\nResponse was:\n$cleaned');
    }
  }
}
