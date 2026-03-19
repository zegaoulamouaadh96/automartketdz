import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await ApiService.getSellerStats();
      setState(() {
        _stats = res['data'] ?? res['stats'] ?? res;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('الإحصائيات والتحليلات'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? Center(
                  child: Text('لا توجد بيانات',
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF111827))),
                )
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Revenue overview
                      _buildRevenueCard(),
                      const SizedBox(height: 20),

                      // Monthly sales chart
                      _buildMonthlySalesChart(),
                      const SizedBox(height: 20),

                      // Orders overview
                      _buildOrdersOverview(),
                      const SizedBox(height: 20),

                      // Best selling products
                      _buildBestSelling(),
                      const SizedBox(height: 20),

                      // Performance metrics
                      _buildPerformanceMetrics(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRevenueCard() {
    final revenue =
        double.tryParse(_stats?['total_revenue']?.toString() ?? '0') ?? 0;
    final profits = double.tryParse(_stats?['profits']?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Text('ملخص المالي',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي الإيرادات',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('${revenue.toStringAsFixed(0)} د.ج',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الأرباح',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('${profits.toStringAsFixed(0)} د.ج',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySalesChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final monthlySales = _stats?['monthly_sales'];
    if (monthlySales == null || monthlySales is! List || monthlySales.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal = monthlySales.fold<double>(0, (max, e) {
      final val = double.tryParse(e['revenue']?.toString() ?? '0') ?? 0;
      return val > max ? val : max;
    }).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Color(0xFFF97316), size: 22),
              const SizedBox(width: 8),
              Text('المبيعات الشهرية',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthlySales.map<Widget>((e) {
                final revenue =
                    double.tryParse(e['revenue']?.toString() ?? '0') ?? 0;
                final height = (revenue / maxVal) * 140;
                final month = e['month']?.toString() ?? '';
                final shortMonth =
                    month.length >= 7 ? month.substring(5, 7) : month;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${(revenue / 1000).toStringAsFixed(0)}K',
                            style: TextStyle(
                                fontSize: 8,
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.grey[600])),
                        const SizedBox(height: 4),
                        Container(
                          height: height.clamp(4.0, 140.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(shortMonth,
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.grey[600])),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersOverview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statuses = _stats?['orders_by_status'];
    final totalOrders = _stats?['total_orders'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  color: Color(0xFF8B5CF6), size: 22),
              const SizedBox(width: 8),
              Text('نظرة على الطلبات',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$totalOrders إجمالي',
                    style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (statuses is Map)
            ...{
              'delivered': {
                'label': 'تم التوصيل',
                'color': Colors.green,
                'icon': Icons.done_all
              },
              'shipped': {
                'label': 'تم الشحن',
                'color': Colors.teal,
                'icon': Icons.local_shipping
              },
              'processing': {
                'label': 'قيد التحضير',
                'color': Colors.indigo,
                'icon': Icons.settings
              },
              'pending': {
                'label': 'بانتظار',
                'color': Colors.orange,
                'icon': Icons.hourglass_empty
              },
              'cancelled': {
                'label': 'ملغي',
                'color': Colors.red,
                'icon': Icons.cancel
              },
            }.entries.map((e) {
              final count = statuses[e.key] ?? 0;
              final info = e.value;
              final total =
                  totalOrders is int && totalOrders > 0 ? totalOrders : 1;
              final pct = count / total;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Icon(info['icon'] as IconData,
                        color: info['color'] as Color, size: 20),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 80,
                      child: Text(info['label'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFD1D5DB)
                                  : const Color(0xFF111827))),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor:
                              (info['color'] as Color).withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation(info['color'] as Color),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$count',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: info['color'] as Color)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBestSelling() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final products = _stats?['best_selling_products'];
    if (products == null || products is! List || products.isEmpty)
      return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Color(0xFFF97316), size: 22),
              const SizedBox(width: 8),
              Text('المنتجات الأكثر مبيعاً',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(products.length.clamp(0, 5), (i) {
            final p = products[i];
            final totalSold = p['total_sold'] ?? 0;
            final maxSold =
                (products[0]['total_sold'] ?? 1).clamp(1, double.infinity);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? Colors.amber
                          : i == 1
                              ? Colors.grey[400]
                              : i == 2
                                  ? Colors.brown[300]
                                  : (isDark
                                      ? const Color(0xFF374151)
                                      : Colors.grey[200]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: i < 3 ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Image
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF1F2937) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: p['primary_image'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                                ApiService.resolveMediaUrl(
                                    p['primary_image']?.toString()),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.inventory_2,
                                    size: 20,
                                    color: Colors.grey)))
                        : const Icon(Icons.inventory_2,
                            size: 20, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: totalSold / maxSold,
                            backgroundColor: const Color(0xFFFED7AA),
                            valueColor:
                                const AlwaysStoppedAnimation(Color(0xFFF97316)),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$totalSold',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFFF97316))),
                      Text('مبيع',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalOrders = _stats?['total_orders'] ?? 0;
    final totalReviews = _stats?['total_reviews'] ?? 0;
    final avgRating =
        double.tryParse(_stats?['avg_rating']?.toString() ?? '0') ?? 0;
    final newOrders = _stats?['new_orders'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Color(0xFF3B82F6), size: 22),
              const SizedBox(width: 8),
              Text('مؤشرات الأداء',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _metricTile(
                  'طلبات جديدة', '$newOrders', Icons.fiber_new, Colors.orange),
              const SizedBox(width: 12),
              _metricTile(
                  'إجمالي الطلبات', '$totalOrders', Icons.receipt, Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricTile(
                  'التقييمات', '$totalReviews', Icons.reviews, Colors.purple),
              const SizedBox(width: 12),
              _metricTile('المتوسط', avgRating.toStringAsFixed(1), Icons.star,
                  Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
