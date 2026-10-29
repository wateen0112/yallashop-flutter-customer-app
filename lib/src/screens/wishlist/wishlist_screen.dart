import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.getText('wishlistTitle'))),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: AppDimensions.sm,
          mainAxisSpacing: AppDimensions.sm,
        ),
        itemCount: 6,
        itemBuilder: (_, index) => ProductCard(
          imageUrl: 'https://via.placeholder.com/200x200/F2B705/000000?text=Wish+${index + 1}',
          title: loc.getText('wishlistItem', params: {'index': '${index + 1}'}),
          price: 34.99 + index * 3,
          originalPrice: index % 2 == 0 ? 59.99 : null,
          rating: 4.5,
          isWishlisted: true,
          onWishlistTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.getText('removedFromWishlist'))),
            );
          },
          onTap: () => context.push('/product/${index + 1}'),
        ),
      ),
    );
  }
}
