import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/unified_app_bar.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  String _selectedFilter = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    _error = null;

    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        '/vendor/products',
        queryParams: {'page': _currentPage.toString(), 'per_page': '15'},
      );

      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final items = (data['data'] as List<dynamic>?) ?? [];
        final products = items
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        final lastPage = data['last_page'] ?? 1;

        setState(() {
          _products = products;
          _hasMore = _currentPage < lastPage;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = AppLocalization.of(context)?.getText('failedToLoadData') ?? 'Failed to load data';
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

  List<Product> get _filteredProducts {
    switch (_selectedFilter) {
      case 'active':
        return _products.where((p) => p.status == 'active').toList();
      case 'inactive':
        return _products.where((p) => p.status != 'active').toList();
      default:
        return _products;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: UnifiedAppBar.main(
        title: loc.getText('myProducts'),
        showNotification: true,
        showUserAvatar: true,
      ),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError(loc)
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Stats Summary
                      SliverToBoxAdapter(
                        child: _buildStatsSummary(loc),
                      ),
                      // Filter Tabs
                      SliverToBoxAdapter(
                        child: _buildFilterTabs(loc),
                      ),
                      // Products List
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: _buildProductsList(loc),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/my-products/new');
          _loadProducts();
        },
        backgroundColor: CustomerAppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          loc.getText('addProduct'),
          style: AppTypography.body14.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary(AppLocalization loc) {
    final total = _products.length;
    final active = _products.where((p) => p.status == 'active').length;
    final inactive = total - active;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _StatCard(
            label: loc.getText('totalProducts'),
            value: total.toString(),
            icon: Icons.inventory_2_outlined,
            color: CustomerAppColors.primary,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: loc.getText('active'),
            value: active.toString(),
            icon: Icons.check_circle_outline,
            color: CustomerAppColors.success,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: loc.getText('inactive'),
            value: inactive.toString(),
            icon: Icons.pause_circle_outline,
            color: CustomerAppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(AppLocalization loc) {
    final tabs = [
      {'key': 'all', 'label': loc.getText('all')},
      {'key': 'active', 'label': loc.getText('active')},
      {'key': 'inactive', 'label': loc.getText('inactive')},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedFilter == tab['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = tab['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? CustomerAppColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tab['label']!,
                  textAlign: TextAlign.center,
                  style: AppTypography.title18.copyWith(
                    color: isSelected
                        ? CustomerAppColors.primary
                        : CustomerAppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductsList(AppLocalization loc) {
    final products = _filteredProducts;

    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: loc.getText('noProductsYet'),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = products[index];
          return _VendorProductCard(
            product: product,
            onTap: () async {
              await context.push('/my-products/${product.id}/edit');
              _loadProducts();
            },
            onEdit: () async {
              await context.push('/my-products/${product.id}/edit');
              _loadProducts();
            },
            onDelete: () => _confirmDelete(product, loc),
          );
        },
        childCount: products.length,
      ),
    );
  }

  void _confirmDelete(Product product, AppLocalization loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.getText('deleteProduct')),
        content: Text(loc.getText('areYouSure')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.getText('no')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProduct(product.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: CustomerAppColors.error,
            ),
            child: Text(loc.getText('yes')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(int productId) async {
    final result = await _apiClient.delete('/vendor/products/$productId');
    if (result is Success) {
      setState(() {
        _products.removeWhere((p) => p.id == productId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalization.of(context)!.getText('productDeleted')),
            backgroundColor: CustomerAppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildError(AppLocalization loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? loc.getText('errorOccurred')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadProducts,
            child: Text(loc.getText('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats shimmer
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Tabs shimmer
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Product cards shimmer
            for (int i = 0; i < 4; i++)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.h1_22.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption12.copyWith(
                color: CustomerAppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VendorProductCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    final imageUrls = product.imageUrls;
    final firstImage = imageUrls.isNotEmpty ? imageUrls.first : null;
    final isActive = product.status == 'active';
    final variantCount = product.variants?.length ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: CustomerAppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CustomerAppColors.surfaceContainerHigh),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: firstImage != null
                      ? Image.network(
                          firstImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                        )
                      : _buildPlaceholderImage(),
                ),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: AppTypography.body14.copyWith(
                        fontWeight: FontWeight.w600,
                        color: CustomerAppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category?.name ?? '',
                      style: AppTypography.caption12.copyWith(
                        color: CustomerAppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${product.currencySymbol}${product.basePrice.toStringAsFixed(2)}',
                          style: AppTypography.body14.copyWith(
                            fontWeight: FontWeight.w700,
                            color: CustomerAppColors.primary,
                          ),
                        ),
                        if (variantCount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            loc.getText('variantCountLabel', params: {'count': '$variantCount'}),
                            style: AppTypography.caption12.copyWith(
                              color: CustomerAppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Status + Actions
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isActive
                              ? CustomerAppColors.success
                              : CustomerAppColors.warning)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      loc.getText(isActive ? 'active' : 'inactive'),
                      style: AppTypography.caption12.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? CustomerAppColors.success
                            : CustomerAppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      color: CustomerAppColors.textSecondary,
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 18, color: CustomerAppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalization.of(context)!.getText('edit'),
                              style: const TextStyle(color: CustomerAppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, size: 18, color: CustomerAppColors.error),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalization.of(context)!.getText('delete'),
                              style: const TextStyle(color: CustomerAppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: CustomerAppColors.surfaceContainer,
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 28,
          color: CustomerAppColors.primary,
        ),
      ),
    );
  }
}
