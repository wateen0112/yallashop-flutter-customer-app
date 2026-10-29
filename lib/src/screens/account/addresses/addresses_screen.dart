import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../../config/api_config.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<Address> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final result = await _apiClient.get<List<dynamic>>('/addresses');
    if (result is Success<List<dynamic>>) {
      setState(() {
        _addresses = result.data
            .map((e) => Address.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(int id) async {
    final loc = AppLocalization.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.getText('deleteAddress')),
        content: Text(loc.getText('deleteAddressConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.getText('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: CustomerAppColors.error),
            child: Text(loc.getText('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _apiClient.delete('/addresses/$id');
    if (result is Success) {
      _loadAddresses();
    }
  }

  Future<void> _setDefault(int id) async {
    final result = await _apiClient.patch('/addresses/$id/default');
    if (result is Success) {
      _loadAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: AppBar(
        backgroundColor: CustomerAppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: CustomerAppColors.secondary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          loc.getText('myAddresses'),
          style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600, color: CustomerAppColors.onSurface),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/account/add-address');
          if (result == true) _loadAddresses();
        },
        backgroundColor: CustomerAppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CustomerAppColors.primary))
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off_outlined, size: 64, color: CustomerAppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(loc.getText('noAddressesYet'), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(loc.getText('tapToAddFirstAddress'), style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAddresses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final addr = _addresses[index];
                      return _AddressCard(
                        address: addr,
                        onEdit: () async {
                          final result = await context.push<bool>('/account/edit-address/${addr.id}');
                          if (result == true) _loadAddresses();
                        },
                        onDelete: () => _deleteAddress(addr.id),
                        onSetDefault: () => _setDefault(addr.id),
                      );
                    },
                  ),
                ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: address.isDefault ? CustomerAppColors.primary : CustomerAppColors.border,
          width: address.isDefault ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: address.isDefault
                      ? CustomerAppColors.primary.withValues(alpha: 0.1)
                      : CustomerAppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  address.label ?? loc.getText('address'),
                  style: AppTypography.body14.copyWith(
                    fontWeight: FontWeight.w600,
                    color: address.isDefault ? CustomerAppColors.primary : CustomerAppColors.onSurface,
                  ),
                ),
              ),
              if (address.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CustomerAppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(loc.getText('default'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'default') onSetDefault();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(loc.getText('edit'))),
                  if (!address.isDefault)
                    PopupMenuItem(value: 'default', child: Text(loc.getText('setAsDefault'))),
                  PopupMenuItem(value: 'delete', child: Text(loc.getText('delete'), style: const TextStyle(color: CustomerAppColors.error))),
                ],
                icon: const Icon(Icons.more_vert, size: 20, color: CustomerAppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: CustomerAppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${address.area}, ${address.city}',
                  style: AppTypography.body14.copyWith(color: CustomerAppColors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              address.governorate,
              style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              address.fullAddress,
              style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
