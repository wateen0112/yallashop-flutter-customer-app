part of 'currency_cubit.dart';

abstract class CurrencyState extends Equatable {
  const CurrencyState();

  @override
  List<Object?> get props => [];
}

class CurrencyInitial extends CurrencyState {}

class CurrencyLoading extends CurrencyState {}

class CurrencyLoaded extends CurrencyState {
  final List<Currency> currencies;
  final Currency selectedCurrency;

  const CurrencyLoaded({
    required this.currencies,
    required this.selectedCurrency,
  });

  @override
  List<Object?> get props => [currencies, selectedCurrency];
}

class CurrencyError extends CurrencyState {
  final String message;

  const CurrencyError(this.message);

  @override
  List<Object?> get props => [message];
}
