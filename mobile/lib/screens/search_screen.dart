import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialQuery;

  const SearchScreen({super.key, this.initialCategory, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  List<Product> _products = [];
  List<PublicProfile> _users = [];
  List<Store> _stores = [];
  List<Category> _categories = [];
  List<Map<String, dynamic>> _vehicleBrands = [];
  bool _loading = false;
  int _selectedTab = 0; // 0=Products, 1=Users, 2=Stores
  String? _selectedCategory;
  String? _selectedBrand;
  String? _selectedBrandName;
  String _sort = 'newest';
  String _condition = '';
  bool _searchBarCollapsed = false;
  Timer? _debounce;
  late AnimationController _shimmerController;
  late AnimationController _fabController;

  static const _orange = Color(0xFFF97316);
  static const _deepOrange = Color(0xFFEA580C);
  static const _ink = Color(0xFF0F172A);
  static const _smoke = Color(0xFFF8FAFC);
  static const _night = Color(0xFF0B1220);

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.initialQuery != null) _searchCtrl.text = widget.initialQuery!;

    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _fabController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _scrollController.addListener(() {
      final collapsed = _scrollController.offset > 60;
      if (collapsed != _searchBarCollapsed) {
        setState(() => _searchBarCollapsed = collapsed);
      }
      if (_scrollController.offset > 200) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });

    _loadCategories();
    _loadVehicleBrands();
    _search();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ApiService.getCategories();
      final data = res['data'] ?? res['categories'] ?? res;
      if (data is List) {
        setState(
            () => _categories = data.map((c) => Category.fromJson(c)).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadVehicleBrands() async {
    try {
      final res = await ApiService.getBrands();
      final data = res['data'] ?? res['brands'] ?? res;
      if (data is List) {
        setState(() => _vehicleBrands = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search();
    });
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      if (_selectedTab == 0) {
        // Search Products
        final res = await ApiService.getProducts(
          search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
          category: _selectedCategory,
          sort: _sort,
          condition: _condition.isNotEmpty ? _condition : null,
          brand: _selectedBrand,
          limit: 40,
        );
        final data = res['data'] ?? res['products'] ?? [];
        setState(() {
          if (data is List) {
            _products = data.map((p) => Product.fromJson(p)).toList();
          }
          _loading = false;
        });
      } else if (_selectedTab == 1) {
        // Search Users
        final res = await ApiService.searchUsers(
          search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
          limit: 40,
        );
        final data = res['data'] ?? res['users'] ?? [];
        setState(() {
          if (data is List) {
            _users = data.map((u) => PublicProfile.fromJson(u)).toList();
          }
          _loading = false;
        });
      } else {
        // Search Stores
        final res = await ApiService.getStores(
          search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
          limit: 40,
        );
        final data = res['data'] ?? res['stores'] ?? [];
        setState(() {
          if (data is List) {
            _stores = data.map((s) => Store.fromJson(s)).toList();
          }
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _night : _smoke;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final surfaceColor = isDark ? const Color(0xFF1B2437) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        floatingActionButton: ScaleTransition(
          scale: _fabController,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: _orange,
            onPressed: () => _scrollController.animateTo(0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic),
            child: const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white),
          ),
        ),
        body: SafeArea(
          child: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ── Animated search header ──
              SliverToBoxAdapter(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(
                      16, _searchBarCollapsed ? 8 : 16, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF0F172A), const Color(0xFF111827)]
                          : [Colors.white, const Color(0xFFF1F5F9)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      AnimatedCrossFade(
                        firstChild: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              if (widget.initialCategory != null ||
                                  widget.initialQuery != null)
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.arrow_back_ios_rounded,
                                      color: textPrimary, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              if (widget.initialCategory != null ||
                                  widget.initialQuery != null)
                                const SizedBox(width: 8),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [_orange, _deepOrange],
                                ).createShader(bounds),
                                child: Text('البحث',
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                              const Spacer(),
                              _buildActiveFiltersBadge(textSecondary),
                            ],
                          ),
                        ),
                        secondChild: const SizedBox(height: 4),
                        crossFadeState: _searchBarCollapsed
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),

                      // ── Search field ──
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  surfaceColor.withValues(
                                      alpha: isDark ? 0.52 : 0.85),
                                  surfaceColor.withValues(
                                      alpha: isDark ? 0.35 : 0.72),
                                ],
                              ),
                              border: Border.all(
                                color: _orange.withValues(alpha: 0.16),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.32 : 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              onSubmitted: (_) => _search(),
                              style:
                                  TextStyle(color: textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText:
                                    'ابحث عن قطع الغيار، الماركة، الموديل...',
                                hintStyle: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.6),
                                    fontSize: 14),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [_orange, _deepOrange]),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.search_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchCtrl.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          _search();
                                        },
                                        child: Icon(Icons.close_rounded,
                                            color: textSecondary, size: 20),
                                      ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: _showFilters,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            left: 8, right: 8),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _hasActiveFilters()
                                              ? _orange.withValues(alpha: 0.12)
                                              : (isDark
                                                  ? Colors.grey[800]
                                                  : Colors.grey[100]),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.tune_rounded,
                                          color: _hasActiveFilters()
                                              ? _orange
                                              : textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 4),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Vehicle brand filter (Products only) ──
              if (_vehicleBrands.isNotEmpty && _selectedTab == 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: GestureDetector(
                      onTap: _showVehicleBrandPicker,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedBrand != null
                              ? _orange.withValues(alpha: 0.08)
                              : surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedBrand != null
                                ? _orange.withValues(alpha: 0.4)
                                : (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedBrand != null
                                    ? _orange.withValues(alpha: 0.15)
                                    : (isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.directions_car_rounded,
                                  size: 18,
                                  color: _selectedBrand != null
                                      ? _orange
                                      : textSecondary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedBrandName ?? 'اختر ماركة السيارة',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: _selectedBrand != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _selectedBrand != null
                                      ? textPrimary
                                      : textSecondary,
                                ),
                              ),
                            ),
                            if (_selectedBrand != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedBrand = null;
                                    _selectedBrandName = null;
                                  });
                                  _search();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _orange.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close_rounded,
                                      size: 14, color: _orange),
                                ),
                              )
                            else
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  color: textSecondary, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Category chips (Products only) ──
              if (_categories.isNotEmpty && _selectedTab == 0)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return _buildCategoryChip(
                              'الكل',
                              null,
                              Icons.apps_rounded,
                              _selectedCategory == null,
                              isDark,
                              textPrimary);
                        }
                        final c = _categories[i - 1];
                        return _buildCategoryChip(
                            c.nameAr ?? c.name,
                            c.id,
                            _getCategoryIcon(c.name),
                            _selectedCategory == c.id,
                            isDark,
                            textPrimary);
                      },
                    ),
                  ),
                ),

              // ── Results bar with tabs ──
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_orange, _deepOrange],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _orange.withValues(alpha: 0.22),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedTab == 0
                                      ? Icons.inventory_2_outlined
                                      : _selectedTab == 1
                                          ? Icons.people_outline
                                          : Icons.store_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedTab == 0
                                      ? '${_products.length} منتج'
                                      : _selectedTab == 1
                                          ? '${_users.length} حساب'
                                          : '${_stores.length} متجر',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_selectedTab == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sort,
                                  isDense: true,
                                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 18, color: textSecondary),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: textPrimary,
                                      fontWeight: FontWeight.w500),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'newest', child: Text('الأحدث')),
                                    DropdownMenuItem(
                                        value: 'price_asc',
                                        child: Text('الأرخص')),
                                    DropdownMenuItem(
                                        value: 'price_desc',
                                        child: Text('الأغلى')),
                                    DropdownMenuItem(
                                        value: 'popular',
                                        child: Text('الأكثر شعبية')),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _sort = v!);
                                    _search();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Tabs
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          _buildTabButton('المنتجات', 0,
                              Icons.inventory_2_outlined, isDark, textPrimary),
                          _buildTabButton('الحسابات', 1, Icons.people_outline,
                              isDark, textPrimary),
                          _buildTabButton('المتاجر', 2, Icons.store_outlined,
                              isDark, textPrimary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            body: _loading
                ? _buildShimmerGrid(cardBg, isDark)
                : _selectedTab == 0
                    ? (_products.isEmpty
                        ? _buildEmptyState(textSecondary)
                        : _buildProductsView(cardBg, isDark))
                    : _selectedTab == 1
                        ? (_users.isEmpty
                            ? _buildEmptyState(textSecondary)
                            : _buildUsersView(
                                cardBg, isDark, textPrimary, textSecondary))
                        : (_stores.isEmpty
                            ? _buildEmptyState(textSecondary)
                            : _buildStoresView(
                                cardBg, isDark, textPrimary, textSecondary)),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int tabIndex, IconData icon, bool isDark,
      Color textPrimary) {
    final isSelected = _selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedTab = tabIndex;
            _searchCtrl.clear();
            _selectedCategory = null;
            _condition = '';
            _selectedBrand = null;
            _selectedBrandName = null;
          });
          _search();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [_orange, _deepOrange])
                : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF1B2437) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? null
                : Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _orange.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    )
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16, color: isSelected ? Colors.white : _orange),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsView(Color cardBg, bool isDark) {
    return RefreshIndicator(
      color: _orange,
      onRefresh: _search,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.56,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        itemCount: _products.length,
        itemBuilder: (ctx, i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + i * 60),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final safeOpacity = value.clamp(0.0, 1.0).toDouble();
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(opacity: safeOpacity, child: child),
              );
            },
            child: ProductCard(product: _products[i]),
          );
        },
      ),
    );
  }

  Widget _buildUsersView(
      Color cardBg, bool isDark, Color textPrimary, Color textSecondary) {
    return RefreshIndicator(
      color: _orange,
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _users.length,
        itemBuilder: (ctx, i) {
          final user = _users[i];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + i * 60),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _buildUserCard(
                user, cardBg, isDark, textPrimary, textSecondary),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(PublicProfile user, Color cardBg, bool isDark,
      Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: () {
        // Navigate to public profile
        Navigator.of(context).pushNamed('/public-profile', arguments: user.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_orange, _deepOrange]),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.12),
                  width: 2,
                ),
                image: user.avatar != null && user.avatar!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(
                            ApiService.resolveMediaUrl(user.avatar)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: user.avatar == null || user.avatar!.isEmpty
                  ? Center(
                      child: Text(
                        user.firstName.isNotEmpty
                            ? user.firstName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.hasStore) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.storeName ?? 'متجر',
                      style: TextStyle(
                        fontSize: 12,
                        color: _orange,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${user.followersCount} متابع',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Follow button
            GestureDetector(
              onTap: () => _toggleFollowUser(user),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: user.isFollowing
                      ? null
                      : const LinearGradient(colors: [_orange, _deepOrange]),
                  color:
                      user.isFollowing ? _orange.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(10),
                  border: user.isFollowing
                      ? Border.all(color: _orange.withValues(alpha: 0.3))
                      : null,
                ),
                child: Text(
                  user.isFollowing ? 'متابع' : 'متابعة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: user.isFollowing ? _orange : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoresView(
      Color cardBg, bool isDark, Color textPrimary, Color textSecondary) {
    return RefreshIndicator(
      color: _orange,
      onRefresh: _search,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.9,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        itemCount: _stores.length,
        itemBuilder: (ctx, i) {
          final store = _stores[i];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + i * 60),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _buildStoreCard(
                store, cardBg, isDark, textPrimary, textSecondary),
          );
        },
      ),
    );
  }

  Widget _buildStoreCard(Store store, Color cardBg, bool isDark,
      Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: () {
        // Navigate to store details
        Navigator.of(context).pushNamed('/store', arguments: store.id);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF131C2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store logo/image
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: const LinearGradient(
                    colors: [_orange, _deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image: store.logo != null && store.logo!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(
                              ApiService.resolveMediaUrl(store.logo)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: store.logo == null || store.logo!.isEmpty
                    ? Center(
                        child: Text(
                          store.name.isNotEmpty
                              ? store.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 32,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            // Store info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${store.rating.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${store.reviewCount})',
                          style: TextStyle(
                            fontSize: 10,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${store.productCount} منتج',
                      style: TextStyle(
                        fontSize: 10,
                        color: textSecondary,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamed('/store', arguments: store.id);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_orange, _deepOrange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: const Text(
                              'الزيارة',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Future<void> _toggleFollowUser(PublicProfile user) async {
    try {
      if (user.isFollowing) {
        await ApiService.unfollowUser(user.id);
      } else {
        await ApiService.followUser(user.id);
      }

      // Update local state
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        setState(() {
          _users[index] = user.copyWith(
            isFollowing: !user.isFollowing,
            followersCount: user.isFollowing
                ? user.followersCount - 1
                : user.followersCount + 1,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  // ── Category chip builder ──
  Widget _buildCategoryChip(String label, String? id, IconData icon,
      bool selected, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedCategory = id);
          _search();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [_orange, _deepOrange])
                : null,
            color: selected
                ? null
                : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: selected
                ? null
                : Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: _orange.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : _orange),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Active filters badge ──
  Widget _buildActiveFiltersBadge(Color textSecondary) {
    final count = (_selectedCategory != null ? 1 : 0) +
        (_condition.isNotEmpty ? 1 : 0) +
        (_selectedBrand != null ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list_rounded, size: 14, color: _orange),
          const SizedBox(width: 4),
          Text('$count فلتر',
              style: TextStyle(
                  fontSize: 12, color: _orange, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  bool _hasActiveFilters() =>
      _selectedCategory != null ||
      _condition.isNotEmpty ||
      _selectedBrand != null;

  // ── Shimmer loading grid ──
  Widget _buildShimmerGrid(Color cardBg, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.56,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: 6,
      itemBuilder: (_, i) {
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment(
                              -1.0 + 2.0 * _shimmerController.value, 0),
                          end: Alignment(
                              -1.0 + 2.0 * _shimmerController.value + 1, 0),
                          colors: isDark
                              ? [
                                  const Color(0xFF2A2A2A),
                                  const Color(0xFF3A3A3A),
                                  const Color(0xFF2A2A2A)
                                ]
                              : [
                                  Colors.grey[200]!,
                                  Colors.grey[100]!,
                                  Colors.grey[200]!
                                ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(double.infinity, 12, isDark),
                        const SizedBox(height: 8),
                        _shimmerBox(80, 10, isDark),
                        const SizedBox(height: 10),
                        _shimmerBox(60, 14, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shimmerBox(double w, double h, bool isDark) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState(Color textSecondary) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.8 + 0.2 * v, child: child)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 56, color: _orange.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text('لا توجد نتائج',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textSecondary)),
            const SizedBox(height: 8),
            Text('حاول تغيير كلمات البحث أو الفلاتر',
                style: TextStyle(
                    fontSize: 14, color: textSecondary.withValues(alpha: 0.7))),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _selectedCategory = null;
                  _condition = '';
                  _selectedBrand = null;
                  _selectedBrandName = null;
                });
                _search();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة ضبط'),
              style: TextButton.styleFrom(
                foregroundColor: _orange,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category icon helper ──
  IconData _getCategoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('engine') || n.contains('محرك'))
      return Icons.settings_rounded;
    if (n.contains('brake') || n.contains('فرامل'))
      return Icons.disc_full_rounded;
    if (n.contains('filter') || n.contains('فلتر'))
      return Icons.filter_alt_rounded;
    if (n.contains('electric') || n.contains('كهرب')) return Icons.bolt_rounded;
    if (n.contains('body') || n.contains('هيكل'))
      return Icons.directions_car_rounded;
    if (n.contains('oil') || n.contains('زيت')) return Icons.water_drop_rounded;
    if (n.contains('tire') || n.contains('إطار'))
      return Icons.trip_origin_rounded;
    if (n.contains('light') || n.contains('إضاءة'))
      return Icons.lightbulb_rounded;
    return Icons.build_rounded;
  }

  void _showFilters() {
    // Only show filters for products tab
    if (_selectedTab != 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: _orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('الفلاتر',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary)),
                ],
              ),
              const SizedBox(height: 24),
              Text('حالة المنتج',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFilterOption(
                      'الكل', '', Icons.all_inclusive_rounded, isDark),
                  const SizedBox(width: 10),
                  _buildFilterOption(
                      'جديد', 'new', Icons.fiber_new_rounded, isDark),
                  const SizedBox(width: 10),
                  _buildFilterOption(
                      'مستعمل', 'used', Icons.recycling_rounded, isDark),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _condition = '';
                      _selectedCategory = null;
                      _selectedBrand = null;
                      _selectedBrandName = null;
                      _searchCtrl.clear();
                    });
                    Navigator.pop(ctx);
                    _search();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('مسح جميع الفلاتر',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                    foregroundColor: textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(
      String label, String value, IconData icon, bool isDark) {
    final selected = _condition == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _condition = value);
          Navigator.pop(context);
          _search();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [_orange, _deepOrange])
                : null,
            color: selected
                ? null
                : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[50]),
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? null
                : Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : _orange, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  void _showVehicleBrandPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.55,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_car_rounded,
                        color: _orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('اختر ماركة السيارة',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _vehicleBrands.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? Colors.grey[800] : Colors.grey[100]),
                  itemBuilder: (_, i) {
                    final brand = _vehicleBrands[i];
                    final id = brand['id']?.toString();
                    final name = brand['name']?.toString() ?? '';
                    final selected = _selectedBrand == id;
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: selected
                          ? _orange.withValues(alpha: 0.10)
                          : Colors.transparent,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: selected
                            ? _orange.withValues(alpha: 0.2)
                            : (isDark ? Colors.grey[800] : Colors.grey[100]),
                        child: Icon(Icons.directions_car_filled_rounded,
                            size: 16, color: selected ? _orange : Colors.grey),
                      ),
                      title: Text(name,
                          style: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 14,
                              color: textPrimary)),
                      trailing: selected
                          ? Icon(Icons.check_circle_rounded,
                              color: _orange, size: 20)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedBrand = id;
                          _selectedBrandName = name;
                        });
                        Navigator.pop(ctx);
                        _search();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _shimmerController.dispose();
    _fabController.dispose();
    super.dispose();
  }
}
