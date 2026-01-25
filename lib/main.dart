import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl != null && supabaseKey != null && supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Menu',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const MenuPage(),
    );
  }
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Category> categories = [];
  bool loading = true;
  String dataSource = '';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    // Try Supabase first (if configured), otherwise fall back to local asset
    print('Loading menu — checking Supabase config');
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];
    print('SUPABASE_URL present: ${supabaseUrl != null}');
    print('SUPABASE_ANON_KEY present: ${supabaseKey != null}');
    try {
      if (supabaseUrl != null && supabaseKey != null && supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
        final raw = await Supabase.instance.client
            .from('categories')
            .select('id,name,items(id,name,price,description)');
        print('Supabase raw response type: ${raw.runtimeType}');

        // Handle different response shapes from the Supabase client
        if (raw is List) {
          final cats = raw
              .map((c) => Category.fromJson(_mapFromSupabase(c as Map<String, dynamic>)))
              .toList();
          setState(() {
            categories = cats;
            loading = false;
            dataSource = 'Supabase';
          });
          return;
        }

        if (raw is Map<String, dynamic>) {
          // Some SDK versions return a map with 'data' and 'error' fields
          print('Supabase map keys: ${raw.keys.toList()}');
          final dataField = raw['data'] ?? raw['body'] ?? raw['result'];
          if (dataField is List) {
            final cats = dataField
                .map((c) => Category.fromJson(_mapFromSupabase(c as Map<String, dynamic>)))
                .toList();
            setState(() {
              categories = cats;
              loading = false;
              dataSource = 'Supabase';
            });
            return;
          }
          if (raw['error'] != null) {
            print('Supabase error: ${raw['error']}');
          }
        }

        print('Supabase returned unexpected response; falling back');
      } else {
        print('Supabase not configured — skipping Supabase fetch');
      }
    } catch (e, st) {
      print('Supabase fetch failed: $e\n$st');
    }

    // Fallback to bundled JSON asset
    print('Falling back to bundled asset: assets/menu.json');
    final data = await rootBundle.loadString('assets/menu.json');
    final map = json.decode(data) as Map<String, dynamic>;
    final cats = (map['categories'] as List<dynamic>)
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList();
    setState(() {
      categories = cats;
      loading = false;
      dataSource = 'Assets';
    });
  }

  // Supabase returns nested maps/lists; normalize to the same shape as assets/menu.json
  Map<String, dynamic> _mapFromSupabase(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final items = <Map<String, dynamic>>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        if (it is Map<String, dynamic>) items.add(it);
      }
    }
    return {'name': json['name'], 'items': items};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Digital Menu'),
            if (!loading) Text('Source: $dataSource', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, idx) {
                final cat = categories[idx];
                return ExpansionTile(
                  title: Text(cat.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  children: cat.items
                      .map((item) => ListTile(
                            title: Text(item.name),
                            subtitle: Text(item.description ?? ''),
                            trailing: Text('\$${item.price.toStringAsFixed(2)}'),
                          ))
                      .toList(),
                );
              },
            ),
    );
  }
}

class Category {
  final String name;
  final List<MenuItem> items;

  Category({required this.name, required this.items});

  factory Category.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((i) => MenuItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return Category(name: json['name'] as String, items: items);
  }
}

class MenuItem {
  final String name;
  final double price;
  final String? description;

  MenuItem({required this.name, required this.price, this.description});

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
    );
  }
}
