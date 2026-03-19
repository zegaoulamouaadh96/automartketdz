import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'create_store_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = true;
  String? _error;
  bool _needsStoreSetup = false;
  Map<String, dynamic>? _data;
  late AnimationController _animCtrl;
  late AnimationController _pulseCtrl;
  Timer? _liveRefreshTimer;

  static const _primary = Color(0xFFF97316);
  static const _primaryDark = Color(0xFFC2410C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _loadData();

    // Keep stats near-real-time for seller operations.
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        _loadData(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveRefreshTimer?.cancel();
    _animCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadData(showLoader: false);
    }
  }

  Future<void> _openAndRefresh(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (mounted) {
      await _loadData(showLoader: false);
    }
  }

  Future<void> _openCreateStoreAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateStoreScreen(replaceExisting: true),
      ),
    );

    if (mounted) {
      await _loadData(showLoader: true);
    }
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final storeRes = await ApiService.getMyStore();
      final statsRes = await ApiService.getSellerStats();

      final store = Map<String, dynamic>.from(storeRes['store'] ?? {});
      final stats = Map<String, dynamic>.from(statsRes['stats'] ?? {});
      final orderStatuses =
          Map<String, dynamic>.from(stats['orders_by_status'] ?? {});
      final bestSelling = List<Map<String, dynamic>>.from(
          stats['best_selling_products'] ?? const []);

      setState(() {
        _data = {
          'store': store,
          'stats': stats,
          'orderStatuses': orderStatuses,
          'bestSelling': bestSelling,
        };
        _needsStoreSetup = false;
        _error = null;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;

      final normalized = e.toString().toLowerCase();
      final storeMissing = normalized.contains('store not found') ||
          normalized.contains("don't have a store yet") ||
          normalized.contains('you don\'t have a store yet');

      if (showLoader || _data == null) {
        setState(() {
          _error = e.toString().isEmpty ? 'حدث خطأ في الاتصال' : e.toString();
          _needsStoreSetup = storeMissing;
        });
      }
    } finally {
      if (mounted && showLoader) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAndRefresh('/seller-messages'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        tooltip: 'المراسلة',
        child: const Icon(Icons.forum_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Transform.scale(
                scale: 1.0 + 0.1 * _pulseCtrl.value,
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: _primary, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            const Text('جاري تحميل لوحة التحكم...',
                style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ],
        ),
      );
    }

    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    color: Colors.redAccent, size: 50),
              ),
              const SizedBox(height: 20),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (_needsStoreSetup)
                ElevatedButton.icon(
                  onPressed: _openCreateStoreAndRefresh,
                  icon: const Icon(Icons.store_mall_directory_rounded),
                  label: const Text('إنشاء متجر جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                )
            ],
          ),
        ),
      );
    }

    final store = _data?['store'] ?? {};
    final stats = _data?['stats'] ?? {};
    final statuses = _data?['orderStatuses'] ?? {};
    final topProducts = _data?['bestSelling'] as List? ?? [];

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          //  Premium App Bar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: _primary,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_rounded,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: () => _openAndRefresh('/seller-analytics'),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 20, right: 20),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (store['store_name'] ?? store['name'] ?? 'متجري')
                        .toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  if (store['wilaya'] != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            store['wilaya'] ?? '',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  store['logo'] != null
                      ? Image.network(
                          ApiService.resolveMediaUrl(store['logo']),
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.5),
                          colorBlendMode: BlendMode.darken,
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primary, _primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                  // Decorative circles
                  Positioned(
                    top: 60,
                    right: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 30,
                    right: 40,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    right: 30,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),

          //  Dashboard Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.08), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: _animCtrl, curve: Curves.easeOutCubic)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Stats
                      Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(
                                  'المبيعات',
                                  '${_formatMoney(stats['total_revenue'] ?? stats['total_sales'])} د.ج',
                                  Icons.account_balance_wallet_rounded,
                                  const Color(0xFF10B981))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildStatCard(
                                  'الطلبات',
                                  '${stats['total_orders'] ?? 0}',
                                  Icons.shopping_bag_rounded,
                                  const Color(0xFF3B82F6))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(
                                  'المنتجات',
                                  '${stats['total_products'] ?? 0}',
                                  Icons.inventory_2_rounded,
                                  const Color(0xFF8B5CF6))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildStatCard(
                                  'التقييم',
                                  '${stats['avg_rating']?.toString() ?? '0.0'}',
                                  Icons.star_rounded,
                                  const Color(0xFFF59E0B))),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Quick Actions
                      const Text('إجراءات سريعة',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 115,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildActionBtn(
                                'إضافة منتج',
                                Icons.add_box_rounded,
                                const Color(0xFF3B82F6),
                                () => _openAndRefresh('/seller-add-product')),
                            _buildActionBtn(
                                'منتجاتي',
                                Icons.list_alt_rounded,
                                const Color(0xFF8B5CF6),
                                () => _openAndRefresh('/seller-products')),
                            _buildActionBtn(
                                'الطلبات',
                                Icons.receipt_long_rounded,
                                const Color(0xFF10B981),
                                () => _openAndRefresh('/seller-orders')),
                            _buildActionBtn(
                                'التحليلات',
                                Icons.insights_rounded,
                                const Color(0xFFF59E0B),
                                () => _openAndRefresh('/seller-analytics')),
                            _buildActionBtn(
                                'التقييمات',
                                Icons.reviews_rounded,
                                const Color(0xFFEF4444),
                                () => _openAndRefresh('/seller-reviews')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Order Statuses
                      const Text('حالة الطلبات',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 16),
                      _buildOrderStatusSection(statuses),
                      const SizedBox(height: 32),

                      // Best Selling
                      const Text('المنتجات الأكثر مبيعاً',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 16),
                      if (topProducts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.trending_up_rounded,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('لا توجد مبيعات بعد',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      else
                        _buildBestSelling(topProducts),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (_, v, child) {
        final safeOpacity = v.clamp(0.0, 1.0).toDouble();
        return Transform.scale(
          scale: 0.85 + 0.15 * v,
          child: Opacity(opacity: safeOpacity, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 105,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusSection(Map<String, dynamic> statuses) {
    final statusInfo = {
      'pending': {
        'label': 'قيد الانتظار',
        'color': Colors.orange,
        'icon': Icons.hourglass_top_rounded
      },
      'processing': {
        'label': 'قيد التجهيز',
        'color': Colors.blue,
        'icon': Icons.settings_rounded
      },
      'shipped': {
        'label': 'تم الشحن',
        'color': Colors.teal,
        'icon': Icons.local_shipping_rounded
      },
      'delivered': {
        'label': 'تم التوصيل',
        'color': Colors.green,
        'icon': Icons.done_all_rounded
      },
      'cancelled': {
        'label': 'ملغي',
        'color': Colors.redAccent,
        'icon': Icons.cancel_outlined
      },
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: statusInfo.entries.map((e) {
          final rawCount = statuses[e.key] ?? 0;
          final count = e.key == 'pending'
              ? (int.tryParse('${statuses['pending'] ?? 0}') ?? 0) +
                  (int.tryParse('${statuses['confirmed'] ?? 0}') ?? 0)
              : (int.tryParse('$rawCount') ?? 0);
          final info = e.value;
          final color = info['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(left: 12),
            width: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(info['icon'] as IconData, color: color, size: 22),
                ),
                const SizedBox(height: 12),
                Text('$count',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color)),
                const SizedBox(height: 4),
                Text(info['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBestSelling(List products) {
    return Column(
      children: products.take(5).map<Widget>((p) {
        final productName = (p['name'] ?? p['product_name'] ?? '').toString();
        final soldQty = p['total_sold'] ?? p['sold_qty'] ?? 0;
        final amount = p['price'] ?? p['total_amount'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: p['primary_image'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          ApiService.resolveMediaUrl(
                              p['primary_image']?.toString()),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_rounded,
                              color: _primary),
                        ))
                    : const Icon(Icons.image_rounded, color: _primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.trending_up_rounded,
                                  size: 12, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text('$soldQty مبيع',
                                  style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${double.tryParse(amount.toString())?.toStringAsFixed(0) ?? '0'} د.ج',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _primary,
                      fontSize: 13),
                ),
              ),  

            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatMoney(dynamic val) {
    final n = double.tryParse(val?.toString() ?? '0') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

