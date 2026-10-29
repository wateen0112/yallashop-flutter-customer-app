import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yallashop_core/yallashop_core.dart';

/// A carousel slider widget for displaying advertisement banners.
class CarouselSliderWidget extends StatefulWidget {
  final List<CarouselAd> ads;
  final bool isLoading;
  final double height;
  final void Function(CarouselAd ad)? onAdTap;

  const CarouselSliderWidget({
    super.key,
    required this.ads,
    this.isLoading = false,
    this.height = 180,
    this.onAdTap,
  });

  @override
  State<CarouselSliderWidget> createState() => _CarouselSliderWidgetState();
}

class _CarouselSliderWidgetState extends State<CarouselSliderWidget> {
  int _currentIndex = 0;
  CarouselSliderController? _carouselController;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselSliderController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant CarouselSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ads.length != oldWidget.ads.length) {
      _currentIndex = 0;
      _restartAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _carouselController = null;
    super.dispose();
  }

  void _startAutoPlay() {
    if (widget.ads.isEmpty) return;
    _scheduleNextSlide();
  }

  void _restartAutoPlay() {
    _autoPlayTimer?.cancel();
    _startAutoPlay();
  }

  void _scheduleNextSlide() {
    if (widget.ads.isEmpty || _currentIndex >= widget.ads.length) return;

    final ad = widget.ads[_currentIndex];
    final duration = Duration(milliseconds: ad.durationMs);

    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(duration, () {
      if (!mounted || widget.ads.isEmpty) return;

      final nextIndex = (_currentIndex + 1) % widget.ads.length;
      _carouselController?.animateToPage(nextIndex);
    });
  }

  void _onPageChanged(int index, CarouselPageChangedReason reason) {
    setState(() => _currentIndex = index);
    _scheduleNextSlide();
  }

  Future<void> _handleAdTap(CarouselAd ad) async {
    if (widget.onAdTap != null) {
      widget.onAdTap!(ad);
      return;
    }

    switch (ad.linkType) {
      case 'external':
        final uri = Uri.tryParse(ad.linkTarget);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case 'product':
        if (context.mounted) {
          context.push('/product/${ad.linkTarget}');
        }
        break;
      case 'category':
        if (context.mounted) {
          context.push('/categories/${ad.linkTarget}');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildShimmer();
    }

    if (widget.ads.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CarouselSlider(
          carouselController: _carouselController,
          items: widget.ads.map((ad) => _buildAdItem(ad)).toList(),
          options: CarouselOptions(
            height: widget.height,
            viewportFraction: 0.92,
            enlargeCenterPage: true,
            autoPlay: false,
            onPageChanged: _onPageChanged,
            enableInfiniteScroll: widget.ads.length > 1,
          ),
        ),
        if (widget.ads.length > 1) ...[
          const SizedBox(height: 8),
          _buildDotIndicators(),
        ],
      ],
    );
  }

  Widget _buildAdItem(CarouselAd ad) {
    return GestureDetector(
      onTap: () => _handleAdTap(ad),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          color: CustomerAppColors.surfaceAlt,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                ad.mediaUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildImageLoading();
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildImageError();
                },
              ),
              if (ad.title.isNotEmpty)
                _buildTitleOverlay(ad.title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleOverlay(String title) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Text(
          title,
          style: AppTypography.body14.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.ads.asMap().entries.map((entry) {
        final isActive = entry.key == _currentIndex;
        return Container(
          width: isActive ? 20 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? CustomerAppColors.primary
                : CustomerAppColors.textSecondary.withValues(alpha: 0.3),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
    );
  }

  Widget _buildImageLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.white,
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: CustomerAppColors.surfaceAlt,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: CustomerAppColors.textSecondary,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: widget.height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hide_image_outlined,
              color: CustomerAppColors.textSecondary.withValues(alpha: 0.5),
              size: 48,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'No banners available',
              style: AppTypography.caption12.copyWith(
                color: CustomerAppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
