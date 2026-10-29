import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../../config/api_config.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  bool _isLoading = true;
  Map<String, dynamic>? _earnings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiClient.get<Map<String, dynamic>>('/courier/earnings');
      if (!mounted) return;

      if (result is Success<Map<String, dynamic>>) {
        setState(() => _earnings = result.data);
      } else if (result is Failure) {
        final msg = (result as Failure).exception.message;
        developer.log('Earnings error: $msg', name: 'DriverEarnings');
        setState(() => _error = msg);
      }
    } catch (e, stack) {
      developer.log('Error loading earnings: $e', name: 'DriverEarnings', error: e, stackTrace: stack);
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.getText('earnings'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.getText('earnings'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEarnings,
                child: Text(loc.getText('retry')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.getText('earnings'))),
      body: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CustomerAppColors.primary,
                    CustomerAppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    loc.getText('totalEarnings'),
                    style: AppTypography.body14.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    '\$${(_earnings?['total_earnings'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Row(
              children: [
                Expanded(
                  child: _EarningStatCard(
                    title: loc.getText('completedDeliveries'),
                    value: '${_earnings?['completed_deliveries'] ?? 0}',
                    icon: Icons.check_circle,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _EarningStatCard(
                    title: loc.getText('cashInHand'),
                    value: '\$${(_earnings?['wallet_balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _EarningStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: CustomerAppColors.primary, size: 28),
          const SizedBox(height: AppDimensions.sm),
          Text(
            value,
            style: AppTypography.h2_18.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            title,
            style: AppTypography.caption12.copyWith(
              color: CustomerAppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}