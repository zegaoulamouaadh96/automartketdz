import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'store_screen.dart';
import 'chat_screen.dart';

class ProductScreen extends StatefulWidget {
  final String productId;
  const ProductScreen({super.key, required this.productId});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen>
    with TickerProviderStateMixin {
  Product? _product;
  Map<String, dynamic> _rawData = {};
  bool _loading = true;
  int _selectedImage = 0;
  int _quantity = 1;
  List<dynamic> _reviews = [];
  List<dynamic> _fitments = [];
  List<dynamic> _oemRefs = [];
  int _myRating = 5;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _submittingReview = false;
  final PageController _pageCtrl = PageController();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _descExpanded = false;

  static const _orange = Color(0xFFF97316);
  static const _deepOrange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final res = await ApiService.getProduct(widget.productId);
      final productData = res['data'] ?? res['product'] ?? res;
      final product = Product.fromJson(productData);

      List<dynamic> reviews = [];
      try {
        final revRes = await ApiService.getProductReviews(widget.productId);
        reviews = revRes['data'] ?? revRes['reviews'] ?? [];
      } catch (_) {}

      final fitments = (productData is Map)
          ? (productData['fitments'] as List<dynamic>? ?? [])
          : <dynamic>[];
      final oems = (productData is Map)
          ? (productData['oem_references'] as List<dynamic>? ?? [])
          : <dynamic>[];

      setState(() {
        _product = product;
        _rawData = productData is Map<String, dynamic> ? productData : {};
        _reviews = reviews;
        _fitments = fitments;
        _oemRefs = oems;
        _loading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_submittingReview) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _submittingReview = true);
    try {
      await ApiService.addProductReview(
        productId: widget.productId,
        rating: _myRating,
        comment:
            _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      );
      _commentCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إرسال تقييمك بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      await _loadProduct();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<void> _openSellerChat() async {
    final p = _product;
    if (p == null || p.storeId == null) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      final storeRes = await ApiService.getStore(p.storeId!);
      final storeData = storeRes['store'] ?? storeRes['data'] ?? storeRes;
      final sellerId =
          (storeData is Map ? storeData['user_id'] : null)?.toString();

      if (sellerId == null || sellerId.isEmpty) {
        throw Exception('تعذر تحديد البائع لفتح المحادثة');
      }

      final startRes = await ApiService.startConversation(
        sellerId,
        'مرحبا، أريد الاستفسار عن المنتج: ${p.name}',
        productId: p.id,
      );

      final conversation = startRes['conversation'] ?? startRes['data'];
      final conversationId =
          (conversation is Map ? conversation['id'] : null)?.toString();

      if (conversationId == null || conversationId.isEmpty) {
        throw Exception('تعذر فتح المحادثة، حاول مرة أخرى');
      }

      final sellerName = p.storeName ??
          [
            (storeData is Map ? storeData['owner_first_name'] : null)
                ?.toString(),
            (storeData is Map ? storeData['owner_last_name'] : null)
                ?.toString(),
          ].where((n) => n != null && n.trim().isNotEmpty).join(' ').trim();

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserName: sellerName.isNotEmpty ? sellerName : 'البائع',
            otherUserAvatar: (storeData is Map
                    ? (storeData['logo'] ?? storeData['owner_avatar'])
                    : null)
                ?.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(_orange),
                ),
              ),
              const SizedBox(height: 16),
              Text('جاري تحميل المنتج...',
                  style: TextStyle(color: textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 64, color: textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('المنتج غير موجود',
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final p = _product!;
    final cart = context.read<CartProvider>();
    final hasDiscount = p.oldPrice != null && p.oldPrice! > p.price;
    final discountPercent = hasDiscount
        ? (((p.oldPrice! - p.price) / p.oldPrice!) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardBg.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
              ],
            ),
            child: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 22),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8),
                ],
              ),
              child: Icon(Icons.share_rounded, color: textPrimary, size: 20),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Image gallery ──
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  Container(
                    height: 380,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF0F0F2),
                    ),
                    child: p.images.isNotEmpty
                        ? PageView.builder(
                            controller: _pageCtrl,
                            itemCount: p.images.length,
                            onPageChanged: (i) =>
                                setState(() => _selectedImage = i),
                            itemBuilder: (_, i) => Hero(
                              tag: 'product_${p.id}_$i',
                              child: Image.network(
                                ApiService.resolveMediaUrl(p.images[i]),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.build_rounded,
                                      size: 64,
                                      color:
                                          textSecondary.withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.build_rounded,
                                size: 64,
                                color: textSecondary.withValues(alpha: 0.3)),
                          ),
                  ),
                  // Image counter badge
                  if (p.images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_rounded,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedImage + 1} / ${p.images.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Discount badge
                  if (hasDiscount)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 50,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8)
                          ],
                        ),
                        child: Text('-$discountPercent%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),

            // ── Image thumbnails ──
            if (p.images.length > 1)
              SliverToBoxAdapter(
                child: Container(
                  color: bg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: p.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final selected = i == _selectedImage;
                        return GestureDetector(
                          onTap: () {
                            _pageCtrl.animateToPage(i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? _orange : dividerColor,
                                width: selected ? 2.5 : 1.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color: _orange.withValues(alpha: 0.2),
                                          blurRadius: 8)
                                    ]
                                  : [],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                ApiService.resolveMediaUrl(p.images[i]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.image_rounded,
                                    size: 20,
                                    color: textSecondary),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // ── Main content card ──
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row
                    Row(
                      children: [
                        // Condition
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: p.condition == 'new'
                                ? const LinearGradient(colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669)
                                  ])
                                : const LinearGradient(colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF4F46E5)
                                  ]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  p.condition == 'new'
                                      ? Icons.fiber_new_rounded
                                      : Icons.recycling_rounded,
                                  size: 14,
                                  color: Colors.white),
                              const SizedBox(width: 4),
                              Text(p.condition == 'new' ? 'جديد' : 'مستعمل',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Category
                        if (p.categoryName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.category_rounded,
                                    size: 13, color: textSecondary),
                                const SizedBox(width: 4),
                                Text(p.categoryName!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        const Spacer(),
                        // Stock
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: p.quantity > 0
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  p.quantity > 0
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 14,
                                  color: p.quantity > 0
                                      ? const Color(0xFF10B981)
                                      : Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                  p.quantity > 0
                                      ? 'متوفر (${p.quantity})'
                                      : 'غير متوفر',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: p.quantity > 0
                                          ? const Color(0xFF10B981)
                                          : Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Product name
                    Text(p.name,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            height: 1.3)),
                    const SizedBox(height: 10),

                    // Rating
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(
                              5,
                              (i) => Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Icon(
                                      i < p.rating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 18,
                                      color: Colors.amber[700],
                                    ),
                                  )),
                          const SizedBox(width: 6),
                          Text(p.rating.toStringAsFixed(1),
                              style: TextStyle(
                                  color: Colors.amber[800],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('(${p.reviewCount} تقييم)',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${p.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: _orange)),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('د.ج',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _orange)),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('${p.oldPrice!.toStringAsFixed(0)} د.ج',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: textSecondary,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: textSecondary)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Vehicle compatibility ──
            if (_fitments.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF3B82F6),
                                Color(0xFF1D4ED8)
                              ]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.directions_car_filled_rounded,
                                size: 18,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text('التوافق مع السيارات',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${_fitments.length} سيارة',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ..._fitments.map((f) {
                        final brandName = f['brand_name']?.toString() ?? '';
                        final modelName = f['model_name']?.toString() ?? '';
                        final yearStart = f['year_start']?.toString() ?? '';
                        final yearEnd = f['year_end']?.toString() ?? '';
                        final notes = f['notes']?.toString() ?? '';
                        final yearRange = yearStart.isNotEmpty
                            ? '$yearStart${yearEnd.isNotEmpty ? ' - $yearEnd' : '+'}'
                            : '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[900]
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.directions_car_rounded,
                                    size: 20, color: Color(0xFF3B82F6)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$brandName ${modelName.isNotEmpty ? '- $modelName' : ''}',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary),
                                    ),
                                    if (yearRange.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded,
                                                size: 12, color: textSecondary),
                                            const SizedBox(width: 4),
                                            Text(yearRange,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: textSecondary)),
                                          ],
                                        ),
                                      ),
                                    if (notes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(notes,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: textSecondary,
                                                fontStyle: FontStyle.italic)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            // ── Store card ──
            if (p.storeName != null)
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () {
                    if (p.storeId != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  StoreScreen(storeId: p.storeId!)));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_orange, _deepOrange]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.store_rounded,
                              size: 24, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.storeName!,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary)),
                              if (_rawData['store_wilaya'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on_rounded,
                                          size: 13, color: textSecondary),
                                      const SizedBox(width: 3),
                                      Text(_rawData['store_wilaya'].toString(),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: textSecondary)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Description card ──
            if (p.description != null && p.description!.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.description_rounded,
                                size: 18, color: _orange),
                          ),
                          const SizedBox(width: 12),
                          Text('الوصف',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedCrossFade(
                        firstChild: Text(p.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.6)),
                        secondChild: Text(p.description!,
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.6)),
                        crossFadeState: _descExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                      if (p.description!.length > 120)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _descExpanded = !_descExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                _descExpanded ? 'عرض أقل' : 'عرض المزيد',
                                style: const TextStyle(
                                    color: _orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ── Details card ──
            if (p.sku != null || p.warrantyInfo != null || _oemRefs.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.info_outline_rounded,
                                size: 18, color: Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(width: 12),
                          Text('التفاصيل الفنية',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildDetailTile(Icons.qr_code_rounded, 'رقم القطعة',
                          p.sku, textPrimary, textSecondary, isDark),
                      _buildDetailTile(Icons.verified_user_rounded, 'الضمان',
                          p.warrantyInfo, textPrimary, textSecondary, isDark),
                      _buildDetailTile(
                          Icons.new_releases_rounded,
                          'الحالة',
                          p.condition == 'new' ? 'جديد' : 'مستعمل',
                          textPrimary,
                          textSecondary,
                          isDark),
                      if (_oemRefs.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('مراجع OEM',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _oemRefs.map((oem) {
                            final ref =
                                oem['reference_number']?.toString() ?? '';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(ref,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: textPrimary,
                                      fontWeight: FontWeight.w500)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // ── Quantity selector ──
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded,
                          size: 18, color: _orange),
                    ),
                    const SizedBox(width: 12),
                    Text('الكمية',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _quantityBtn(Icons.remove_rounded, () {
                            if (_quantity > 1) setState(() => _quantity--);
                          }, isDark),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text('$_quantity',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary)),
                          ),
                          _quantityBtn(Icons.add_rounded, () {
                            if (_quantity < p.quantity)
                              setState(() => _quantity++);
                          }, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Reviews section ──
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.rate_review_rounded,
                              size: 18, color: Colors.amber[700]),
                        ),
                        const SizedBox(width: 12),
                        Text('التقييمات',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textPrimary)),
                        const Spacer(),
                        if (_reviews.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${_reviews.length}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Add review
                    if (context.watch<AuthProvider>().isLoggedIn)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[900]
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('أضف تقييمك',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: textPrimary)),
                            const SizedBox(height: 10),
                            Row(
                              children: List.generate(5, (i) {
                                final star = i + 1;
                                return GestureDetector(
                                  onTap: () => setState(() => _myRating = star),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      star <= _myRating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 28,
                                      color: Colors.amber[600],
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _commentCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'اكتب تعليقك (اختياري)',
                                hintStyle: TextStyle(
                                    color: textSecondary, fontSize: 13),
                                filled: true,
                                fillColor: cardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: dividerColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: dividerColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: _orange, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _submittingReview ? null : _submitReview,
                                icon: _submittingReview
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 18),
                                label: Text(
                                    _submittingReview
                                        ? 'جاري الإرسال...'
                                        : 'إرسال التقييم',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[900]
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.login_rounded,
                                size: 20, color: textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('سجل دخولك لإضافة تقييم',
                                    style: TextStyle(
                                        color: textSecondary, fontSize: 13))),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/login'),
                              child: const Text('دخول',
                                  style: TextStyle(
                                      color: _orange,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),

                    if (_reviews.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              Icon(Icons.reviews_rounded,
                                  size: 36,
                                  color: textSecondary.withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              Text('لا توجد تقييمات بعد',
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._reviews.take(5).map((r) => _reviewCard(
                          r, textPrimary, textSecondary, isDark, dividerColor)),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom spacer for bottom bar
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),

      // ── Bottom bar ──
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            // Chat button
            GestureDetector(
              onTap: _openSellerChat,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.chat_rounded, color: textPrimary, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Add to cart
            Expanded(
              child: GestureDetector(
                onTap: p.quantity > 0
                    ? () {
                        HapticFeedback.mediumImpact();
                        cart.addItem(p, quantity: _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('تمت الإضافة إلى السلة'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            action: SnackBarAction(
                                label: 'السلة',
                                textColor: Colors.white,
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/cart')),
                          ),
                        );
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: p.quantity > 0
                        ? const LinearGradient(colors: [_orange, _deepOrange])
                        : null,
                    color: p.quantity > 0
                        ? null
                        : (isDark ? Colors.grey[800] : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: p.quantity > 0
                        ? [
                            BoxShadow(
                                color: _orange.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4)),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_rounded,
                          color: p.quantity > 0 ? Colors.white : textSecondary,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(p.quantity > 0 ? 'أضف إلى السلة' : 'غير متوفر',
                          style: TextStyle(
                              color:
                                  p.quantity > 0 ? Colors.white : textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
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

  Widget _quantityBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 20, color: _orange),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String? value,
      Color textPrimary, Color textSecondary, bool isDark) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: textSecondary),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _reviewCard(dynamic review, Color textPrimary, Color textSecondary,
      bool isDark, Color dividerColor) {
    final firstName = (review['first_name'] ?? '').toString().trim();
    final lastName = (review['last_name'] ?? '').toString().trim();
    final combinedName =
        [firstName, lastName].where((name) => name.isNotEmpty).join(' ').trim();
    final userName = combinedName.isNotEmpty
        ? combinedName
        : (review['user_name'] ?? 'مستخدم').toString();
    final rating = int.tryParse('${review['rating'] ?? 0}') ?? 0;
    final comment = (review['comment'] ?? '').toString();
    final avatar = review['avatar']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _orange.withValues(alpha: 0.1),
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? NetworkImage(ApiService.resolveMediaUrl(avatar))
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: _orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textPrimary)),
                    Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                                i < rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 14,
                                color: Colors.amber[600],
                              )),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment,
                style:
                    TextStyle(color: textSecondary, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }
}
