import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CreateStoreScreen extends StatefulWidget {
  final bool replaceExisting;

  const CreateStoreScreen({super.key, this.replaceExisting = false});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _selectedWilaya;
  String _activityType = 'car_parts';
  File? _logoFile;
  bool _loading = false;
  List<dynamic> _wilayas = [];

  final _activityTypes = {
    'car_parts': 'قطع غيار السيارات',
    'truck_parts': 'قطع غيار الشاحنات',
    'motorcycle_parts': 'قطع غيار الدراجات',
    'all_parts': 'جميع قطع الغيار',
  };

  @override
  void initState() {
    super.initState();
    _loadWilayas();
  }

  Future<void> _loadWilayas() async {
    try {
      final res = await ApiService.getWilayas();
      setState(() => _wilayas = res['data'] ?? res['wilayas'] ?? []);
    } catch (_) {}
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (img != null) setState(() => _logoFile = File(img.path));
  }

  Future<void> _submit({bool forceReplace = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'activity_type': _activityType,
      };
      if (widget.replaceExisting || forceReplace) {
        data['replace_existing'] = true;
      }
      if (_selectedWilaya != null) data['wilaya'] = _selectedWilaya!;
      if (_logoFile != null) data['logo_path'] = _logoFile!.path;

      await ApiService.createStore(data);
      await context.read<AuthProvider>().refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إنشاء المتجر بنجاح! 🎉'),
              backgroundColor: Colors.green),
        );
        Navigator.pushReplacementNamed(context, '/seller-dashboard');
      }
    } catch (e) {
      final rawError = e.toString().toLowerCase();
      final alreadyHasStore =
          rawError.contains('already have a store') || rawError.contains('409');

      if (alreadyHasStore &&
          mounted &&
          !forceReplace &&
          !widget.replaceExisting) {
        final confirmReplace = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('استبدال المتجر الحالي؟'),
            content: const Text(
              'لديك متجر نشط بالفعل. هل تريد استبداله بمتجر جديد؟\nسيتم تعطيل المتجر القديم وإخفاؤه من التطبيق.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('استبدال'),
              ),
            ],
          ),
        );

        if (confirmReplace == true) {
          await _submit(forceReplace: true);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final scaffoldBg = isDark ? const Color(0xFF0B1220) : Colors.grey[50]!;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('إنشاء متجرك'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.store, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text('ابدأ رحلتك كبائع',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('أنشئ متجرك وابدأ ببيع قطع الغيار',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14)),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFF97316), width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10)
                            ],
                            image: _logoFile != null
                                ? DecorationImage(
                                    image: FileImage(_logoFile!),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: _logoFile == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: Color(0xFFF97316), size: 30),
                                    SizedBox(height: 4),
                                    Text('شعار المتجر',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFF97316))),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    _sectionTitle('معلومات المتجر'),
                    const SizedBox(height: 12),
                    _buildInput('اسم المتجر *', _nameCtrl, Icons.store_outlined,
                        validator: (v) => v == null || v.trim().length < 3
                            ? 'أدخل اسم المتجر (3 أحرف على الأقل)'
                            : null),
                    _buildInput(
                        'وصف المتجر', _descCtrl, Icons.description_outlined,
                        maxLines: 3),

                    _sectionTitle('نوع النشاط'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8)
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _activityType,
                        items: _activityTypes.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _activityType = v!),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.category_outlined,
                              color: Color(0xFFF97316)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          filled: true,
                          fillColor: surface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle('معلومات الاتصال'),
                    const SizedBox(height: 12),
                    _buildInput(
                        'رقم الهاتف *', _phoneCtrl, Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().length < 9
                            ? 'أدخل رقم هاتف صحيح'
                            : null),
                    _buildInput(
                        'العنوان *', _addressCtrl, Icons.location_on_outlined,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'أدخل العنوان'
                            : null),

                    // Wilaya dropdown
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8)
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedWilaya,
                        hint: const Text('اختر الولاية'),
                        isExpanded: true,
                        items: _wilayas.map<DropdownMenuItem<String>>((w) {
                          final name = w is Map
                              ? (w['name'] ?? w['name_ar'] ?? '').toString()
                              : w.toString();
                          return DropdownMenuItem(
                              value: name, child: Text(name));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedWilaya = v),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.map_outlined,
                              color: Color(0xFFF97316)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          filled: true,
                          fillColor: surface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.rocket_launch, size: 22),
                                  SizedBox(width: 10),
                                  Text('إنشاء المتجر',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151))),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      String? Function(String?)? validator}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFFF97316)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }
}
