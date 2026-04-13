import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Handles AI-powered translation of menu category and item text.
///
/// Translations are stored as JSONB on the DB rows in the shape:
/// ```json
/// {
///   "_source": {"name": "Margherita", "desc": "Classic pizza"},
///   "en": {"name": "Margherita", "description": "Classic pizza"},
///   "de": {"name": "Margherita", "description": "Klassische Pizza"}
/// }
/// ```
/// The `_source` key records the original text at the time of last translation,
/// so we only re-translate when the owner actually changes the content.
class TranslationService {
  static const List<String> targetLocales = ['en', 'de'];

  late final String _supabaseUrl;
  late final String _supabaseAnonKey;

  TranslationService()
      : _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '',
        _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ──────────────────────────────────────────────────────────────────────────
  // Public helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns an updated translations map for a category.
  /// Skips the API call when the name hasn't changed since the last translation.
  Future<Map<String, dynamic>> translateCategoryIfChanged({
    required String name,
    Map<String, dynamic> existing = const {},
  }) async {
    final source = (existing['_source'] as Map?)?.cast<String, dynamic>();
    if (source != null && source['name'] == name) return existing;

    final results = await _translateBatch([
      {'id': '0', 'name': name},
    ]);
    if (results.isEmpty) return existing;

    return _buildTranslations(
      result: results.first,
      sourceName: name,
      sourceDesc: null,
    );
  }

  /// Returns an updated translations map for a menu item.
  /// Skips the API call when name + description haven't changed.
  Future<Map<String, dynamic>> translateItemIfChanged({
    required String name,
    String? description,
    Map<String, dynamic> existing = const {},
  }) async {
    final source = (existing['_source'] as Map?)?.cast<String, dynamic>();
    if (source != null &&
        source['name'] == name &&
        source['desc'] == description) {
      return existing;
    }

    final item = <String, dynamic>{'id': '0', 'name': name};
    if (description != null && description.isNotEmpty) {
      item['description'] = description;
    }

    final results = await _translateBatch([item]);
    if (results.isEmpty) return existing;

    return _buildTranslations(
      result: results.first,
      sourceName: name,
      sourceDesc: description,
    );
  }

  /// Fires a background translation job for all categories and items of the
  /// given [restaurantId]. Returns immediately — the edge function runs
  /// asynchronously and writes translations back to the database on its own.
  /// Failures are swallowed so the caller is never interrupted.
  Future<void> triggerBackgroundTranslation(int restaurantId) async {
    try {
      await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/translate-menu'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseAnonKey',
          'apikey': _supabaseAnonKey,
        },
        body: jsonEncode({'restaurantId': restaurantId}),
      );
    } catch (_) {
      // Background translation failure must not propagate to the caller
    }
  }

  /// Batch-translates many items (categories + menu items) in a single API
  /// call. Returns a list parallel to [entries], each element being the ready-
  /// to-store translations map (with `_source`).
  ///
  /// [entries] shape: `{'id': unique_string, 'name': ..., 'description'?: ...}`
  Future<List<Map<String, dynamic>>> translateBatch(
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return [];

    final results = await _translateBatch(entries);
    // Build a lookup by id
    final byId = <String, Map<String, dynamic>>{
      for (final r in results) r['id'] as String: r,
    };

    return entries.map((entry) {
      final id = entry['id'] as String;
      final result = byId[id];
      if (result == null) return <String, dynamic>{};
      return _buildTranslations(
        result: result,
        sourceName: entry['name'] as String,
        sourceDesc: entry['description'] as String?,
      );
    }).toList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildTranslations({
    required Map<String, dynamic> result,
    required String sourceName,
    required String? sourceDesc,
  }) {
    return {
      '_source': {
        'name': sourceName,
        if (sourceDesc != null) 'desc': sourceDesc,
      },
      for (final locale in targetLocales)
        if (result[locale] != null) locale: result[locale],
    };
  }

  Future<List<Map<String, dynamic>>> _translateBatch(
    List<Map<String, dynamic>> items,
  ) async {
    final prompt = '''Translate these restaurant menu texts to English (en) and German (de).
Return ONLY a JSON array with exactly one object per input item.
Each output object must have: "id" (same as input), "en", and "de".
Each locale object must have "name" and optionally "description".
If the source text is already in a target language, copy it verbatim for that language.

Input:
${jsonEncode(items)}

Output format example:
[{"id":"0","en":{"name":"...","description":"..."},"de":{"name":"...","description":"..."}}]
''';

    final response = await http.post(
      Uri.parse('$_supabaseUrl/functions/v1/anthropic-proxy'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_supabaseAnonKey',
        'apikey': _supabaseAnonKey,
      },
      body: jsonEncode({'prompt': prompt}),
    );

    if (response.statusCode != 200) {
      throw Exception('Translation API error ${response.statusCode}: ${response.body}');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final textContent = StringBuffer();
    if (responseData['content'] != null) {
      for (final block in responseData['content'] as List) {
        if (block['type'] == 'text') {
          textContent.write(block['text'] as String);
        }
      }
    }

    return _parseJsonArray(textContent.toString());
  }

  List<Map<String, dynamic>> _parseJsonArray(String raw) {
    String cleaned = raw.trim();
    // Strip markdown fences
    cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    cleaned = cleaned.trim();

    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start == -1 || end == -1) {
      throw Exception('No JSON array found in translation response');
    }
    cleaned = cleaned.substring(start, end + 1);

    return (jsonDecode(cleaned) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }
}
