import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class StoreScreen extends StatefulWidget {
  final String storeId;
  const StoreScreen({super.key, required this.storeId});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Store? _store;
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    try {
      final results = await Future.wait([
        ApiService.getStore(widget.storeId),
        ApiService.getProducts(limit: 30),
      ]);

      final storeData = results[0]['data'] ?? results[0]['store'] ?? results[0];
      final prodData = results[1]['data'] ?? results[1]['products'] ?? [];

      setState(() {
        _store = Store.fromJson(storeData);
        if (prodData is List) {
          _products = prodData
              .map((p) => Product.fromJson(p))
              .where((p) => p.storeId == widget.storeId)
              .toList();
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        theme.textTheme.titleMedium?.color ?? const Color(0xFF0F172A);
    final textSecondary =
        (theme.textTheme.bodyMedium?.color ?? const Color(0xFF64748B))
            .withValues(alpha: 0.85);

    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_store == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('المتجر غير موجود')),
      );
    }
    final store = _store!;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Store header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(store.name, style: const TextStyle(fontSize: 16)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: store.logo != null &&
                              store.logo!.isNotEmpty
                          ? NetworkImage(ApiService.resolveMediaUrl(store.logo))
                          : null,
                      child: store.logo == null || store.logo!.isEmpty
                          ? const Icon(Icons.store_rounded,
                              size: 42, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Store info
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('المنتجات', '${store.productCount}'),
                      _statItem(
                          'التقييم', '⭐ ${store.rating.toStringAsFixed(1)}'),
                      _statItem('التقييمات', '${store.reviewCount}'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location
                  if (store.wilaya != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                            '${store.wilaya}${store.city != null ? " - ${store.city}" : ""}',
                            style: TextStyle(color: textSecondary)),
                      ],
                    ),
                  if (store.phone != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 18, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(store.phone!,
                            style: TextStyle(color: textSecondary)),
                      ],
                    ),
                  ],

                  if (store.description != null &&
                      store.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(store.description!,
                        style: TextStyle(color: textSecondary, height: 1.5)),
                  ],

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('منتجات المتجر (${_products.length})',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Products grid
          _products.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48,
                              color: isDark
                                  ? const Color(0xFF4B5563)
                                  : Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('لا توجد منتجات',
                              style: TextStyle(color: textSecondary)),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => ProductCard(product: _products[i]),
                      childCount: _products.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    final textSecondary = (Theme.of(context).textTheme.bodyMedium?.color ??
            const Color(0xFF64748B))
        .withValues(alpha: 0.85);

    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
      ],
    );
  }
}
