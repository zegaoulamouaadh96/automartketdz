import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMyProducts();
      final data = res['data'] ?? res['products'] ?? [];
      setState(() {
        if (data is List)
          _products = data.map((p) => Product.fromJson(p)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "$name"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.deleteProduct(id);
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حذف المنتج'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('منتجاتي'),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: const Icon(Icons.add_circle,
                  color: Color(0xFFF97316), size: 28),
              onPressed: () =>
                  Navigator.pushNamed(context, '/seller-add-product')
                      .then((_) => _loadProducts()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) => _productCard(_products[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/seller-add-product')
            .then((_) => _loadProducts()),
        backgroundColor: const Color(0xFFF97316),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة منتج',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
                  (isDark ? const Color(0xFF312012) : const Color(0xFFFED7AA))
                      .withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 64, color: Color(0xFFF97316)),
          ),
          const SizedBox(height: 20),
          Text('لا توجد منتجات بعد',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('أضف أول منتج لبدء البيع',
              style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/seller-add-product')
                .then((_) => _loadProducts()),
            icon: const Icon(Icons.add),
            label: const Text('إضافة منتج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = product.images.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ApiService.resolveMediaUrl(product.images.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image,
                            color: Colors.grey, size: 36),
                      ),
                    )
                  : const Icon(Icons.image, color: Colors.grey, size: 36),
            ),
            const SizedBox(width: 14),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF111827)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('${product.price.toStringAsFixed(0)} د.ج',
                          style: const TextStyle(
                              color: Color(0xFFF97316),
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      if (product.oldPrice != null) ...[
                        const SizedBox(width: 8),
                        Text('${product.oldPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _tag(product.isActive ? 'نشط' : 'غير نشط',
                          product.isActive ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      _tag('${product.quantity} في المخزون',
                          product.quantity > 0 ? Colors.blue : Colors.red),
                      const SizedBox(width: 8),
                      _tag(product.condition == 'new' ? 'جديد' : 'مستعمل',
                          Colors.grey),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  onPressed: () => _deleteProduct(product.id, product.name),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 22),
                  splashRadius: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
