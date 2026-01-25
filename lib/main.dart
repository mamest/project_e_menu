import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const MyApp());

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

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final data = await rootBundle.loadString('assets/menu.json');
    final map = json.decode(data) as Map<String, dynamic>;
    final cats = (map['categories'] as List<dynamic>)
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList();
    setState(() {
      categories = cats;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Menu')),
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
