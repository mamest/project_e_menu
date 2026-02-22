class Category {
  final int id;
  final String name;
  final List<MenuItem> items;
  final String? imageUrl;

  Category({required this.id, required this.name, required this.items, this.imageUrl});

  Category copyWith({String? imageUrl}) {
    return Category(id: id, name: name, items: items, imageUrl: imageUrl ?? this.imageUrl);
  }
}

class MenuItem {
  final int id;
  final String name;
  final String? itemNumber;
  final double? price;
  final String? description;
  bool available; // Made mutable for toggling availability
  final bool hasVariants;
  final List<ItemVariant> variants;

  MenuItem({
    required this.id,
    required this.name,
    this.itemNumber,
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
      itemNumber: json['item_number'] as String?,
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
