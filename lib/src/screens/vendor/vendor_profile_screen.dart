import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';

class VendorProfileScreen extends StatefulWidget {
  final String storeId;

  const VendorProfileScreen({super.key, required this.storeId});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  Map<String, dynamic>? _storeData;
  Store? _store;
  List<Product> _products = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        '/catalog/stores/${widget.storeId}',
      );
      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final store = Store.fromJson(data);
        final products = (data['products'] as List<dynamic>?)
                ?.map((p) => Product.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [];
        setState(() {
          _storeData = data;
          _store = store;
          _products = products;
          _isLoading = false;
        });
        _loadReviews();
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

  Future<void> _loadReviews() async {
    try {
      final result = await _apiClient.get<dynamic>('/reviews/store/${widget.storeId}');
      if (result is Success<dynamic>) {
        final data = result.data;
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          list = data['data'] as List;
        }
        if (mounted) {
          setState(() {
            _reviews = list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        }
      }
    } catch (_) {
      // Reviews are optional; ignore failures.
    }
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
    if (_error != null || _store == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.getText('storeNotFound')),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadStore, child: Text(loc.getText('retry'))),
            ],
          ),
        ),
      );
    }

    final store = _store!;
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
                  // Banner Image
                  Container(
                    width: double.infinity,
                    height: screenHeight * 0.32 + topPadding,
                    color: const Color(0xFFF5F3F3),
                    child: store.coverPhoto != null || store.banner != null
                        ? Image.network(
                            store.coverPhoto ?? store.banner!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => _buildBannerPlaceholder(),
                          )
                        : _buildBannerPlaceholder(),
                  ),

                  // Details Card
                  Column(
                    children: [
                      SizedBox(height: screenHeight * 0.27 + topPadding),
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
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Store Name & City
                            Text(
                              store.name,
                              style: AppTypography.h1_22.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 16, color: CustomerAppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  store.city ?? '',
                                  style: AppTypography.body14.copyWith(color: CustomerAppColors.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Rating
                            Row(
                              children: [
                                ...List.generate(5, (i) => Icon(
                                    Icons.star,
                                    size: 18,
                                    color: i < store.ratingAvg.floor()
                                        ? const Color(0xFFF2B705)
                                        : CustomerAppColors.border,
                                  )),
                                const SizedBox(width: 6),
                                Text(
                                  store.ratingAvg.toStringAsFixed(1),
                                  style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Description
                            if (store.description != null && store.description!.isNotEmpty) ...[
                              Text(
                                loc.getText('about'),
                                style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                store.description!,
                                style: AppTypography.body14.copyWith(
                                  color: CustomerAppColors.secondary,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Working Hours
                            if (_storeData?['working_hours'] != null &&
                                (_storeData!['working_hours'] as List).isNotEmpty) ...[
                              Text(
                                loc.getText('workingHours'),
                                style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              ...(_storeData!['working_hours'] as List).map((wh) {
                                final day = wh['day'] ?? '';
                                final openTime = wh['open_time'] ?? '';
                                final closeTime = wh['close_time'] ?? '';
                                final isClosed = wh['is_closed'] == true;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        day[0].toUpperCase() + day.substring(1),
                                        style: AppTypography.body14.copyWith(fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        isClosed ? loc.getText('closed') : '$openTime - $closeTime',
                                        style: AppTypography.body14.copyWith(
                                          color: isClosed ? Colors.red : CustomerAppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 24),
                            ],

                            // Products Section
                            if (_products.isNotEmpty) ...[
                              Text(
                                loc.getText('productsCount', params: {'count': '${_products.length}'}),
                                style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.7,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _products.length,
                                itemBuilder: (context, index) {
                                  return _buildProductCard(_products[index]);
                                },
                              ),
                            ],

                            // Reviews Section
                            const SizedBox(height: 24),
                            Text(loc.getText('customerReviews'), style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            if (store.ratingAvg > 0)
                              Row(
                                children: [
                                  ...List.generate(5, (i) => Icon(Icons.star, size: 20, color: i < store.ratingAvg.floor() ? const Color(0xFFF2B705) : CustomerAppColors.border)),
                                  const SizedBox(width: 8),
                                  Text(store.ratingAvg.toStringAsFixed(1), style: AppTypography.body14),
                                  Text(loc.getText('reviewsCount', params: {'count': '${_reviews.length}'}), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),
                                ],
                              ),
                            if (store.ratingAvg == 0 && _reviews.isEmpty)
                              Text(loc.getText('noReviewsYet'), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),
                            if (_reviews.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ..._reviews.map((r) => _buildReviewTile(r, loc)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Logo (overlapping banner and card)
                  Positioned(
                    top: screenHeight * 0.27 + topPadding - 30,
                    left: 20,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: store.logo != null ? NetworkImage(store.logo!) : null,
                        child: store.logo == null
                            ? Icon(Icons.store, color: CustomerAppColors.primary, size: 28)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top AppBar Overlay
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
                    _buildCircleButton(Icons.share, () {}),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPlaceholder() {
    return Container(
      color: const Color(0xFFF5F3F3),
      child: Center(
        child: Icon(Icons.store, size: 60, color: CustomerAppColors.primary.withOpacity(0.3)),
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

  int _numStar(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _formatDate(dynamic value) {
    final d = DateTime.tryParse('$value');
    if (d == null) return '$value';
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  Widget _buildReviewTile(Map<String, dynamic> review, AppLocalization loc) {
    final rating = _numStar(review['rating']);
    final comment = review['comment'] as String?;
    final userMap = review['user'] as Map<String, dynamic>?;
    final userName = (userMap?['name'] as String?)?.trim() ?? loc.getText('customer');
    final avatar = userMap?['avatar'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CustomerAppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CustomerAppColors.border.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: CustomerAppColors.secondary.withOpacity(0.15),
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? const Icon(Icons.person, size: 20, color: CustomerAppColors.secondary)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600)),
                      Text(_formatDate(review['created_at']), style: AppTypography.body12.copyWith(color: CustomerAppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) => Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(Icons.star, size: 16, color: i < rating ? const Color(0xFFF2B705) : CustomerAppColors.border),
              )),
            ),
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment, style: AppTypography.body14.copyWith(color: CustomerAppColors.secondary, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CustomerAppColors.border.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _ProductImagePlaceholder(),
                        errorWidget: (_, __, ___) => const _ProductImagePlaceholder(),
                      )
                    else
                      const _ProductImagePlaceholder(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.currencySymbol}${product.basePrice.toStringAsFixed(2)}',
                    style: AppTypography.body14.copyWith(
                      fontWeight: FontWeight.bold,
                      color: CustomerAppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CustomerAppColors.surfaceAlt,
      child: const Center(
        child: Icon(Icons.image, size: 30, color: CustomerAppColors.textSecondary),
      ),
    );
  }
}
