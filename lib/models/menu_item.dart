class Category {
  final int id;
  final String name;
  final List<MenuItem> items;

  Category({required this.id, required this.name, required this.items});
}

class MenuItem {
  final int id;
  final String name;
  final double? price;
  final String? description;
  final bool available;
  final bool hasVariants;
  final List<ItemVariant> variants;

  MenuItem({
    required this.id,
    required this.name,
    this.price,
    this.description,
    this.available = true,
    this.hasVariants = false,
    this.variants = const [],
  });

  factory MenuItem.fromJson(
      Map<String, dynamic> json, List<ItemVariant> variants) {
    return MenuItem(
      id: json['id'] as int,
      name: json['name'] as String,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      description: json['description'] as String?,
      available: json['available'] as bool? ?? true,
      hasVariants: json['has_variants'] as bool? ?? false,
      variants: variants,
    );
  }
}

class ItemVariant {
  final int id;
  final String name;
  final double price;
  final int displayOrder;

  ItemVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.displayOrder,
  });

  factory ItemVariant.fromJson(Map<String, dynamic> json) {
    return ItemVariant(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }
}
