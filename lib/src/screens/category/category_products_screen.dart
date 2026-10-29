import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../services/location_service.dart';
import '../../widgets/location_selector.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<Category> _categories = [];
  List<Product> _products = [];
  bool _isLoading = true;
  bool _isLoadingCategories = true;
  String? _error;
  String _sortBy = 'newest';
  late String _selectedCategoryId;

  // Location filters
  final LocationService _locationService = LocationService();
  String? _selectedGovernorate;
  String? _selectedCity;
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
    _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final result = await _apiClient.get<List<dynamic>>(
        '/catalog/categories',
        fromJson: (json) => (json as List<dynamic>).toList(),
      );
      if (result is Success<List<dynamic>>) {
        setState(() {
          _categories = result.data
              .map((e) => Category.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoadingCategories = false;
        });
      } else {
        setState(() => _isLoadingCategories = false);
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final queryParams = <String, String>{
        'category_id': _selectedCategoryId,
        'sort': _sortBy,
        'per_page': '20',
      };

      if (_selectedGovernorate != null) {
        queryParams['governorate'] = _selectedGovernorate!;
      }
      if (_selectedCity != null) {
        queryParams['city'] = _selectedCity!;
      }
      if (_selectedArea != null) {
        queryParams['area'] = _selectedArea!;
      }

      final result = await _apiClient.get<Map<String, dynamic>>(
        '/catalog/products',
        queryParams: queryParams,
      );
      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final list = (data['data'] as List<dynamic>?) ?? [];
        setState(() {
          _products = list
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = (result as Failure).exception.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getCategoryName() {
    if (_categories.isEmpty) return 'Products';
    final cat = _categories.firstWhere(
      (c) => c.id.toString() == _selectedCategoryId,
      orElse: () => _categories.first,
    );
    return cat.name;
  }

  void _showFilterBottomSheet() {
    final loc = AppLocalization.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                loc.getText('filterByLocation'),
                style: AppTypography.h2_18.copyWith(
                  fontWeight: FontWeight.w600,
                  color: CustomerAppColors.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // Location Selector
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: LocationSelector(
                    initialGovernorate: _selectedGovernorate,
                    initialCity: _selectedCity,
                    initialArea: _selectedArea,
                    onLocationNamesSelected: (gov, city, area) {
                      setState(() {
                        _selectedGovernorate = gov;
                        _selectedCity = city;
                        _selectedArea = area;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedGovernorate = null;
                          _selectedCity = null;
                          _selectedArea = null;
                        });
                        Navigator.pop(context);
                        _loadProducts();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: CustomerAppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        loc.getText('clear'),
                        style: AppTypography.body14.copyWith(
                          color: CustomerAppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadProducts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomerAppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        loc.getText('applyFilters'),
                        style: AppTypography.body14.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: AppBar(
        title: Text(_getCategoryName()),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Location Filter Button
          if (_selectedGovernorate != null || _selectedCity != null || _selectedArea != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CustomerAppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: CustomerAppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedArea ?? _selectedCity ?? _selectedGovernorate!,
                    style: TextStyle(
                      fontSize: 12,
                      color: CustomerAppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGovernorate = null;
                        _selectedCity = null;
                        _selectedArea = null;
                      });
                      _loadProducts();
                    },
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: CustomerAppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadProducts();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'newest', child: Text(loc.getText('sortNewest'))),
              PopupMenuItem(value: 'price_low', child: Text(loc.getText('sortPriceLow'))),
              PopupMenuItem(value: 'price_high', child: Text(loc.getText('sortPriceHigh'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories horizontal filter
          if (!_isLoadingCategories && _categories.isNotEmpty)
            Container(
              height: 56,
              color: Colors.white,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat.id.toString() == _selectedCategoryId;
                  return ChoiceChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = cat.id.toString());
                      _loadProducts();
                    },
                    selectedColor: CustomerAppColors.primary.withOpacity(0.15),
                    side: BorderSide(
                      color: isSelected ? CustomerAppColors.primary : CustomerAppColors.border,
                    ),
                    labelStyle: AppTypography.body14.copyWith(
                      color: isSelected ? CustomerAppColors.primary : CustomerAppColors.secondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),

          // Products grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: CustomerAppColors.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProducts,
                              child: Text(loc.getText('retry')),
                            ),
                          ],
                        ),
                      )
                    : _products.isEmpty
                        ? Center(
                            child: Text(
                              loc.getText('noProducts'),
                              style: AppTypography.body14.copyWith(color: CustomerAppColors.secondary),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadProducts,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(AppDimensions.md),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: AppDimensions.sm,
                                mainAxisSpacing: AppDimensions.sm,
                              ),
                              itemCount: _products.length,
                              itemBuilder: (_, index) {
                                final p = _products[index];
                                return ProductCard(
                                  imageUrl: (p.images?.isNotEmpty ?? false)
                                      ? p.images!.first.url
                                      : 'https://via.placeholder.com/200x200',
                                  title: p.title,
                                  price: p.basePrice,
                                  currencySymbol: p.currencySymbol,
                                  rating: p.ratingAvg,
                                  onTap: () => context.push('/product/${p.id}'),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
