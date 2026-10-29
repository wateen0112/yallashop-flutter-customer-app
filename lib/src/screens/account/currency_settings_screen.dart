import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../core/cubit/currency_cubit.dart';

class CurrencySettingsScreen extends StatelessWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: AppBar(
        title: const Text('Currency Settings'),
        backgroundColor: CustomerAppColors.background,
        foregroundColor: CustomerAppColors.secondary,
      ),
      body: BlocBuilder<CurrencyCubit, CurrencyState>(
        builder: (context, state) {
          if (state is CurrencyLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CurrencyError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<CurrencyCubit>().loadCurrencies(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is CurrencyLoaded) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.currencies.length,
              itemBuilder: (context, index) {
                final currency = state.currencies[index];
                final isSelected = currency.id == state.selectedCurrency.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? CustomerAppColors.primary.withOpacity(0.1)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? CustomerAppColors.primary
                          : CustomerAppColors.border,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CustomerAppColors.primary
                            : CustomerAppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          currency.symbol,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : CustomerAppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      currency.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: CustomerAppColors.secondary,
                      ),
                    ),
                    subtitle: Text(
                      currency.code,
                      style: AppTypography.caption12.copyWith(
                        color: CustomerAppColors.textSecondary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: CustomerAppColors.primary,
                          )
                        : null,
                    onTap: () {
                      context.read<CurrencyCubit>().selectCurrency(currency);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
