import 'package:flutter/material.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../services/location_service.dart';

/// A widget that provides cascading dropdowns for selecting location:
/// Governorate → City → Area (village)
class LocationSelector extends StatefulWidget {
  /// Callback when a complete location is selected.
  final Function(String governorateId, String cityId, String areaId)?
      onLocationSelected;

  /// Callback when location names are selected (for display purposes).
  final Function(String governorateName, String cityName, String areaName)?
      onLocationNamesSelected;

  /// Whether to show the area/village field.
  final bool showArea;

  /// Initial values for the selectors.
  final String? initialGovernorate;
  final String? initialCity;
  final String? initialArea;

  const LocationSelector({
    super.key,
    this.onLocationSelected,
    this.onLocationNamesSelected,
    this.showArea = true,
    this.initialGovernorate,
    this.initialCity,
    this.initialArea,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  final LocationService _locationService = LocationService();

  List<LocationItem> _governorates = [];
  List<LocationItem> _cities = [];
  List<LocationItem> _areas = [];

  String? _selectedGovernorateId;
  String? _selectedCityId;
  String? _selectedAreaId;

  String? _selectedGovernorateName;
  String? _selectedCityName;
  String? _selectedAreaName;

  bool _isLoadingGovernorates = true;
  bool _isLoadingCities = false;
  bool _isLoadingAreas = false;

  @override
  void initState() {
    super.initState();
    _loadGovernorates();
  }

  Future<void> _loadGovernorates() async {
    setState(() => _isLoadingGovernorates = true);
    final result = await _locationService.getGovernorates();
    if (result is Success<List<LocationItem>>) {
      setState(() {
        _governorates = result.data;
        _isLoadingGovernorates = false;
      });

      // If initial values are provided, select them
      if (widget.initialGovernorate != null) {
        _selectGovernorateByName(widget.initialGovernorate!);
      }
    } else {
      setState(() => _isLoadingGovernorates = false);
    }
  }

  Future<void> _loadCities(String governorateId) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCityId = null;
      _areas = [];
      _selectedAreaId = null;
    });

    final result = await _locationService.getCities(governorateId);
    if (result is Success<List<LocationItem>>) {
      setState(() {
        _cities = result.data;
        _isLoadingCities = false;
      });

      if (widget.initialCity != null && widget.initialGovernorate != null) {
        _selectCityByName(widget.initialCity!);
      }
    } else {
      setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _loadAreas(String governorateId, String cityId) async {
    setState(() {
      _isLoadingAreas = true;
      _areas = [];
      _selectedAreaId = null;
    });

    final result = await _locationService.getAreas(governorateId, cityId);
    if (result is Success<List<LocationItem>>) {
      setState(() {
        _areas = result.data;
        _isLoadingAreas = false;
      });

      if (widget.initialArea != null &&
          widget.initialGovernorate != null &&
          widget.initialCity != null) {
        _selectAreaByName(widget.initialArea!);
      }
    } else {
      setState(() => _isLoadingAreas = false);
    }
  }

  void _selectGovernorateByName(String name) {
    final governorate = _governorates.firstWhere(
      (g) => g.name.toLowerCase() == name.toLowerCase(),
      orElse: () => _governorates.first,
    );
    _onGovernorateSelected(governorate.id);
  }

  void _selectCityByName(String name) {
    final city = _cities.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => _cities.first,
    );
    _onCitySelected(city.id);
  }

  void _selectAreaByName(String name) {
    final area = _areas.firstWhere(
      (a) => a.name.toLowerCase() == name.toLowerCase(),
      orElse: () => _areas.first,
    );
    _onAreaSelected(area.id);
  }

  void _onGovernorateSelected(String? id) {
    if (id == null) return;

    final governorate = _governorates.firstWhere((g) => g.id == id);
    setState(() {
      _selectedGovernorateId = id;
      _selectedGovernorateName = governorate.name;
      _selectedCityId = null;
      _selectedCityName = null;
      _selectedAreaId = null;
      _selectedAreaName = null;
      _cities = [];
      _areas = [];
    });

    _loadCities(id);
    _notifySelection();
  }

  void _onCitySelected(String? id) {
    if (id == null || _selectedGovernorateId == null) return;

    final city = _cities.firstWhere((c) => c.id == id);
    setState(() {
      _selectedCityId = id;
      _selectedCityName = city.name;
      _selectedAreaId = null;
      _selectedAreaName = null;
      _areas = [];
    });

    if (widget.showArea) {
      _loadAreas(_selectedGovernorateId!, id);
    } else {
      _notifySelection();
    }
  }

  void _onAreaSelected(String? id) {
    if (id == null) return;

    final area = _areas.firstWhere((a) => a.id == id);
    setState(() {
      _selectedAreaId = id;
      _selectedAreaName = area.name;
    });

    _notifySelection();
  }

  void _notifySelection() {
    if (_selectedGovernorateId != null &&
        _selectedCityId != null &&
        (!widget.showArea || _selectedAreaId != null)) {
      widget.onLocationSelected?.call(
        _selectedGovernorateId!,
        _selectedCityId!,
        _selectedAreaId ?? '',
      );
      widget.onLocationNamesSelected?.call(
        _selectedGovernorateName ?? '',
        _selectedCityName ?? '',
        _selectedAreaName ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Governorate Dropdown
        _buildDropdown(
          label: loc?.getText('governorate') ?? 'Governorate',
          value: _selectedGovernorateId,
          items: _governorates,
          isLoading: _isLoadingGovernorates,
          enabled: true,
          onChanged: _onGovernorateSelected,
          hint: loc?.getText('selectGovernorate') ?? 'Select Governorate',
        ),
        const SizedBox(height: 16),

        // City Dropdown
        _buildDropdown(
          label: loc?.getText('city') ?? 'City',
          value: _selectedCityId,
          items: _cities,
          isLoading: _isLoadingCities,
          enabled: _selectedGovernorateId != null && _cities.isNotEmpty,
          onChanged: _onCitySelected,
          hint: loc?.getText('selectCity') ?? 'Select City',
        ),
        const SizedBox(height: 16),

        // Area Dropdown (optional)
        if (widget.showArea)
          _buildDropdown(
            label: loc?.getText('area') ?? 'Area/Village',
            value: _selectedAreaId,
            items: _areas,
            isLoading: _isLoadingAreas,
            enabled: _selectedCityId != null && _areas.isNotEmpty,
            onChanged: _onAreaSelected,
            hint: loc?.getText('selectArea') ?? 'Select Area',
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<LocationItem> items,
    required bool isLoading,
    required bool enabled,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body14.copyWith(
            fontWeight: FontWeight.w600,
            color: CustomerAppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : CustomerAppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? CustomerAppColors.border
                  : CustomerAppColors.border.withOpacity(0.5),
            ),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CustomerAppColors.primary,
                      ),
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        hint,
                        style: AppTypography.body14.copyWith(
                          color: CustomerAppColors.textSecondary,
                        ),
                      ),
                    ),
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: CustomerAppColors.primary,
                      ),
                    ),
                    items: items.map((item) {
                      return DropdownMenuItem<String>(
                        value: item.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            item.name,
                            style: AppTypography.body14.copyWith(
                              color: CustomerAppColors.onSurface,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
        ),
      ],
    );
  }

  /// Get the current selection as a map.
  Map<String, String?> get selection => {
        'governorateId': _selectedGovernorateId,
        'governorateName': _selectedGovernorateName,
        'cityId': _selectedCityId,
        'cityName': _selectedCityName,
        'areaId': _selectedAreaId,
        'areaName': _selectedAreaName,
      };
}
