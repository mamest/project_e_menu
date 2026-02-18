class CartItem {
  final int itemId;
  final String itemName;
  final String? itemNumber;
  final int? variantId;
  final String? variantName;
  final double price;
  int quantity;

  CartItem({
    required this.itemId,
    required this.itemName,
    this.itemNumber,
    this.variantId,
    this.variantName,
    required this.price,
    required this.quantity,
  });

  String get uniqueKey => '${itemId}_${variantId ?? 0}';
}

class Cart {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get total =>
      _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  void addItem(CartItem newItem) {
    final existingIndex =
        _items.indexWhere((item) => item.uniqueKey == newItem.uniqueKey);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
  }

  void removeItem(CartItem item) {
    _items.removeWhere((i) => i.uniqueKey == item.uniqueKey);
  }

  void increaseQuantity(CartItem item) {
    final existingItem =
        _items.firstWhere((i) => i.uniqueKey == item.uniqueKey);
    existingItem.quantity++;
  }

  void decreaseQuantity(CartItem item) {
    final existingItem =
        _items.firstWhere((i) => i.uniqueKey == item.uniqueKey);
    if (existingItem.quantity > 1) {
      existingItem.quantity--;
    } else {
      removeItem(item);
    }
  }

  void clear() {
    _items.clear();
  }
}

// CartManager - Manages carts for multiple restaurants in the session
class CartManager {
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  final Map<int, Cart> _restaurantCarts = {};

  Cart getCartForRestaurant(int restaurantId) {
    if (!_restaurantCarts.containsKey(restaurantId)) {
      _restaurantCarts[restaurantId] = Cart();
    }
    return _restaurantCarts[restaurantId]!;
  }

  void clearAllCarts() {
    _restaurantCarts.clear();
  }

  int getTotalCartsCount() {
    return _restaurantCarts.values
        .where((cart) => cart.items.isNotEmpty)
        .length;
  }
}
