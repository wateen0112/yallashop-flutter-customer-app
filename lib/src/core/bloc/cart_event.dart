import 'package:equatable/equatable.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

final class LoadCart extends CartEvent {
  const LoadCart();
}

final class AddItem extends CartEvent {
  final int variantId;
  final int quantity;

  const AddItem({required this.variantId, required this.quantity});

  @override
  List<Object?> get props => [variantId, quantity];
}

final class RemoveItem extends CartEvent {
  final int itemId;

  const RemoveItem({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

final class UpdateQuantity extends CartEvent {
  final int itemId;
  final int quantity;

  const UpdateQuantity({required this.itemId, required this.quantity});

  @override
  List<Object?> get props => [itemId, quantity];
}

final class ClearCart extends CartEvent {
  const ClearCart();
}
