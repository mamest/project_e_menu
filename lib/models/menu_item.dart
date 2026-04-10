class Category {
  final int id;
  final String name;
  final List<MenuItem> items;
  final String? imageUrl;
  final Map<String, dynamic> translations;

  Category({
    required this.id,
    required this.name,
    required this.items,
    this.imageUrl,
    this.translations = const {},
  });

  Category copyWith({String? imageUrl, Map<String, dynamic>? translations}) {
    return Category(
      id: id,
      name: name,
      items: items,
      imageUrl: imageUrl ?? this.imageUrl,
      translations: translations ?? this.translations,
    );
  }

  String localizedName(String locale) {
    final t = translations[locale] as Map?;
    return (t?['name'] as String?)?.isNotEmpty == true ? t!['name'] as String : name;
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
  final Map<String, dynamic> translations;

  MenuItem({
    required this.id,
    required this.name,
    this.itemNumber,
    this.price,
    this.description,
    this.available = true,
    this.hasVariants = false,
    this.variants = const [],
    this.translations = const {},
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
      translations: (json['translations'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  String localizedName(String locale) {
    final t = translations[locale] as Map?;
    return (t?['name'] as String?)?.isNotEmpty == true ? t!['name'] as String : name;
  }

  String? localizedDescription(String locale) {
    final t = translations[locale] as Map?;
    final localized = t?['description'] as String?;
    return (localized?.isNotEmpty == true) ? localized : description;
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
