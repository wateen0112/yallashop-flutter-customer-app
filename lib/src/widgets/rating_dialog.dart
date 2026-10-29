import 'package:flutter/material.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../config/api_config.dart';

class RatingDialog extends StatefulWidget {
  final String type; // 'product' or 'store'
  final int id;
  final String name;
  final String? imageUrl;
  final int orderId;
  final VoidCallback? onSubmitted;

  const RatingDialog({
    super.key,
    required this.type,
    required this.id,
    required this.name,
    this.imageUrl,
    required this.orderId,
    this.onSubmitted,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.of(context)!.getText('pleaseSelectRating')), backgroundColor: CustomerAppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
      final result = await apiClient.post('/reviews', data: {
        'rating': _rating,
        'comment': _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        'reviewable_type': widget.type,
        'reviewable_id': widget.id,
        'order_id': widget.orderId,
      });

      if (result is Success) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalization.of(context)!.getText('reviewSubmitted')), backgroundColor: CustomerAppColors.success),
          );
          widget.onSubmitted?.call();
        }
      } else if (result is Failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text((result as Failure).exception.message), backgroundColor: CustomerAppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CustomerAppColors.error),
        );
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            if (widget.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: SizedBox(width: 64, height: 64, child: Image.network(widget.imageUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: CustomerAppColors.surfaceContainer,
                    child: const Icon(Icons.shopping_bag_outlined, size: 32, color: CustomerAppColors.primary)))),
              ),
            const SizedBox(height: AppDimensions.sm),
            Text(widget.name, style: AppTypography.h2_18, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.md),

            // Star rating
            Text(
              AppLocalization.of(context)!.getText('rateItem',
                  params: {'item': AppLocalization.of(context)!.getText(widget.type == 'product' ? 'product' : 'store')}),
              style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: index < _rating ? CustomerAppColors.accentGold : Colors.black,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppDimensions.md),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalization.of(context)!.getText('writeReviewHint'),
                hintStyle: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: CustomerAppColors.primary),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalization.of(context)!.getText('submitReview'), style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}