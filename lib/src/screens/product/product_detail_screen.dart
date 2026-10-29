import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';
import 'package:video_player/video_player.dart';

import '../../config/api_config.dart';
import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_state.dart';
import '../../core/bloc/cart_bloc.dart';
import '../../core/bloc/cart_event.dart';
import '../../core/cubit/currency_cubit.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  Product? _product;
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;
  ProductVariant? _selectedVariant;
  int _quantity = 1;
  late TabController _tabController;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  final Map<String, dynamic> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProduct();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        '/catalog/products/${widget.productId}',
      );
      if (result is Success<Map<String, dynamic>>) {
        final p = Product.fromJson(result.data);

        // Log product attributes as JSON response to the console
        try {
          const encoder = JsonEncoder.withIndent('  ');
          debugPrint('================ PRODUCT ATTRIBUTES API RESPONSE JSON ================');
          if (result.data['attributes'] != null) {
            debugPrint('Product Attributes:');
            debugPrint(encoder.convert(result.data['attributes']));
          }
          if (result.data['category']?['attributes'] != null) {
            debugPrint('Category Attributes:');
            debugPrint(encoder.convert(result.data['category']['attributes']));
          }
          if (result.data['variants'] != null) {
            debugPrint('Variants:');
            debugPrint(encoder.convert(result.data['variants']));
          }
          debugPrint('Full Product Data JSON:');
          debugPrint(encoder.convert(result.data));
          debugPrint('======================================================================');
        } catch (e) {
          debugPrint('Error logging product attributes: $e');
        }

        setState(() {
          _product = p;
          // Don't auto-select variant â€” show all images initially
          _selectedVariant = null;
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

  void _onPageChanged(int index, List<ProductMedia> media) {
    setState(() => _currentIndex = index);
    _initializeVideoForIndex(index, media);
  }

  Map<String, List<String>> _getAvailableFilters() {
    final filters = <String, List<String>>{};
    final variants = _product?.variants ?? [];

    for (final variant in variants) {
      if (variant.attributes == null) continue;
      for (final attr in variant.attributes!) {
        final name = attr.attribute?.name ?? 'Unknown';
        final value = attr.option?.value ?? attr.value?.toString() ?? 'Unknown';
        filters.putIfAbsent(name, () => []);
        if (!filters[name]!.contains(value)) {
          filters[name]!.add(value);
        }
      }
    }
    return filters;
  }

  List<ProductVariant> _getFilteredVariants() {
    final variants = _product?.variants ?? [];
    if (_activeFilters.isEmpty) return variants;

    return variants.where((variant) {
      if (variant.attributes == null) return false;
      for (final filter in _activeFilters.entries) {
        final hasMatch = variant.attributes!.any((attr) {
          final name = attr.attribute?.name;
          final value = attr.option?.value ?? attr.value?.toString();
          return name == filter.key && value == filter.value;
        });
        if (!hasMatch) return false;
      }
      return true;
    }).toList();
  }

  void _onFilterChanged(String attributeName, String value) {
    setState(() {
      if (_activeFilters[attributeName] == value) {
        _activeFilters.remove(attributeName);
      } else {
        _activeFilters[attributeName] = value;
      }

      final filtered = _getFilteredVariants();
      if (filtered.isNotEmpty) {
        if (_selectedVariant == null || !filtered.contains(_selectedVariant)) {
          _selectedVariant = filtered.first;
        }
      } else {
        _selectedVariant = null;
      }

      // Reset carousel when variant changes
      _currentIndex = 0;
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
    });
  }

  String _getVariantDescription(ProductVariant variant) {
    if (variant.attributes == null || variant.attributes!.isEmpty) return 'Default';
    return variant.attributes!
        .map((attr) => '${attr.attribute?.name}: ${attr.option?.value ?? attr.value}')
        .join(', ');
  }

  Future<void> _initializeVideoForIndex(int index, List<ProductMedia> media) async {
    if (media.isEmpty || index >= media.length) return;

    final item = media[index];
    if (!item.isVideo) {
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
      return;
    }

    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(item.url));
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      setState(() => _isVideoInitialized = true);
    } catch (e) {
      setState(() => _isVideoInitialized = false);
    }
  }

  bool _isVendor() {
    final authState = context.read<AuthBloc>().state;
    return authState is Authenticated && authState.user.role == 'vendor';
  }

  void _addToCart() {
    final loc = AppLocalization.of(context)!;

    final variants = _getFilteredVariants();
    final variant = _selectedVariant ?? (variants.isNotEmpty ? variants.first : null);
    if (variant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.getText('selectOptions'))),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.getText('loginToAddToCart'))),
      );
      context.push('/login');
      return;
    }

    context.read<CartBloc>().add(AddItem(variantId: variant.id, quantity: _quantity));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.getText('addedToCart')),
        backgroundColor: Colors.green,
      ),
    );
  }

  Color _parseHexColor(String hexColor) {
    try {
      String hex = hexColor.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildVariantSelector(AppLocalization loc) {
    final availableFilters = _getAvailableFilters();
    final filteredVariants = _getFilteredVariants();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.getText('selectOptions'), style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        // Filter Sections
        ...availableFilters.entries.map((entry) {
          final attributeName = entry.key;
          final options = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(attributeName, style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: options.map((option) {
                    final isSelected = _activeFilters[attributeName] == option;
                    final hasActiveFilter = _activeFilters.containsKey(attributeName);
                    final optionOpacity = hasActiveFilter ? (isSelected ? 1.0 : 0.4) : 1.0;
                    if (attributeName.toLowerCase() == 'color') {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _onFilterChanged(attributeName, option),
                          child: Opacity(
                            opacity: optionOpacity,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _parseHexColor(option),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? CustomerAppColors.primary : Colors.grey.withOpacity(0.3),
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Opacity(
                        opacity: optionOpacity,
                        child: ChoiceChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (_) => _onFilterChanged(attributeName, option),
                          selectedColor: CustomerAppColors.primary.withOpacity(0.2),
                          side: BorderSide(
                            color: isSelected ? CustomerAppColors.primary : Colors.grey.withOpacity(0.3),
                          ),
                          labelStyle: AppTypography.body12.copyWith(
                            color: isSelected ? CustomerAppColors.primary : CustomerAppColors.secondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),

        const SizedBox(height: 16),
        Text(loc.getText('availableVariants'), style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        if (filteredVariants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(loc.getText('noVariantsMatch'),
                style: const TextStyle(color: Colors.red, fontSize: 14)),
            ),
          )
        else
          Column(
            children: filteredVariants.map((variant) {
              final isSelected = _selectedVariant?.id == variant.id;
              return _buildVariantTile(variant, isSelected, loc);
            }).toList(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVariantAttributes(ProductVariant variant, AppLocalization loc) {
    if (variant.attributes == null || variant.attributes!.isEmpty) {
      return Text(loc.getText('defaultKey'), style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: variant.attributes!.map((attr) {
        final name = attr.attribute?.name ?? '';
        final value = attr.option?.value ?? attr.value?.toString() ?? '';

        if (name.toLowerCase() == 'color') {
          return Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _parseHexColor(value),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
          );
        }
        return Text(value, style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600));
      }).toList(),
    );
  }

  Widget _buildVariantTile(ProductVariant variant, bool isSelected, AppLocalization loc) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVariant = variant;
          // Reset carousel when variant changes
          _currentIndex = 0;
          _videoController?.dispose();
          _videoController = null;
          _isVideoInitialized = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? CustomerAppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? CustomerAppColors.primary : CustomerAppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: variant.images != null && variant.images!.isNotEmpty
                    ? Image.network(variant.images!.first.url, fit: BoxFit.cover)
                    : Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVariantAttributes(variant, loc),
                  Text(
                    '${loc.getText('sku')}: ${variant.sku}',
                    style: AppTypography.body12.copyWith(color: CustomerAppColors.secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${_product!.currencySymbol}${(variant.price ?? 0).toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: AppTypography.body14.copyWith(fontWeight: FontWeight.bold, color: CustomerAppColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              const Icon(Icons.check_circle, color: CustomerAppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: CustomerAppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: CustomerAppColors.primary)),
      );
    }
    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.getText('productNotFound')),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadProduct, child: Text(loc.getText('retry'))),
            ],
          ),
        ),
      );
    }

    final product = _product!;

    // Build combined media list: product images + all variant images (deduplicated)
    final allMedia = <ProductMedia>[];
    final seenUrls = <String>{};

    // Add product-level images/videos first
    if (product.images != null && product.images!.isNotEmpty) {
      for (final img in product.images!) {
        if (seenUrls.add(img.url)) {
          allMedia.add(img);
        }
      }
    }

    // Add all variant images/videos
    if (product.variants != null) {
      for (final variant in product.variants!) {
        if (variant.images != null) {
          for (final img in variant.images!) {
            if (seenUrls.add(img.url)) {
              allMedia.add(ProductMedia(url: img.url, type: img.type, sortOrder: img.sortOrder));
            }
          }
        }
      }
    }

    // If variant is selected and has images, show only that variant's media
    final hasSelectedVariant = _selectedVariant != null &&
        _selectedVariant!.images != null &&
        _selectedVariant!.images!.isNotEmpty;

    List<ProductMedia> mediaItems;
    if (hasSelectedVariant) {
      mediaItems = _selectedVariant!.images!
          .map((img) => ProductMedia(url: img.url, type: img.type, sortOrder: img.sortOrder))
          .toList();
    } else if (allMedia.isNotEmpty) {
      mediaItems = allMedia;
    } else {
      mediaItems = [ProductMedia(url: 'https://via.placeholder.com/600x600', type: 'image')];
    }
    
    final displayPrice = _selectedVariant?.price ?? product.basePrice;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      body: Stack(
        children: [
          // Scrollable Content
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Stack(
                children: [
                  // 1. Hero Image Section â€” fills from top, image is the background
                  Container(
                    width: double.infinity,
                    height: screenHeight * 0.48 + topPadding,
                    color: const Color(0xFFF5F3F3),
                    child: Stack(
                      children: [
                        ClipRect(
                          child: PageView.builder(
                            itemCount: mediaItems.length,
                            onPageChanged: (i) => _onPageChanged(i, mediaItems),
                            itemBuilder: (_, i) {
                              final item = mediaItems[i];
                              if (item.isVideo) {
                                if (_videoController != null && _isVideoInitialized) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _videoController!.value.size.width,
                                          height: _videoController!.value.size.height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                      // Video play/pause button
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (_videoController!.value.isPlaying) {
                                              _videoController!.pause();
                                            } else {
                                              _videoController!.play();
                                            }
                                          });
                                        },
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _videoController!.value.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.network(item.url, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                    const CircularProgressIndicator(color: Colors.white),
                                  ],
                                );
                              }
                              return Image.network(item.url, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
                            },
                          ),
                        ),
                        // Dots indicator
                        if (mediaItems.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(mediaItems.length, (i) {
                                final isActive = i == _currentIndex;
                                final isVideo = mediaItems[i].isVideo;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: isActive ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: isVideo && isActive
                                      ? const Center(
                                          child: Icon(Icons.videocam, size: 6, color: Colors.black54),
                                        )
                                      : null,
                                );
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 2. Scrollable Details Card (Slides over the image)
                  Column(
                    children: [
                      SizedBox(height: screenHeight * 0.43 + topPadding),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 40,
                              offset: const Offset(0, -20),
                            ),
                          ],
                          border: Border(
                            top: BorderSide(color: CustomerAppColors.border.withOpacity(0.3)),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 200), // 200 bottom padding to clear bottom bar completely and add breathing room
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadge(loc.getText('newRelease'), const Color(0xFFFFDF9D), const Color(0xFF251A00)),
                                _buildBadge(loc.getText('bestSeller'), const Color(0xFFE4E2E2), CustomerAppColors.secondary),
                                _buildBadge(loc.getText('off', params: {'percent': '20'}), const Color(0xFFFFDADA), CustomerAppColors.primary),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Product Header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.title,
                                        style: AppTypography.h1_22.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 28,
                                          letterSpacing: -0.02,
                                        ),
                                      ),
                                      Text(
                                        product.category?.name ?? loc.getText('premiumCollection'),
                                        style: AppTypography.body14.copyWith(color: CustomerAppColors.secondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${product.currencySymbol}${displayPrice.toStringAsFixed(2)}',
                                        style: AppTypography.display28.copyWith(
                                          color: CustomerAppColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (product.basePrice > displayPrice)
                                        Text(
                                          '${product.currencySymbol}${product.basePrice.toStringAsFixed(2)}',
                                          style: AppTypography.body12.copyWith(
                                            color: CustomerAppColors.textSecondary.withOpacity(0.6),
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Rating
                            Row(
                              children: [
                                ...List.generate(5, (i) => Icon(
                                    Icons.star,
                                    size: 18,
                                    color: i < (product.ratingAvg.floor()) 
                                        ? const Color(0xFFF2B705) 
                                        : CustomerAppColors.border,
                                  )),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${product.ratingAvg} ${loc.getText('rating')}',
                                    style: AppTypography.body12.copyWith(color: CustomerAppColors.secondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Store Info Row
                            if (product.store != null)
                              GestureDetector(
                                onTap: () => context.push('/store/${product.storeId}'),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F3F3),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage: product.store!.logo != null
                                            ? NetworkImage(product.store!.logo!)
                                            : null,
                                        child: product.store!.logo == null
                                            ? Icon(Icons.store, color: CustomerAppColors.primary, size: 22)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.store!.name,
                                              style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              product.store!.city ?? '',
                                              style: AppTypography.body12.copyWith(color: CustomerAppColors.secondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: CustomerAppColors.secondary),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),

                            // Variant Selector
                            _buildVariantSelector(loc),
                            
                            // Description
                            Text(
                              loc.getText('aboutProduct'),
                              style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description ?? loc.getText('noDescriptionAvailable'),
                              style: AppTypography.body14.copyWith(
                                color: CustomerAppColors.secondary,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Reviews Section
                            const SizedBox(height: 24),
                            Text(loc.getText('customerReviews'), style: AppTypography.h2_18),
                            const SizedBox(height: 8),
                            if (product.ratingAvg > 0)
                              Row(
                                children: [
                                  ...List.generate(5, (i) => Icon(Icons.star, size: 20, color: i < product.ratingAvg.floor() ? const Color(0xFFF2B705) : CustomerAppColors.border)),
                                  const SizedBox(width: 8),
                                  Text('${product.ratingAvg}', style: AppTypography.body14),
                                ],
                              ),
                            if (product.ratingAvg == 0)
                              Text(loc.getText('noReviewsYet'), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),

                            // Bento Grid
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                _buildBentoCard(Icons.local_shipping, loc.getText('freeShipping'), loc.getText('deliveryInDays')),
                                const SizedBox(width: 16),
                                _buildBentoCard(Icons.verified_user, loc.getText('twoYearWarranty'), loc.getText('fullCoverageIncluded')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Top AppBar Overlay (Fixed) â€” over the image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCircleButton(Icons.arrow_back, () => context.pop()),
                    Row(
                      children: [
                        _buildCircleButton(Icons.favorite_border, () {}),
                        const SizedBox(width: 12),
                        _buildCircleButton(Icons.share, () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Action Bar (Fixed at Bottom, Reduced Height)
          if (!_isVendor()) Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(loc),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTypography.body12.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.05,
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBentoCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: CustomerAppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: AppTypography.body12.copyWith(color: CustomerAppColors.secondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(AppLocalization loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: CustomerAppColors.border.withOpacity(0.2))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Quantity Selector
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFEDED),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () {
                      if (_quantity > 1) setState(() => _quantity--);
                    },
                  ),
                  Text('$_quantity', style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Action Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomerAppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 5,
                    shadowColor: CustomerAppColors.primary.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        loc.getText('addToCart'),
                        style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getApproxColor(String value) {
    final val = value.toLowerCase();
    if (val.contains('black')) return Colors.black;
    if (val.contains('white')) return Colors.white;
    if (val.contains('grey') || val.contains('gray')) return Colors.grey;
    if (val.contains('red')) return Colors.red;
    if (val.contains('blue')) return Colors.blue;
    if (val.contains('green')) return Colors.green;
    if (val.contains('gold') || val.contains('yellow')) return Colors.amber;
    if (val.contains('silver')) return const Color(0xFFC0C0C0);
    return Colors.blueGrey;
  }
}
