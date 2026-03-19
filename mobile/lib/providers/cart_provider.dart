import 'package:flutter/material.dart';
import '../models/models.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;
  int get itemCount => _items.length;
  double get totalAmount => _items.fold(0, (sum, item) => sum + item.total);

  void addItem(Product product, {int quantity = 1}) {
    final idx = _items.indexWhere((item) => item.product.id == product.id);
    if (idx >= 0) {
      _items[idx].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final idx = _items.indexWhere((item) => item.product.id == productId);
    if (idx >= 0) {
      if (quantity <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Map<String, List<CartItem>> get itemsByStore {
    final map = <String, List<CartItem>>{};
    for (final item in _items) {
      final storeId = item.product.storeId ?? 'unknown';
      map.putIfAbsent(storeId, () => []).add(item);
    }
    return map;
  }
}
