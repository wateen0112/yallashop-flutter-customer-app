import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../../config/api_config.dart';
import '../../../widgets/location_selector.dart';

class AddEditAddressScreen extends StatefulWidget {
  final int? addressId;
  const AddEditAddressScreen({super.key, this.addressId});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isDefault = false;
  bool _isLoading = false;
  bool _isSaving = false;

  // Location fields
  String? _governorate;
  String? _city;
  String? _area;

  bool get _isEditing => widget.addressId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadAddress();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onLocationSelected(String gov, String city, String area) {
    setState(() {
      _governorate = gov;
      _city = city;
      _area = area;
    });
  }

  Future<void> _loadAddress() async {
    setState(() => _isLoading = true);
    final result = await _apiClient.get<List<dynamic>>('/addresses');
    if (result is Success<List<dynamic>>) {
      final addrs = result.data
          .map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList();
      final addr = addrs.firstWhere(
        (a) => a.id == widget.addressId,
        orElse: () => addrs.first,
      );
      _labelController.text = addr.label ?? '';
      _governorate = addr.governorate;
      _city = addr.city;
      _area = addr.area;
      _addressController.text = addr.fullAddress;
      _isDefault = addr.isDefault;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    final loc = AppLocalization.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (_governorate == null || _city == null || _area == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.getText('pleaseSelectLocation')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final data = {
      'label': _labelController.text.trim(),
      'governorate': _governorate!,
      'city': _city!,
      'area': _area!,
      'full_address': _addressController.text.trim(),
      'is_default': _isDefault,
    };

    final result = _isEditing
        ? await _apiClient.patch('/addresses/${widget.addressId}', data: data)
        : await _apiClient.post('/addresses', data: data);

    if (result is Success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? loc.getText('addressUpdated') : loc.getText('addressAdded')),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } else {
      final err = result as Failure;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.exception.message), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isSaving = false);
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
          _isEditing ? loc.getText('editAddress') : loc.getText('addAddress'),
          style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600, color: CustomerAppColors.onSurface),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CustomerAppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(loc.getText('addressLabelHint'), _labelController, Icons.label_outline, validator: (v) {
                      if (v == null || v.trim().isEmpty) return loc.getText('labelRequired');
                      return null;
                    }),
                    const SizedBox(height: 16),

                    // Location Selection
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CustomerAppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, color: CustomerAppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                loc.getText('location'),
                                style: AppTypography.body14.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: CustomerAppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LocationSelector(
                            initialGovernorate: _governorate,
                            initialCity: _city,
                            initialArea: _area,
                            onLocationNamesSelected: _onLocationSelected,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildField(loc.getText('fullAddress'), _addressController, Icons.home_outlined,
                      maxLines: 3, validator: (v) {
                      if (v == null || v.trim().isEmpty) return loc.getText('fullAddressRequired');
                      return null;
                    }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _isDefault,
                          onChanged: (v) => setState(() => _isDefault = v ?? false),
                          activeColor: CustomerAppColors.primary,
                        ),
                        Text(loc.getText('setAsDefaultAddress'), style: AppTypography.body14.copyWith(color: CustomerAppColors.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CustomerAppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _isEditing ? loc.getText('updateAddress') : loc.getText('addAddress'),
                                style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon,
      {int maxLines = 1, String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerAppColors.border),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: AppTypography.body14.copyWith(color: CustomerAppColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary),
          prefixIcon: maxLines == 1 ? Icon(icon, color: CustomerAppColors.primary, size: 22) : null,
          prefixIconConstraints: maxLines == 1 ? null : const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: maxLines == 1 ? 16 : 16,
            vertical: maxLines == 1 ? 16 : 14,
          ),
        ),
      ),
    );
  }
}
