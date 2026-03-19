import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _wilayaCtrl;
  bool _editing = false;
  bool _avatarBusy = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _orange = Color(0xFFF97316);
  static const _deepOrange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: user?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _wilayaCtrl = TextEditingController(text: user?.wilaya ?? '');

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _wilayaCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    try {
      await auth.updateProfile({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'wilaya': _wilayaCtrl.text.trim(),
      });
      setState(() => _editing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('تم تحديث البيانات بنجاح'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickAvatar() async {
    if (_avatarBusy) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() => _avatarBusy = true);
    try {
      await ApiService.uploadProfileAvatar(image.path);
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الصورة الشخصية'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _avatarBusy = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    if (_avatarBusy) return;

    setState(() => _avatarBusy = true);
    try {
      await ApiService.removeProfileAvatar();
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الصورة الشخصية'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _avatarBusy = false);
      }
    }
  }

  String _getRoleLabel(String role) {
    if (role == 'admin') return 'مدير النظام';
    if (role == 'seller') return 'بائع';
    return 'مشتري';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle:
                isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            title: Text('الملف الشخصي',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded,
                  size: 80, color: textSecondary.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('يجب تسجيل الدخول أولاً',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('للوصول إلى ملفك الشخصي وإدارته',
                  style: TextStyle(color: textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('تسجيل الدخول'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final user = auth.user!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Text('الملف الشخصي',
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded,
                color: textPrimary),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _editing = !_editing);
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                //  Avatar & Header
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) {
                    final safeOpacity = v.clamp(0.0, 1.0).toDouble();
                    return Transform.scale(
                      scale: 0.8 + 0.2 * v,
                      child: Opacity(opacity: safeOpacity, child: child),
                    );
                  },
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _orange.withOpacity(0.3), width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: _orange.withOpacity(0.15),
                              backgroundImage: user.avatar != null &&
                                      user.avatar!.isNotEmpty
                                  ? NetworkImage(
                                      ApiService.resolveMediaUrl(user.avatar),
                                    )
                                  : null,
                              child: user.avatar == null || user.avatar!.isEmpty
                                  ? const Icon(Icons.person_rounded,
                                      size: 50, color: _orange)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: GestureDetector(
                              onTap: _pickAvatar,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardBg, width: 2),
                                ),
                                child: _avatarBusy
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.camera_alt_rounded,
                                        size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (user.avatar != null && user.avatar!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _avatarBusy ? null : _removeAvatar,
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 18),
                          label: const Text('حذف الصورة',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ] else
                        const SizedBox(height: 12),
                      const SizedBox(height: 8),
                      Text('${user.firstName} ${user.lastName}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: textPrimary)),
                      const SizedBox(height: 4),
                      Text(user.email,
                          style: TextStyle(color: textSecondary, fontSize: 15)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getRoleLabel(user.role),
                          style: const TextStyle(
                              color: _orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                //  Form Fields
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildField('الاسم الأول', _firstNameCtrl,
                          Icons.person_outline_rounded, isDark, textSecondary),
                      const SizedBox(height: 16),
                      _buildField('اللقب', _lastNameCtrl,
                          Icons.person_outline_rounded, isDark, textSecondary),
                      const SizedBox(height: 16),
                      _buildField('رقم الهاتف', _phoneCtrl,
                          Icons.phone_outlined, isDark, textSecondary,
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      _buildField('الولاية', _wilayaCtrl,
                          Icons.location_on_outlined, isDark, textSecondary),
                      if (_editing) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('حفظ التعديلات',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                //  Seller Section
                if (user.role == 'seller' || user.role == 'admin')
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/seller-dashboard');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_orange, _deepOrange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: _orange.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.dashboard_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('لوحة تحكم المتجر',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                                const SizedBox(height: 4),
                                Text('إدارة منتجاتك وطلباتك وإحصائياتك',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/create-store');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: _orange.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.store_rounded,
                                color: _orange, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('افتح متجرك الآن',
                                    style: TextStyle(
                                        color: _orange,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                                const SizedBox(height: 4),
                                Text('ابدأ ببيع قطع الغيار لآلاف العملاء',
                                    style: TextStyle(
                                        color: textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: _orange, size: 18),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                //  Settings & Actions
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildActionTile(
                        icon: Icons.receipt_long_rounded,
                        title: 'طلباتي',
                        color: textPrimary,
                        isDark: isDark,
                        onTap: () => Navigator.pushNamed(context, '/orders'),
                      ),
                      Divider(
                          height: 1,
                          indent: 60,
                          color: isDark ? Colors.grey[800] : Colors.grey[100]),
                      _buildActionTile(
                        icon: Icons.shopping_cart_outlined,
                        title: 'سلة المشتريات',
                        color: textPrimary,
                        isDark: isDark,
                        onTap: () => Navigator.pushNamed(context, '/cart'),
                      ),
                      Divider(
                          height: 1,
                          indent: 60,
                          color: isDark ? Colors.grey[800] : Colors.grey[100]),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            themeProvider.isDarkMode
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: textPrimary,
                            size: 20,
                          ),
                        ),
                        title: Text('الوضع الداكن',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        trailing: Switch.adaptive(
                          value: themeProvider.isDarkMode,
                          activeColor: _orange,
                          onChanged: (_) {
                            HapticFeedback.selectionClick();
                            context.read<ThemeProvider>().toggleDarkMode();
                          },
                        ),
                      ),
                      Divider(
                          height: 1,
                          indent: 60,
                          color: isDark ? Colors.grey[800] : Colors.grey[100]),
                      _buildActionTile(
                        icon: Icons.logout_rounded,
                        title: 'تسجيل الخروج',
                        color: Colors.redAccent,
                        isDark: isDark,
                        hideChevron: true,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await auth.logout();
                          if (mounted) {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      bool isDark, Color textSecondary,
      {TextInputType keyboardType = TextInputType.text}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: TextFormField(
        controller: ctrl,
        enabled: _editing,
        keyboardType: keyboardType,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textSecondary),
          prefixIcon: Icon(icon, color: _editing ? _orange : textSecondary),
          filled: true,
          fillColor: _editing
              ? (isDark ? Colors.grey[800] : Colors.grey[50])
              : Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _orange, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
      {required IconData icon,
      required String title,
      required Color color,
      required bool isDark,
      required VoidCallback onTap,
      bool hideChevron = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color == Colors.redAccent
              ? Colors.redAccent.withOpacity(0.1)
              : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: hideChevron
          ? null
          : Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: Colors.grey[500]),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
