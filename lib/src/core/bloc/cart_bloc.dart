import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yallashop_core/yallashop_core.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final ApiClient _apiClient;

  CartBloc({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const CartState()) {
    on<LoadCart>(_onLoadCart);
    on<AddItem>(_onAddItem);
    on<RemoveItem>(_onRemoveItem);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<ClearCart>(_onClearCart);
  }

  Future<void> _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    emit(state.copyWith(isLoading: true));
    final result = await _apiClient.get<Map<String, dynamic>>(
      '/cart',
    );
    if (result is Success<Map<String, dynamic>>) {
      final cartData = result.data;
      final itemsList = cartData['items'] as List<dynamic>? ?? [];
      final items = itemsList
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(items: items, isLoading: false));
    } else {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onAddItem(AddItem event, Emitter<CartState> emit) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/cart/items',
      data: {'variant_id': event.variantId, 'quantity': event.quantity},
    );
    if (result is Success) {
      add(const LoadCart());
    }
  }

  Future<void> _onRemoveItem(RemoveItem event, Emitter<CartState> emit) async {
    await _apiClient.delete('/cart/items/${event.itemId}');
    add(const LoadCart());
  }

  Future<void> _onUpdateQuantity(UpdateQuantity event, Emitter<CartState> emit) async {
    if (event.quantity <= 0) {
      add(RemoveItem(itemId: event.itemId));
      return;
    }
    await _apiClient.patch(
      '/cart/items/${event.itemId}',
      data: {'quantity': event.quantity},
    );
    add(const LoadCart());
  }

  Future<void> _onClearCart(ClearCart event, Emitter<CartState> emit) async {
    for (final item in state.items) {
      await _apiClient.delete('/cart/items/${item.id}');
    }
    emit(const CartState());
  }
}
