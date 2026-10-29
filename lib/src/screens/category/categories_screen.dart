import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_state.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/unified_app_bar.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await _apiClient.get<List<dynamic>>(
      '/catalog/categories',
      fromJson: (json) => (json as List<dynamic>).toList(),
    );
    if (result is Success<List<dynamic>>) {
      setState(() {
        _categories = result.data
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

@override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: UnifiedAppBar.main(
        title: loc.getText('categories'),
        showNotification: true,
        showUserAvatar: true,
        onAvatarTap: () => context.push('/account'),
      ),
      body: _isLoading
          ? _buildShimmer()
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Horizontal Category Chips
                  SliverToBoxAdapter(
                    child: _buildCategoryChips(loc),
                  ),
                  // Category Grid (Bento style)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: _buildCategoryGrid(),
                  ),
                  // CTA Section
                  SliverToBoxAdapter(
                    child: _buildCtaSection(),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildCategoryChips(AppLocalization loc) {
    final categoryNames = [
      loc.getText('all'),
      loc.getText('fashion'),
      loc.getText('electronics'),
      loc.getText('homeAndLiving'),
      loc.getText('beauty'),
      loc.getText('accessories'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categoryNames.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final isSelected = index == 0; // For now, first is selected
            return GestureDetector(
              onTap: () {
                // Could add filter logic here
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? CustomerAppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: isSelected
                        ? CustomerAppColors.primary
                        : CustomerAppColors.surfaceContainerHighest,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: CustomerAppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  categoryNames[index],
                  style: AppTypography.body12.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                    color: isSelected
                        ? Colors.white
                        : CustomerAppColors.secondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    if (_categories.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              AppLocalization.of(context)!.getText('noCategoriesFound'),
              style: AppTypography.body14.copyWith(
                color: CustomerAppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    // Create bento-style grid with first category as featured
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0 && _categories.length > 0) {
            return _buildFeaturedCategoryCard(_categories.first);
          }
          final catIndex = index > 0 ? index - 1 : 0;
          if (catIndex < _categories.length) {
            return _buildRegularCategoryCard(_categories[catIndex]);
          }
          return _buildPlaceholderCard();
        },
        childCount: _categories.length > 0 ? _categories.length : 0,
      ),
    );
  }

  Widget _buildFeaturedCategoryCard(Category category) {
    final imageUrl = category.image?.isNotEmpty == true
        ? category.image!
        : 'https://images.unsplash.com/photo-1483985988355-763728e19387e8d?w=800';

    return GestureDetector(
      onTap: () => context.push('/category/${category.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: CustomerAppColors.surfaceContainerLow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category.id == 1) // Example: New Season badge for first category
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CustomerAppColors.accentGold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalization.of(context)!.getText('newSeason'),
                          style: AppTypography.caption10.copyWith(
                            fontWeight: FontWeight.w800,
                            color: CustomerAppColors.brandDark,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.01,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalization.of(context)!.getText('exploreStyles'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularCategoryCard(Category category) {
    final imageUrl = category.image?.isNotEmpty == true
        ? category.image!
        : _getPlaceholderImageForCategory(category.name);

    // Category icons mapping
    final categoryIcons = <String, IconData>{
      'electronics': Icons.devices,
      'home': Icons.home_outlined,
      'beauty': Icons.face_outlined,
      'sports': Icons.sports_esports_outlined,
      'fashion': Icons.checkroom_outlined,
    };

    final icon = categoryIcons.entries
        .firstWhere(
          (e) => category.name.toLowerCase().contains(e.key),
          orElse: () => const MapEntry('default', Icons.category_outlined),
        )
        .value;

    return GestureDetector(
      onTap: () => context.push('/category/${category.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: CustomerAppColors.surfaceContainerHigh,
                border: Border.all(
                  color: CustomerAppColors.surfaceContainerHighest,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  ),
                  // Category Icon Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: CustomerAppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              category.name,
              style: AppTypography.title18.copyWith(
                color: CustomerAppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlaceholderImageForCategory(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('electronic')) {
      return 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400';
    } else if (lowerName.contains('home') || lowerName.contains('living')) {
      return 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400';
    } else if (lowerName.contains('beauty')) {
      return 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400';
    } else if (lowerName.contains('sport')) {
      return 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400';
    } else if (lowerName.contains('fashion')) {
      return 'https://images.unsplash.com/photo-1483985988355-763728e18e8d?w=400';
    }
    return 'https://images.unsplash.com/photo-1523293182086-7651a899d37f?w=400';
  }

  Widget _buildPlaceholderCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: CustomerAppColors.surfaceContainerHigh,
        border: Border.all(
          color: CustomerAppColors.surfaceContainerHighest,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.category_outlined, size: 40, color: CustomerAppColors.primary),
          const SizedBox(height: 12),
          Text(
            AppLocalization.of(context)!.getText('categories'),
            style: AppTypography.caption12,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: CustomerAppColors.surfaceContainerHigh,
      child: const Center(
        child: Icon(Icons.category_outlined, size: 40, color: CustomerAppColors.primary),
      ),
    );
  }

  Widget _buildCtaSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CustomerAppColors.brandDark,
              CustomerAppColors.brandDark.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Background accent
            Positioned(
              top: -32,
              right: -32,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CustomerAppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.of(context)!.getText('flashSale'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.01,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalization.of(context)!.getText('upTo70Off'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => context.push('/categories'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomerAppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    elevation: 0,
                    textStyle: AppTypography.body12.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.05,
                    ),
                  ),
                  child: Text(
                    AppLocalization.of(context)!.getText('shopNow'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            // Category chips shimmer
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => Container(
                  width: 100,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Grid shimmer
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // CTA shimmer
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}