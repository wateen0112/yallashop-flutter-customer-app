import 'package:equatable/equatable.dart';
import 'package:yallashop_core/yallashop_core.dart';

class CartState extends Equatable {
  final List<CartItem> items;
  final bool isLoading;
  final Map<int, String> storeNames;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.storeNames = const {},
  });

  double get subtotal =>
      items.fold(0, (sum, item) => sum + (item.variant.price ?? 0) * item.quantity);

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  Map<int, List<CartItem>> get groupedByStore {
    final map = <int, List<CartItem>>{};
    for (final item in items) {
      final storeId = item.variant.product?.storeId ?? 0;
      map.putIfAbsent(storeId, () => []).add(item);
    }
    return map;
  }

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    Map<int, String>? storeNames,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      storeNames: storeNames ?? this.storeNames,
    );
  }

  @override
  List<Object?> get props => [items, isLoading, storeNames];
}
