import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/product_card.dart';
import 'product_screen.dart';
import 'search_screen.dart';
import 'store_screen.dart';
import 'notifications_screen.dart';
import 'seller/seller_messages_screen.dart';

// ── Banner model ──────────────────────────────────────────────────
class _BannerData {
  final String title, subtitle, cta;
  final IconData icon;
  final List<Color> gradient;
  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.gradient,
  });
}

// ── Constants ─────────────────────────────────────────────────────
const _orange = Color(0xFFF97316);

const _banners = [
  _BannerData(
    title: 'قطع غيار أصلية',
    subtitle: 'لجميع أنواع المركبات في الجزائر',
    icon: Icons.verified_rounded,
    gradient: [Color(0xFFF97316), Color(0xFFEA580C)],
    cta: 'تصفح المنتجات',
  ),
  _BannerData(
    title: 'عروض حصرية',
    subtitle: 'خصومات مميزة على قطع الغيار',
    icon: Icons.local_offer_rounded,
    gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    cta: 'اكتشف العروض',
  ),
  _BannerData(
    title: 'افتح متجرك الآن',
    subtitle: 'ابدأ بيع قطع الغيار وزد أرباحك',
    icon: Icons.storefront_rounded,
    gradient: [Color(0xFF10B981), Color(0xFF059669)],
    cta: 'ابدأ الآن',
  ),
  _BannerData(
    title: 'توصيل سريع',
    subtitle: 'إلى جميع ولايات الجزائر',
    icon: Icons.local_shipping_rounded,
    gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    cta: 'اطلب الآن',
  ),
];

// ══════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Category> _categories = [];
  List<Product> _latestProducts = [];
  List<Product> _topRatedProducts = [];
  List<Store> _popularStores = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;
  int _currentIndex = 0;
  bool _maintenanceMode = false;
  int _unreadNotifications = 0;

  // Banner carousel
  final PageController _bannerCtl = PageController();
  int _currentBanner = 0;
  Timer? _bannerTimer;

  // Entrance animation
  late final AnimationController _entranceCtl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _entranceCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _entranceCtl, curve: Curves.easeOut);
    _loadData();
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtl.dispose();
    _entranceCtl.dispose();
    super.dispose();
  }

  int get _totalBannerPages => _banners.length + _announcements.length;

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerCtl.hasClients) return;
      final total = _totalBannerPages;
      if (total == 0) return;
      final next = (_currentBanner + 1) % total;
      _bannerCtl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getProducts(limit: 10, sort: 'newest'),
        ApiService.getProducts(limit: 8, sort: 'rating'),
        ApiService.getStores(),
        ApiService.getAnnouncements()
            .catchError((_) => <String, dynamic>{'announcements': []}),
        ApiService.getAppSettings()
            .catchError((_) => <String, dynamic>{'settings': {}}),
      ]);
      if (!mounted) return;

      // Check maintenance mode
      final settings = results[5]['settings'] ?? {};
      final isMaintenance = settings['maintenance_mode'] == true ||
          settings['maintenance_mode'] == 'true';

      setState(() {
        _maintenanceMode = isMaintenance;

        final catData =
            results[0]['data'] ?? results[0]['categories'] ?? results[0];
        if (catData is List) {
          _categories = catData.map((c) => Category.fromJson(c)).toList();
        }

        final prodData = results[1]['data'] ?? results[1]['products'] ?? [];
        if (prodData is List) {
          _latestProducts = prodData.map((p) => Product.fromJson(p)).toList();
        }

        final topData = results[2]['data'] ?? results[2]['products'] ?? [];
        if (topData is List) {
          _topRatedProducts = topData.map((p) => Product.fromJson(p)).toList();
        }

        final storeData = results[3]['data'] ?? results[3]['stores'] ?? [];
        if (storeData is List) {
          _popularStores = storeData.map((s) => Store.fromJson(s)).toList();
        }

        final annData = results[4]['announcements'];
        if (annData is List) {
          _announcements = annData.cast<Map<String, dynamic>>();
        }

        _loading = false;
      });
      _entranceCtl.forward();
      _loadUnreadNotifications();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _entranceCtl.forward();
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final data = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _unreadNotifications = data['unread_count'] ?? 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final screens = [
      _buildHome(),
      const SearchScreen(),
      const _OrdersTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 AutoMarket DZ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  if (!auth.isLoggedIn) {
                    Navigator.pushNamed(context, '/login');
                    return;
                  }
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  );
                  _loadUnreadNotifications();
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: themeProvider.isDarkMode
                ? 'تفعيل الوضع الفاتح'
                : 'تفعيل الوضع الداكن',
            icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => context.read<ThemeProvider>().toggleDarkMode(),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text('${cart.itemCount}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Maintenance mode red banner
          if (_maintenanceMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.red.shade700,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.construction_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'الموقع في وضع الصيانة حالياً',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: screens[_currentIndex]),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              heroTag: 'home_chat_fab',
              tooltip: 'الدردشة',
              onPressed: () async {
                if (!auth.isLoggedIn) {
                  Navigator.pushNamed(context, '/login');
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SellerMessagesScreen()),
                );
              },
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.chat_bubble_rounded),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'بحث'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'طلباتي'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }

  // ── Shimmer placeholder ──────────────────────────────────────────
  Widget _shimmerBlock(double w, double h, {double radius = 12}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1F2937) : Colors.grey[300]!,
      highlightColor: isDark ? const Color(0xFF374151) : Colors.grey[100]!,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _shimmerBlock(double.infinity, 52),
        const SizedBox(height: 20),
        _shimmerBlock(double.infinity, 170, radius: 20),
        const SizedBox(height: 20),
        _shimmerBlock(120, 18, radius: 6),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: Row(
              children: List.generate(
                  4,
                  (i) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(children: [
                        _shimmerBlock(60, 60, radius: 16),
                        const SizedBox(height: 6),
                        _shimmerBlock(56, 10, radius: 4),
                      ])))),
        ),
        const SizedBox(height: 24),
        _shimmerBlock(140, 18, radius: 6),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _shimmerBlock(double.infinity, 200, radius: 20)),
          const SizedBox(width: 12),
          Expanded(child: _shimmerBlock(double.infinity, 200, radius: 20)),
        ]),
      ],
    );
  }

  // ── Home body ────────────────────────────────────────────────────
  Widget _buildHome() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        theme.textTheme.titleMedium?.color ?? const Color(0xFF0F172A);
    final textSecondary =
        (theme.textTheme.bodyMedium?.color ?? const Color(0xFF64748B))
            .withValues(alpha: 0.8);

    if (_loading) return _buildShimmerLoading();

    return FadeTransition(
      opacity: _fadeIn,
      child: RefreshIndicator(
        color: _orange,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),

            // ── 1. Search bar with animated hint ──
            _AnimatedSearchBar(
              isDark: isDark,
              textSecondary: textSecondary,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            const SizedBox(height: 20),

            // ── 2. Banner carousel (static + API announcements) ──
            SizedBox(
              height: 175,
              child: PageView.builder(
                controller: _bannerCtl,
                itemCount: _totalBannerPages,
                onPageChanged: (i) => setState(() => _currentBanner = i),
                itemBuilder: (_, i) {
                  if (i < _announcements.length) {
                    return _buildAnnouncementCard(_announcements[i], isDark);
                  }
                  return _buildBannerCard(_banners[i - _announcements.length]);
                },
              ),
            ),
            const SizedBox(height: 12),
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalBannerPages,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentBanner == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentBanner == i
                        ? _orange
                        : (isDark ? Colors.white24 : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ── 3. Quick action chips ──
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _quickChip(Icons.new_releases_rounded, 'وصل حديثاً',
                      const Color(0xFFF97316), isDark, () {
                    setState(() => _currentIndex = 1);
                  }),
                  _quickChip(Icons.local_offer_rounded, 'عروض',
                      const Color(0xFF8B5CF6), isDark, () {
                    setState(() => _currentIndex = 1);
                  }),
                  _quickChip(Icons.star_rounded, 'الأعلى تقييماً',
                      const Color(0xFFF59E0B), isDark, () {
                    setState(() => _currentIndex = 1);
                  }),
                  _quickChip(Icons.storefront_rounded, 'المتاجر',
                      const Color(0xFF10B981), isDark, () {
                    setState(() => _currentIndex = 1);
                  }),
                  _quickChip(Icons.local_shipping_rounded, 'توصيل',
                      const Color(0xFF3B82F6), isDark, () {
                    setState(() => _currentIndex = 1);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 4. Categories with animated entrance ──
            _sectionTitle('الأصناف', Icons.category_rounded, textPrimary),
            const SizedBox(height: 12),
            if (_categories.isNotEmpty)
              SizedBox(
                height: 105,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) => _buildCategoryChip(
                      _categories[i], i, isDark, textPrimary),
                ),
              ),
            const SizedBox(height: 28),

            // ── 5. Flash Deals (products with old price = discount) ──
            if (_flashDeals.isNotEmpty) ...[
              _sectionTitleWithAction(
                'عروض خاصة 🔥',
                Icons.flash_on_rounded,
                textPrimary,
                'عرض الكل',
                () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _flashDeals.length,
                  itemBuilder: (_, i) =>
                      _buildFlashDealCard(_flashDeals[i], isDark),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── 6. Popular stores ──
            if (_popularStores.isNotEmpty) ...[
              _sectionTitleWithAction(
                'متاجر مميزة',
                Icons.storefront_rounded,
                textPrimary,
                'عرض الكل',
                () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularStores.length,
                  itemBuilder: (_, i) =>
                      _buildStoreCard(_popularStores[i], isDark, textPrimary),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── 7. Top rated products ──
            if (_topRatedProducts.isNotEmpty) ...[
              _sectionTitleWithAction(
                'الأعلى تقييماً',
                Icons.star_rounded,
                textPrimary,
                'عرض الكل',
                () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _topRatedProducts.length,
                  itemBuilder: (_, i) => SizedBox(
                    width: 170,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: ProductCard(product: _topRatedProducts[i]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── 8. Latest products grid ──
            _sectionTitleWithAction(
              'أحدث المنتجات',
              Icons.fiber_new_rounded,
              textPrimary,
              'عرض الكل',
              () => setState(() => _currentIndex = 1),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _latestProducts.length,
              itemBuilder: (ctx, i) => ProductCard(product: _latestProducts[i]),
            ),
            const SizedBox(height: 28),

            // ── 9. App features info strip ──
            _buildFeaturesStrip(isDark),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  // ── Flash deals = products that have an oldPrice ─────────────────
  List<Product> get _flashDeals => [
        ..._latestProducts
            .where((p) => p.oldPrice != null && p.oldPrice! > p.price),
        ..._topRatedProducts
            .where((p) => p.oldPrice != null && p.oldPrice! > p.price),
      ].take(8).toList();

  // ── Banner card ──────────────────────────────────────────────────
  Widget _buildBannerCard(_BannerData b) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: b.gradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: b.gradient.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(b.title,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2)),
                      const SizedBox(height: 8),
                      Text(b.subtitle,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () => setState(() => _currentIndex = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: b.gradient.first,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            elevation: 0,
                          ),
                          child: Text(b.cta,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(b.icon, size: 36, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Announcement card (from API) ─────────────────────────────────
  Widget _buildAnnouncementCard(Map<String, dynamic> ann, bool isDark) {
    final type = ann['type'] ?? 'info';
    final text = ann['text'] ?? '';

    final Map<String, List<Color>> typeGradients = {
      'info': [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      'warning': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      'success': [const Color(0xFF10B981), const Color(0xFF059669)],
      'danger': [const Color(0xFFEF4444), const Color(0xFFDC2626)],
    };
    final Map<String, IconData> typeIcons = {
      'info': Icons.campaign_rounded,
      'warning': Icons.warning_amber_rounded,
      'success': Icons.check_circle_rounded,
      'danger': Icons.error_rounded,
    };

    final gradient = typeGradients[type] ?? typeGradients['info']!;
    final icon = typeIcons[type] ?? Icons.campaign_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('📣 إعلان',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 36, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick action chip ────────────────────────────────────────────
  Widget _quickChip(IconData icon, String label, Color color, bool isDark,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Material(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Category chip ────────────────────────────────────────────────
  Widget _buildCategoryChip(
      Category cat, int index, bool isDark, Color textColor) {
    // Each chip enters with a slight delay
    final delay = index * 80;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutBack,
      builder: (_, val, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - val)),
        child: Opacity(opacity: val.clamp(0, 1), child: child),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SearchScreen(initialCategory: cat.id)),
        ),
        child: Container(
          width: 82,
          margin: const EdgeInsets.only(left: 10),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF312012), const Color(0xFF1C1206)]
                        : [const Color(0xFFFFF7ED), const Color(0xFFFED7AA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _orange.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                    child: Text(cat.icon ?? '📦',
                        style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(height: 8),
              Text(cat.nameAr ?? cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Flash deal card ──────────────────────────────────────────────
  Widget _buildFlashDealCard(Product product, bool isDark) {
    final discount = product.oldPrice != null && product.oldPrice! > 0
        ? ((product.oldPrice! - product.price) / product.oldPrice! * 100)
            .round()
        : 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductScreen(productId: product.id)),
      ),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + discount badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: product.images.isNotEmpty
                        ? Image.network(
                            ApiService.resolveMediaUrl(product.images.first),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF2A2A3A)
                                  : const Color(0xFFF1F5F9),
                              child: const Icon(Icons.image_not_supported,
                                  size: 40, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: isDark
                                ? const Color(0xFF2A2A3A)
                                : const Color(0xFFF1F5F9),
                            child: const Icon(Icons.inventory_2_rounded,
                                size: 40, color: Colors.grey),
                          ),
                  ),
                ),
                if (discount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('-$discount%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87)),
                    const Spacer(),
                    Row(
                      children: [
                        Text('${product.price.toStringAsFixed(0)} د.ج',
                            style: const TextStyle(
                                color: _orange,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        const SizedBox(width: 6),
                        if (product.oldPrice != null)
                          Text('${product.oldPrice!.toStringAsFixed(0)}',
                              style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                  fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Store card ───────────────────────────────────────────────────
  Widget _buildStoreCard(Store store, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StoreScreen(storeId: store.id)),
      ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: store.logo != null && store.logo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            ApiService.resolveMediaUrl(store.logo!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.store,
                                    color: Colors.white, size: 22)),
                          ),
                        )
                      : Center(
                          child: Text(
                            store.name.isNotEmpty
                                ? store.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: textColor)),
                      if (store.wilaya != null)
                        Text(store.wilaya!,
                            style: TextStyle(
                                fontSize: 11,
                                color: textColor.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.star_rounded,
                    size: 16, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(store.rating.toStringAsFixed(1),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: textColor)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${store.productCount} منتج',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _orange)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section title helpers ────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 22, color: _orange),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _sectionTitleWithAction(String title, IconData icon, Color color,
      String action, VoidCallback onTap) {
    return Row(
      children: [
        Icon(icon, size: 22, color: _orange),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const Spacer(),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: _orange,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ── App features strip ───────────────────────────────────────────
  Widget _buildFeaturesStrip(bool isDark) {
    final items = [
      (Icons.verified_user_rounded, 'قطع أصلية', const Color(0xFF10B981)),
      (Icons.local_shipping_rounded, 'توصيل سريع', const Color(0xFF3B82F6)),
      (Icons.payment_rounded, 'دفع آمن', const Color(0xFF8B5CF6)),
      (Icons.support_agent_rounded, 'دعم 24/7', const Color(0xFFF97316)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : _orange.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : _orange.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items
            .map((e) => Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: e.$3.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(e.$1, size: 22, color: e.$3),
                    ),
                    const SizedBox(height: 6),
                    Text(e.$2,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54)),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

// ── Animated search bar with cycling hints ─────────────────────────
class _AnimatedSearchBar extends StatefulWidget {
  final bool isDark;
  final Color textSecondary;
  final VoidCallback onTap;
  const _AnimatedSearchBar({
    required this.isDark,
    required this.textSecondary,
    required this.onTap,
  });
  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  static const _hints = [
    'ابحث عن قطع الغيار...',
    'فلاتر زيت، بواجي...',
    'قطع غيار أصلية...',
    'اكتب اسم القطعة...',
  ];
  int _hintIndex = 0;
  late final AnimationController _ctl;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);
    _ctl.value = 1;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _cycleHint());
  }

  void _cycleHint() async {
    await _ctl.reverse();
    if (!mounted) return;
    setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    _ctl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1F2937) : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: widget.textSecondary, size: 22),
            const SizedBox(width: 10),
            FadeTransition(
              opacity: _fade,
              child: Text(_hints[_hintIndex],
                  style: TextStyle(color: widget.textSecondary, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('سجّل دخولك لعرض طلباتك'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );
    }
    return const Center(child: Text('اضغط لعرض الطلبات'));
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary),
              child: const Text('تسجيل الدخول',
                  style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('إنشاء حساب جديد'),
            ),
          ],
        ),
      );
    }

    final avatar = auth.user!.avatar;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(ApiService.resolveMediaUrl(avatar))
                      : null,
                  child: avatar == null || avatar.isEmpty
                      ? Icon(Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                const SizedBox(height: 12),
                Text('${auth.user!.firstName} ${auth.user!.lastName}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(auth.user!.email,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _profileTile(Icons.person, 'الملف الشخصي',
            () => Navigator.pushNamed(context, '/profile')),
        _profileTile(Icons.receipt_long, 'طلباتي',
            () => Navigator.pushNamed(context, '/orders')),
        _profileTile(Icons.shopping_cart, 'سلة المشتريات',
            () => Navigator.pushNamed(context, '/cart')),
        const Divider(),
        _profileTile(Icons.logout, 'تسجيل الخروج', () async {
          await auth.logout();
        }, color: Colors.red),
      ],
    );
  }

  Widget _profileTile(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    final defaultColor = color ?? const Color(0xFFF97316);

    return ListTile(
      leading: Icon(icon, color: defaultColor),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
