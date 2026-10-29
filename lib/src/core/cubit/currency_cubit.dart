import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yallashop_core/yallashop_core.dart';

part 'currency_state.dart';

class CurrencyCubit extends Cubit<CurrencyState> {
  final ApiClient _apiClient;
  static const String _selectedCurrencyKey = 'selected_currency_id';

  CurrencyCubit({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl),
        super(CurrencyInitial());

  Future<void> loadCurrencies() async {
    emit(CurrencyLoading());
    try {
      final result = await _apiClient.getList<Map<String, dynamic>>(
        '/currencies',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (result is Success<List<Map<String, dynamic>>>) {
        final currencies = result.data
            .map((json) => Currency.fromJson(json))
            .toList();

        final prefs = await SharedPreferences.getInstance();
        final savedCurrencyId = prefs.getInt(_selectedCurrencyKey);

        Currency selectedCurrency;
        if (savedCurrencyId != null) {
          selectedCurrency = currencies.firstWhere(
            (c) => c.id == savedCurrencyId,
            orElse: () => currencies.firstWhere((c) => c.isDefault),
          );
        } else {
          selectedCurrency = currencies.firstWhere((c) => c.isDefault);
        }

        emit(CurrencyLoaded(
          currencies: currencies,
          selectedCurrency: selectedCurrency,
        ));
      } else {
        emit(CurrencyError('Failed to load currencies'));
      }
    } catch (e) {
      emit(CurrencyError(e.toString()));
    }
  }

  Future<void> selectCurrency(Currency currency) async {
    final currentState = state;
    if (currentState is CurrencyLoaded) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_selectedCurrencyKey, currency.id);
      emit(CurrencyLoaded(
        currencies: currentState.currencies,
        selectedCurrency: currency,
      ));
    }
  }

  double getPriceForProduct(Product product, {ProductVariant? variant}) {
    final currentState = state;
    final basePrice = variant?.price ?? product.basePrice;

    if (currentState is! CurrencyLoaded) {
      return basePrice;
    }

    // Get the product's currency (if set) or find the default currency
    final productCurrency = product.currencyId != null
        ? currentState.currencies.firstWhere(
            (c) => c.id == product.currencyId,
            orElse: () => currentState.currencies.firstWhere((c) => c.isDefault),
          )
        : currentState.currencies.firstWhere((c) => c.isDefault);

    // If selected currency is the same as product's currency, no conversion needed
    if (currentState.selectedCurrency.id == productCurrency.id) {
      return basePrice;
    }

    // Convert from product's currency to selected currency
    // price_in_selected = base_price * (exchange_rate_selected / exchange_rate_product)
    final convertedPrice = basePrice *
        (currentState.selectedCurrency.exchangeRate / productCurrency.exchangeRate);

    return convertedPrice;
  }

  String formatPrice(double price) {
    final currentState = state;
    if (currentState is CurrencyLoaded) {
      return '${currentState.selectedCurrency.symbol}${price.toStringAsFixed(2)}';
    }
    return price.toStringAsFixed(2);
  }
}
