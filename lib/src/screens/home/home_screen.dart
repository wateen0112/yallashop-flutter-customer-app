import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_state.dart';
import '../../core/cubit/currency_cubit.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/location_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<Category> _categories = [];
  List<Product> _products = [];
  List<CarouselAd> _carouselAds = [];
  bool _isLoading = true;
  String? _error;
  int _selectedCategoryIndex = 0;
  User? _currentUser;

  // Location filters
  String? _selectedGovernorate;
  String? _selectedCity;
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _error = null;

    try {
      // Get current user from AuthBloc
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        _currentUser = authState.user;
      }

      final results = await Future.wait([
        _apiClient.getCarouselAds(),
        _apiClient.get<List<dynamic>>(
          '/catalog/categories',
          fromJson: (json) => (json as List<dynamic>).toList(),
        ),
        _apiClient.get<Map<String, dynamic>>(
          '/catalog/products',
          queryParams: () {
            final params = <String, String>{'per_page': '20', 'sort': 'newest'};
            if (_selectedGovernorate != null) params['governorate'] = _selectedGovernorate!;
            if (_selectedCity != null) params['city'] = _selectedCity!;
            if (_selectedArea != null) params['area'] = _selectedArea!;
            return params;
          }(),
        ),
      ]);

      final carouselResult = results[0] as Result<List<CarouselAd>>;
      final catResult = results[1] as Result<List<dynamic>>;
      final prodResult = results[2] as Result<Map<String, dynamic>>;

      setState(() {
        if (carouselResult is Success<List<CarouselAd>>) {
          _carouselAds = carouselResult.data;
        }

        if (catResult is Success<List<dynamic>>) {
          _categories = catResult.data
              .map((e) => Category.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        if (prodResult is Success<Map<String, dynamic>>) {
          final prodData = prodResult.data;
          final prods = (prodData['data'] as List<dynamic>?) ?? [];
          _products = prods
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        final hasAnyData = _categories.isNotEmpty || _products.isNotEmpty || _carouselAds.isNotEmpty;
        final allFailed = carouselResult is Failure && catResult is Failure && prodResult is Failure;

        if (allFailed && !hasAnyData) {
          _error = 'failedToLoadData';
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      body: SafeArea(
        child: _isLoading
            ? _buildShimmer()
            : _error != null
                ? _buildError(context)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Header with User Info
                        SliverToBoxAdapter(
                          child: _buildHeader(loc),
                        ),
                        // Main Title
                        SliverToBoxAdapter(
                          child: _buildMainTitle(loc),
                        ),
                        // Carousel Ads
                        if (_carouselAds.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildCarouselAds(),
                          ),
                        // Search Bar
                        SliverToBoxAdapter(
                          child: _buildSearchBar(loc),
                        ),
                        // Real Categories Filter
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildRealCategories(loc),
                          ),
                        ),
                        // Recommended Section Header
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(loc),
                        ),
                        // Product Grid
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: _buildProductGrid(),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildHeader(AppLocalization loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Profile Avatar with User Image
          GestureDetector(
            onTap: () => context.push('/account'),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: CustomerAppColors.border,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: _currentUser != null
                    ? (_currentUser!.avatar != null && _currentUser!.avatar!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _currentUser!.avatar!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildDefaultAvatar(),
                            errorWidget: (_, __, ___) => _buildFallbackAvatar(),
                          )
                        : _buildFallbackAvatar())
                    : _buildDefaultAvatar(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting and Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: AppTypography.caption12.copyWith(
                    color: CustomerAppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _currentUser?.name ?? 'Guest',
                  style: AppTypography.body14.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CustomerAppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          // Location Filter Button
          GestureDetector(
            onTap: _showLocationFilter,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedGovernorate != null
                    ? CustomerAppColors.primary.withOpacity(0.1)
                    : CustomerAppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_outlined,
                size: 20,
                color: _selectedGovernorate != null
                    ? CustomerAppColors.primary
                    : CustomerAppColors.secondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Notification Button
          NotificationBell(
            onTap: () => context.push('/notifications'),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CustomerAppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: CustomerAppColors.secondary,
                ),
                onPressed: () => context.push('/notifications'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: CustomerAppColors.surfaceAlt,
      child: const Icon(
        Icons.person,
        color: CustomerAppColors.textSecondary,
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return CachedNetworkImage(
      imageUrl: 'https://api.dicebear.com/7.x/initials/svg?seed=${Uri.encodeComponent(_currentUser?.name ?? 'U')}',
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildDefaultAvatar(),
      errorWidget: (_, __, ___) => _buildDefaultAvatar(),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildMainTitle(AppLocalization loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        loc.getText('eleganceCrafted'),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: -0.02,
          color: CustomerAppColors.secondary,
        ),
      ),
    );
  }

  Widget _buildCarouselAds() {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: _carouselAds.length,
        itemBuilder: (context, index) {
          final ad = _carouselAds[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: CustomerAppColors.surfaceAlt,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (ad.mediaUrl.isNotEmpty)
                    Image.network(
                      ad.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: CustomerAppColors.surfaceAlt,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: CustomerAppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: CustomerAppColors.surfaceAlt,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: CustomerAppColors.textSecondary),
                      ),
                    ),
                  if (ad.title?.isNotEmpty == true || ad.description?.isNotEmpty == true)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ad.title?.isNotEmpty == true)
                            Text(
                              ad.title!,
                              style: AppTypography.h1_22.copyWith(color: Colors.white),
                            ),
                          if (ad.description?.isNotEmpty == true)
                            Text(
                              ad.description!,
                              style: AppTypography.body14.copyWith(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(AppLocalization loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GestureDetector(
        onTap: () => context.push('/categories'),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: CustomerAppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: CustomerAppColors.border,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(
                Icons.search,
                color: CustomerAppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.getText('searchProduct'),
                  style: AppTypography.body14.copyWith(
                    color: CustomerAppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealCategories(AppLocalization loc) {
    final allCategories = [
      Category(
        id: 0,
        name: loc.getText('all'),
        slug: 'all',
      ),
      ..._categories,
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = index == _selectedCategoryIndex;
          return GestureDetector(
            onTap: () {
              if (category.id == 0) return;
              context.push('/categories/${category.id}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? CustomerAppColors.primary
                    : CustomerAppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? null
                    : Border.all(
                        color: CustomerAppColors.border,
                      ),
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  color: isSelected ? Colors.white : CustomerAppColors.secondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(AppLocalization loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            loc.getText('recommendedForYou'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: CustomerAppColors.secondary,
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/categories'),
            child: Text(
              loc.getText('seeAll'),
              style: AppTypography.caption12.copyWith(
                color: CustomerAppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationFilter() {
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
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                loc.getText('filterByLocation'),
                style: AppTypography.h2_18.copyWith(
                  fontWeight: FontWeight.w600,
                  color: CustomerAppColors.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: LocationSelector(
                    initialGovernorate: _selectedGovernorate,
                    initialCity: _selectedCity,
                    initialArea: _selectedArea,
                    onLocationSelected: (govId, cityId, areaId) {
                      setState(() {
                        _selectedGovernorate = govId;
                        _selectedCity = cityId;
                        _selectedArea = areaId;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                        _loadData();
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
                        style: AppTypography.body14.copyWith(color: CustomerAppColors.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadData();
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

  Widget _buildProductGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = _products[index];
          final isEven = index % 2 == 0;
          return Container(
            margin: EdgeInsets.only(top: isEven ? 0 : 24),
            child: _ProductCard(
              product: product,
              index: index,
              onTap: () => context.push('/product/${product.id}'),
            ),
          );
        },
        childCount: _products.length,
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
            // Header shimmer
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12, width: 80, color: Colors.white),
                      const SizedBox(height: 4),
                      Container(height: 16, width: 120, color: Colors.white),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Main title shimmer
            Container(height: 40, width: 200, color: Colors.white),
            const SizedBox(height: 16),
            // Carousel shimmer
            Container(height: 180, width: double.infinity, color: Colors.white),
            const SizedBox(height: 16),
            // Search bar shimmer
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            const SizedBox(height: 16),
            // Categories shimmer
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) => Container(
                  width: 100,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Section header shimmer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(height: 24, width: 150, color: Colors.white),
                Container(height: 16, width: 50, color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            // Product grid shimmer
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 4,
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(loc.getText('failedToLoadData')),
          const SizedBox(height: 8),
          Text(_error ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: Text(loc.getText('retry'))),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int index;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstImage = product.images?.isNotEmpty == true
        ? product.images!.first.url
        : 'https://via.placeholder.com/600x600';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: CustomerAppColors.surfaceAlt,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: firstImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: CustomerAppColors.surfaceAlt,
                        child: const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: CustomerAppColors.textSecondary,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: CustomerAppColors.surfaceAlt,
                        child: const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: CustomerAppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    // Favorite Button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.favorite_border,
                            size: 18,
                            color: CustomerAppColors.secondary,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Product Info
          Text(
            product.title,
            style: AppTypography.body14.copyWith(
              fontWeight: FontWeight.w600,
              color: CustomerAppColors.secondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${product.store?.name ?? 'Store'}',
            style: AppTypography.caption12.copyWith(
              color: CustomerAppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${product.currencySymbol}${product.basePrice.toStringAsFixed(2)}',
            style: AppTypography.body14.copyWith(
              fontWeight: FontWeight.w700,
              color: CustomerAppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}