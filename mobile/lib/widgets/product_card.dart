import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../screens/product_screen.dart';

class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  static const _orange = Color(0xFFF97316);

  Product get product => widget.product;

  void _onTap() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ProductScreen(productId: product.id),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: _orange.withValues(alpha: _pressed ? 0.1 : 0.0),
                blurRadius: 20,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image section ──
                Expanded(
                  flex: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF8F9FA),
                        ),
                        child: product.images.isNotEmpty
                            ? Hero(
                                tag: 'product_${product.id}',
                                child: Image.network(
                                  ApiService.resolveMediaUrl(product.images[0]),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _PlaceholderIcon(isDark: isDark),
                                ),
                              )
                            : _PlaceholderIcon(isDark: isDark),
                      ),
                      // Condition badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.condition == 'new'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: (product.condition == 'new'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF6366F1))
                                    .withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            product.condition == 'new' ? 'جديد' : 'مستعمل',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      // Rating badge
                      if (product.rating > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 13, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Gradient overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 30,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cardBg.withValues(alpha: 0.0),
                                cardBg.withValues(alpha: 0.6)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info section ──
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Store name
                        if (product.storeName != null)
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded,
                                  size: 12,
                                  color: textSecondary.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  product.storeName!,
                                  style: TextStyle(
                                      fontSize: 11, color: textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        // Price row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (product.oldPrice != null &&
                                      product.oldPrice! > product.price)
                                    Text(
                                      '${product.oldPrice!.toStringAsFixed(0)} د.ج',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: textSecondary,
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: textSecondary,
                                      ),
                                    ),
                                  Text(
                                    '${product.price.toStringAsFixed(0)} د.ج',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Stock indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: product.quantity > 0
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                product.quantity > 0 ? 'متوفر' : 'نفذ',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: product.quantity > 0
                                      ? const Color(0xFF10B981)
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final bool isDark;
  const _PlaceholderIcon({this.isDark = false});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_rounded,
              size: 36, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 4),
          Text('لا توجد صورة',
              style: TextStyle(
                  fontSize: 9,
                  color: isDark ? Colors.grey[600] : Colors.grey[400])),
        ],
      ),
    );
  }
}
