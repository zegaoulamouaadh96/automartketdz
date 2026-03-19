import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
  // ── Form ──
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _oldPriceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _skuCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _oemCtrl = TextEditingController();

  String _condition = 'new';
  String? _selectedCategory;
  String? _selectedBrand;
  String? _selectedModel;

  List<dynamic> _categories = [];
  List<dynamic> _brands = [];
  List<dynamic> _models = [];
  List<File> _images = [];
  bool _loading = false;

  // ── Stepper ──
  int _currentStep = 0;
  final int _totalSteps = 4;
  late final PageController _pageCtrl;

  // ── Animations ──
  late final AnimationController _headerAnim;
  late final AnimationController _staggerAnim;
  late final AnimationController _pulseAnim;
  late final AnimationController _submitAnim;
  late final Animation<double> _headerSlide;
  late final Animation<double> _headerFade;
  late final Animation<double> _pulseScale;

  static const _orange = Color(0xFFF97316);
  static const _deepOrange = Color(0xFFEA580C);
  static const _bg = Color(0xFFF8FAFC);
  static const _cardBg = Colors.white;
  static const _dark = Color(0xFF1E293B);
  static const _grey = Color(0xFF64748B);

  final _stepIcons = [
    Icons.photo_library_rounded,
    Icons.edit_note_rounded,
    Icons.payments_rounded,
    Icons.directions_car_filled_rounded,
  ];
  final _stepLabels = ['الصور', 'التفاصيل', 'التسعير', 'التوافق'];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _staggerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _submitAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _headerSlide = Tween<double>(begin: -40, end: 0).animate(
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));
    _headerFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut));
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));

    _headerAnim.forward();
    _staggerAnim.forward();
    _loadDropdowns();

    _priceCtrl.addListener(_onPriceChange);
    _oldPriceCtrl.addListener(_onPriceChange);
  }

  void _onPriceChange() => setState(() {});

  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getBrands(),
      ]);
      setState(() {
        _categories = results[0]['data'] ?? results[0]['categories'] ?? [];
        _brands = results[1]['data'] ?? results[1]['brands'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadModels(String brandId) async {
    try {
      final res = await ApiService.getVehicleModels(brandId);
      setState(() => _models = res['data'] ?? res['models'] ?? []);
    } catch (_) {}
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickMultiImage(maxWidth: 1024, imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.map((x) => File(x.path)));
        if (_images.length > 6) _images = _images.sublist(0, 6);
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null && _images.length < 6) {
      setState(() => _images.add(File(picked.path)));
    }
  }

  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    setState(() => _currentStep = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic);
    _staggerAnim.reset();
    _staggerAnim.forward();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_images.isEmpty) {
          _showSnack('أضف صورة واحدة على الأقل للمنتج', Icons.photo_camera,
              Colors.orange);
          return false;
        }
        return true;
      case 1:
        if (_nameCtrl.text.trim().length < 3) {
          _showSnack('أدخل اسم المنتج (3 أحرف على الأقل)', Icons.text_fields,
              Colors.orange);
          return false;
        }
        return true;
      case 2:
        if (_priceCtrl.text.isEmpty ||
            (double.tryParse(_priceCtrl.text) ?? 0) <= 0) {
          _showSnack('أدخل سعر صحيح للمنتج', Icons.money_off, Colors.orange);
          return false;
        }
        if (_quantityCtrl.text.isEmpty) {
          _showSnack('أدخل الكمية المتوفرة', Icons.inventory, Colors.orange);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showSnack(String msg, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      _showSnack('أضف صورة واحدة على الأقل', Icons.photo_camera, Colors.orange);
      return;
    }

    setState(() => _loading = true);
    _submitAnim.forward();
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'quantity': _quantityCtrl.text.trim(),
        'condition': _condition,
        'images_paths': _images.map((f) => f.path).toList(),
      };

      if (_oldPriceCtrl.text.isNotEmpty) {
        data['original_price'] = _oldPriceCtrl.text.trim();
      }
      if (_selectedCategory != null) data['category_id'] = _selectedCategory!;
      if (_skuCtrl.text.isNotEmpty) data['sku'] = _skuCtrl.text.trim();
      if (_warrantyCtrl.text.isNotEmpty) {
        data['warranty'] = _warrantyCtrl.text.trim();
      }

      if (_selectedBrand != null || _selectedModel != null) {
        final fitment = <String, dynamic>{};
        if (_selectedBrand != null) fitment['brand_id'] = _selectedBrand;
        if (_selectedModel != null) fitment['model_id'] = _selectedModel;
        data['fitments'] = [fitment];
      }

      if (_oemCtrl.text.isNotEmpty) {
        data['oem_numbers'] = _oemCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => {'number': s})
            .toList();
      }

      await ApiService.createProduct(data);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('$e', Icons.error_outline, Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _submitAnim.reset();
      }
    }
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (ctx, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.elasticOut),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                      color: _orange.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_orange, Color(0xFFFBBF24)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _orange.withValues(alpha: 0.4),
                            blurRadius: 20),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 45),
                  ),
                  const SizedBox(height: 20),
                  const Text('تم بنجاح! 🎉',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _dark)),
                  const SizedBox(height: 10),
                  Text('تم إضافة منتجك وسيكون متاحاً للعملاء قريباً',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('حسناً',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double get _discountPercent {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final old = double.tryParse(_oldPriceCtrl.text) ?? 0;
    if (old > price && price > 0) return ((old - price) / old * 100);
    return 0;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildHeader(),
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStep0_Images(),
                  _buildStep1_Details(),
                  _buildStep2_Pricing(),
                  _buildStep3_Vehicle(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _headerSlide.value),
        child: Opacity(
          opacity: _headerFade.value,
          child: Container(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 16,
                left: 20,
                right: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_orange, _deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: _orange.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إضافة منتج جديد',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('الخطوة ${_currentStep + 1} من $_totalSteps',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_images.length}/6 صور',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step Indicator ──
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final active = i == _currentStep;
          final done = i < _currentStep;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (i < _currentStep) _goToStep(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: active
                      ? _orange.withValues(alpha: 0.12)
                      : done
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? _orange
                        : done
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.transparent,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: active ? 36 : 30,
                      height: active ? 36 : 30,
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [_orange, _deepOrange])
                            : done
                                ? const LinearGradient(colors: [
                                    Color(0xFF22C55E),
                                    Color(0xFF16A34A)
                                  ])
                                : null,
                        color: (!active && !done) ? Colors.grey[300] : null,
                        shape: BoxShape.circle,
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: _orange.withValues(alpha: 0.4),
                                    blurRadius: 10),
                              ]
                            : null,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : _stepIcons[i],
                        color:
                            (active || done) ? Colors.white : Colors.grey[500],
                        size: active ? 20 : 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stepLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        color: active
                            ? _orange
                            : done
                                ? Colors.green[700]
                                : _grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Bottom Navigation Bar ──
  Widget _buildBottomBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: _AnimatedButton(
                onTap: () => _goToStep(_currentStep - 1),
                color: Colors.grey[100]!,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded,
                        size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text('السابق',
                        style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: _AnimatedButton(
              onTap: _loading
                  ? null
                  : isLast
                      ? _submit
                      : () {
                          if (_validateCurrentStep()) {
                            _goToStep(_currentStep + 1);
                          }
                        },
              gradient: const LinearGradient(colors: [_orange, _deepOrange]),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLast
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(isLast ? 'نشر المنتج' : 'التالي',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STEP 0 — Images
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStep0_Images() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _animatedEntry(
              0,
              _buildSectionCard(
                icon: Icons.photo_library_rounded,
                title: 'صور المنتج',
                subtitle: 'أضف حتى 6 صور عالية الجودة (${_images.length}/6)',
                required: true,
                child: Column(
                  children: [
                    // Main image area
                    if (_images.isEmpty)
                      _buildEmptyImageArea()
                    else
                      _buildImageGrid(),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildImagePickerBtn(
                            icon: Icons.photo_library_rounded,
                            label: 'من المعرض',
                            onTap: _pickImages,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildImagePickerBtn(
                            icon: Icons.camera_alt_rounded,
                            label: 'الكاميرا',
                            onTap: _pickFromCamera,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              1,
              _buildTipCard(
                'نصائح لصور أفضل',
                [
                  'استخدم إضاءة طبيعية جيدة',
                  'التقط الصور من زوايا متعددة',
                  'أظهر تفاصيل المنتج والعلامات التجارية',
                  'الصورة الأولى هي الرئيسية للعرض',
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyImageArea() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: _images.isEmpty ? _pulseScale.value : 1.0,
        child: GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _orange.withValues(alpha: 0.4),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside),
              color: _orange.withValues(alpha: 0.04),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_rounded,
                      size: 40, color: _orange),
                ),
                const SizedBox(height: 14),
                const Text('اضغط لإضافة صور المنتج',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                const SizedBox(height: 4),
                Text('PNG, JPG حتى 6 صور',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return SizedBox(
      height: 120,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + (_images.length < 6 ? 1 : 0),
        onReorder: (oldIndex, newIndex) {
          if (oldIndex >= _images.length || newIndex > _images.length) return;
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _images.removeAt(oldIndex);
            _images.insert(newIndex, item);
          });
        },
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
          );
        },
        itemBuilder: (ctx, idx) {
          if (idx == _images.length) {
            return SizedBox(
              key: const ValueKey('add_btn'),
              width: 100,
              child: _buildMiniAddBtn(),
            );
          }
          return Container(
            key: ValueKey('img_$idx'),
            width: 110,
            margin: const EdgeInsets.only(left: 10),
            child: _buildImageCard(idx, _images[idx]),
          );
        },
      ),
    );
  }

  Widget _buildImageCard(int idx, File file) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: idx == 0 ? _orange : Colors.grey[200]!,
              width: idx == 0 ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: (idx == 0 ? _orange : Colors.black)
                      .withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file, width: 110, height: 120, fit: BoxFit.cover),
          ),
        ),
        if (idx == 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_orange, _deepOrange],
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text('رئيسية',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(idx)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red[400],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4), blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniAddBtn() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _orange.withValues(alpha: 0.3)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: _orange, size: 28),
            SizedBox(height: 4),
            Text('إضافة',
                style: TextStyle(
                    fontSize: 11, color: _orange, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Material(
      color: _orange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _orange, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STEP 1 — Details
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStep1_Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _animatedEntry(
              0,
              _buildSectionCard(
                icon: Icons.edit_note_rounded,
                title: 'المعلومات الأساسية',
                subtitle: 'أدخل تفاصيل المنتج الأساسية',
                required: true,
                child: Column(
                  children: [
                    _buildModernInput(
                      label: 'اسم المنتج',
                      hint: 'مثال: فلتر زيت تويوتا كامري 2020',
                      controller: _nameCtrl,
                      icon: Icons.inventory_2_rounded,
                      required: true,
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'أدخل اسم المنتج (3 أحرف على الأقل)'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _buildModernInput(
                      label: 'وصف المنتج',
                      hint:
                          'اكتب وصفاً تفصيلياً يساعد المشتري على فهم المنتج...',
                      controller: _descCtrl,
                      icon: Icons.description_rounded,
                      maxLines: 5,
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              1,
              _buildSectionCard(
                icon: Icons.category_rounded,
                title: 'التصنيف',
                subtitle: 'اختر تصنيف المنتج لسهولة البحث',
                child: _buildModernDropdown<String>(
                  label: 'اختر الصنف',
                  value: _selectedCategory,
                  icon: Icons.category_rounded,
                  items: _categories.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['name_ar'] ?? c['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              2,
              _buildSectionCard(
                icon: Icons.new_releases_rounded,
                title: 'حالة المنتج',
                subtitle: 'حدد حالة المنتج',
                child: _buildConditionSelector(),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              3,
              _buildSectionCard(
                icon: Icons.verified_user_rounded,
                title: 'الضمان',
                subtitle: 'أضف معلومات الضمان (اختياري)',
                child: _buildModernInput(
                  label: 'معلومات الضمان',
                  hint: 'مثال: ضمان سنة كاملة',
                  controller: _warrantyCtrl,
                  icon: Icons.shield_rounded,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildConditionSelector() {
    final conditions = [
      {
        'value': 'new',
        'label': 'جديد',
        'icon': Icons.fiber_new_rounded,
        'color': const Color(0xFF22C55E)
      },
      {
        'value': 'used',
        'label': 'مستعمل',
        'icon': Icons.recycling_rounded,
        'color': const Color(0xFF3B82F6)
      },
      {
        'value': 'refurbished',
        'label': 'مُجدّد',
        'icon': Icons.autorenew_rounded,
        'color': const Color(0xFF8B5CF6)
      },
    ];

    return Row(
      children: conditions.map((c) {
        final sel = _condition == c['value'];
        final color = c['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _condition = c['value'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: sel
                    ? LinearGradient(
                        colors: [color, color.withValues(alpha: 0.8)])
                    : null,
                color: sel ? null : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel ? color : Colors.grey[200]!,
                  width: sel ? 0 : 1.5,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(c['icon'] as IconData,
                      size: 26, color: sel ? Colors.white : Colors.grey[500]),
                  const SizedBox(height: 6),
                  Text(c['label'] as String,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.grey[700],
                        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STEP 2 — Pricing
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStep2_Pricing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _animatedEntry(
              0,
              _buildSectionCard(
                icon: Icons.payments_rounded,
                title: 'التسعير',
                subtitle: 'حدد سعر البيع والسعر الأصلي',
                required: true,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernInput(
                            label: 'السعر (د.ج)',
                            hint: '0.00',
                            controller: _priceCtrl,
                            icon: Icons.monetization_on_rounded,
                            required: true,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'أدخل السعر';
                              if (double.tryParse(v) == null ||
                                  double.parse(v) <= 0) {
                                return 'سعر غير صحيح';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernInput(
                            label: 'السعر القديم',
                            hint: 'اختياري',
                            controller: _oldPriceCtrl,
                            icon: Icons.money_off_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    if (_discountPercent > 0) ...[
                      const SizedBox(height: 12),
                      _buildDiscountPreview(),
                    ],
                  ],
                ),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              1,
              _buildSectionCard(
                icon: Icons.inventory_rounded,
                title: 'المخزون',
                subtitle: 'حدد الكمية المتاحة ومعرّف القطعة',
                required: true,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModernInput(
                        label: 'الكمية',
                        hint: '1',
                        controller: _quantityCtrl,
                        icon: Icons.numbers_rounded,
                        required: true,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'أدخل الكمية' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernInput(
                        label: 'رقم SKU',
                        hint: 'اختياري',
                        controller: _skuCtrl,
                        icon: Icons.qr_code_rounded,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              2,
              _buildTipCard(
                'نصائح للتسعير',
                [
                  'ابحث عن أسعار المنافسين قبل التسعير',
                  'إضافة السعر القديم يُظهر الخصم للمشترين',
                  'السعر المناسب يزيد من المبيعات',
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildDiscountPreview() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.08),
            Colors.green.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_rounded,
                color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('خصم سيظهر للمشترين',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('-${_discountPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_oldPriceCtrl.text} د.ج',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      decoration: TextDecoration.lineThrough)),
              Text('${_priceCtrl.text} د.ج',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: _dark)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STEP 3 — Vehicle
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStep3_Vehicle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _animatedEntry(
              0,
              _buildSectionCard(
                icon: Icons.directions_car_filled_rounded,
                title: 'توافق المركبة',
                subtitle: 'حدد المركبات المتوافقة مع هذا المنتج',
                child: Column(
                  children: [
                    _buildModernDropdown<String>(
                      label: 'اختر الماركة',
                      value: _selectedBrand,
                      icon: Icons.car_repair_rounded,
                      items: _brands.map<DropdownMenuItem<String>>((b) {
                        return DropdownMenuItem(
                          value: b['id'].toString(),
                          child: Text(b['name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedBrand = v;
                          _selectedModel = null;
                          _models = [];
                        });
                        if (v != null) _loadModels(v);
                      },
                    ),
                    if (_models.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildModernDropdown<String>(
                        label: 'اختر الموديل',
                        value: _selectedModel,
                        icon: Icons.model_training_rounded,
                        items: _models.map<DropdownMenuItem<String>>((m) {
                          return DropdownMenuItem(
                            value: m['id'].toString(),
                            child: Text(m['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedModel = v),
                      ),
                    ],
                  ],
                ),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              1,
              _buildSectionCard(
                icon: Icons.pin_rounded,
                title: 'أرقام OEM',
                subtitle: 'أضف أرقام القطعة الأصلية (اختياري)',
                child: _buildModernInput(
                  label: 'أرقام OEM',
                  hint: 'مثال: 90915-YZZD1, 04152-YZZA1',
                  controller: _oemCtrl,
                  icon: Icons.tag_rounded,
                ),
              )),
          const SizedBox(height: 16),
          _animatedEntry(
              2,
              _buildTipCard(
                'لماذا توافق المركبة مهم؟',
                [
                  'يساعد المشترين في إيجاد المنتج بسهولة',
                  'أرقام OEM تزيد من ثقة المشتري',
                  'يقلل من طلبات الإرجاع',
                ],
              )),
          const SizedBox(height: 16),
          _animatedEntry(3, _buildProductPreview()),
        ],
      ),
    );
  }

  Widget _buildProductPreview() {
    if (_images.isEmpty && _nameCtrl.text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _orange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: _orange.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.preview_rounded, color: _orange, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('معاينة المنتج',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: _dark)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_images.first,
                      width: 70, height: 70, fit: BoxFit.cover),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.isEmpty ? 'اسم المنتج' : _nameCtrl.text,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _dark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (_priceCtrl.text.isNotEmpty)
                      Row(
                        children: [
                          Text('${_priceCtrl.text} د.ج',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _orange)),
                          if (_discountPercent > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                  '-${_discountPercent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      color: Colors.red[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle,
                            size: 8,
                            color: _condition == 'new'
                                ? Colors.green
                                : Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          _condition == 'new'
                              ? 'جديد'
                              : _condition == 'used'
                                  ? 'مستعمل'
                                  : 'مجدد',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    bool required = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5)),
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
                  gradient:
                      const LinearGradient(colors: [_orange, _deepOrange]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: _orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _dark)),
                        if (required) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('مطلوب',
                                style: TextStyle(
                                    color: Colors.red[400],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: _dark),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        labelStyle: const TextStyle(color: _grey, fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _orange, size: 18),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildModernDropdown<T>({
    required String label,
    required T? value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      hint:
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _orange),
      decoration: InputDecoration(
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _orange, size: 18),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _orange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildTipCard(String title, List<String> tips) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: 0.06),
            const Color(0xFF3B82F6).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E40AF))),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(t,
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Staggered Animation Helper ──
  Widget _animatedEntry(int index, Widget child) {
    final begin = (index * 0.15).clamp(0.0, 0.7);
    final end = (begin + 0.4).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _staggerAnim,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final safeOpacity = anim.value.clamp(0.0, 1.0).toDouble();
        return Transform.translate(
          offset: Offset(0, 30 * (1 - anim.value)),
          child: Opacity(opacity: safeOpacity, child: child),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _oldPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _skuCtrl.dispose();
    _warrantyCtrl.dispose();
    _oemCtrl.dispose();
    _pageCtrl.dispose();
    _headerAnim.dispose();
    _staggerAnim.dispose();
    _pulseAnim.dispose();
    _submitAnim.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Animated Button Widget
// ═══════════════════════════════════════════════════════════════════
class _AnimatedButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final Gradient? gradient;
  final Color? color;

  const _AnimatedButton(
      {this.onTap, required this.child, this.gradient, this.color});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              color: widget.color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.gradient != null
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF97316).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
