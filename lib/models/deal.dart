class Deal {
  final int id;
  final int restaurantId;
  final String title;
  final String? description;
  final String discountType; // 'percentage' | 'fixed'
  final double discountValue;
  final String appliesTo; // 'all' | 'category' | 'item'
  final List<int>? dayOfWeek; // null = every day; 1=Mon..7=Sun (ISO)
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool active;
  final List<int> categoryIds;
  final List<int> itemIds;

  const Deal({
    required this.id,
    required this.restaurantId,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.appliesTo,
    this.dayOfWeek,
    this.validFrom,
    this.validUntil,
    required this.active,
    this.categoryIds = const [],
    this.itemIds = const [],
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    final dayRaw = json['day_of_week'] as List?;
    final catRaw = json['deal_categories'] as List?;
    final itemRaw = json['deal_items'] as List?;
    return Deal(
      id: json['id'] as int,
      restaurantId: json['restaurant_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      appliesTo: json['applies_to'] as String,
      dayOfWeek: dayRaw?.map((e) => e as int).toList(),
      validFrom: json['valid_from'] != null
          ? DateTime.parse(json['valid_from'] as String)
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      active: json['active'] as bool? ?? true,
      categoryIds:
          catRaw?.map((e) => e['category_id'] as int).toList() ?? [],
      itemIds: itemRaw?.map((e) => e['item_id'] as int).toList() ?? [],
    );
  }

  bool get isActiveToday {
    if (!active) return false;
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null) {
      final endOfDay = DateTime(
          validUntil!.year, validUntil!.month, validUntil!.day, 23, 59, 59);
      if (now.isAfter(endOfDay)) return false;
    }
    if (dayOfWeek != null &&
        dayOfWeek!.isNotEmpty &&
        !dayOfWeek!.contains(now.weekday)) return false;
    return true;
  }

  bool appliesToItem(int itemId, int categoryId) {
    switch (appliesTo) {
      case 'all':
        return true;
      case 'category':
        return categoryIds.contains(categoryId);
      case 'item':
        return itemIds.contains(itemId);
      default:
        return false;
    }
  }

  double computeDiscountedPrice(double price) {
    if (discountType == 'percentage') {
      return (price * (1 - discountValue / 100) * 100).roundToDouble() / 100;
    } else {
      return ((price - discountValue).clamp(0, double.infinity) * 100)
              .roundToDouble() /
          100;
    }
  }

  String get discountLabel {
    if (discountType == 'percentage') {
      final pct = discountValue == discountValue.truncateToDouble()
          ? discountValue.toInt().toString()
          : discountValue.toStringAsFixed(1);
      return '$pct% off';
    } else {
      return '\u20ac${discountValue.toStringAsFixed(2)} off';
    }
  }
}
