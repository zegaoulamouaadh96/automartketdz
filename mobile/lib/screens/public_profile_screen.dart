import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  PublicProfile? _profile;
  bool _isFollowing = false;
  bool _loadingFollow = false;

  static const _orange = Color(0xFFF97316);
  static const _deepOrange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _profileFuture = ApiService.getPublicUserProfile(widget.userId);
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;

    setState(() => _loadingFollow = true);
    try {
      if (_profile!.isFollowing) {
        await ApiService.unfollowUser(_profile!.id);
      } else {
        await ApiService.followUser(_profile!.id);
      }

      setState(() {
        _profile = _profile!.copyWith(
          isFollowing: !_profile!.isFollowing,
          followersCount: _profile!.isFollowing
              ? _profile!.followersCount - 1
              : _profile!.followersCount + 1,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      setState(() => _loadingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'الملف الشخصي',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: _orange),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'فشل تحميل الملف الشخصي',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            try {
              final data = snapshot.data!['data'] ?? snapshot.data!;
              _profile = PublicProfile.fromJson(data);
              _isFollowing = _profile!.isFollowing;
            } catch (e) {
              return Center(
                child: Text('خطأ في تحليل البيانات: $e'),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Header with avatar
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_orange, _deepOrange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 3,
                            ),
                            image: _profile!.avatar != null &&
                                    _profile!.avatar!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                      ApiService.resolveMediaUrl(
                                          _profile!.avatar),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profile!.avatar == null ||
                                  _profile!.avatar!.isEmpty
                              ? Center(
                                  child: Text(
                                    _profile!.firstName.isNotEmpty
                                        ? _profile!.firstName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 40,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Name
                        Text(
                          _profile!.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_profile!.wilaya != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _profile!.wilaya!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Stats section
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'المتابعون',
                          _profile!.followersCount.toString(),
                          Icons.people_outline,
                          textPrimary,
                          textSecondary,
                        ),
                        _buildStatDivider(isDark),
                        _buildStatItem(
                          'يتابع',
                          _profile!.followingCount.toString(),
                          Icons.person_add_outlined,
                          textPrimary,
                          textSecondary,
                        ),
                      ],
                    ),
                  ),

                  // Store section (if applicable)
                  if (_profile!.hasStore) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed('/store',
                              arguments: _profile!.storeId);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المتجر',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Store logo
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: const LinearGradient(
                                        colors: [_orange, _deepOrange],
                                      ),
                                      image: _profile!.storeLogo != null &&
                                              _profile!.storeLogo!.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                ApiService.resolveMediaUrl(
                                                    _profile!.storeLogo),
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _profile!.storeLogo == null ||
                                            _profile!.storeLogo!.isEmpty
                                        ? Center(
                                            child: Text(
                                              _profile!.storeName!.isNotEmpty
                                                  ? _profile!.storeName![0]
                                                      .toUpperCase()
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _profile!.storeName ?? 'متجر',
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.star_rounded,
                                                size: 14, color: Colors.amber),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${_profile!.storeRating.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${_profile!.storeReviewCount})',
                                              style: TextStyle(
                                                color: textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_profile!.storeProductCount} منتج',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 16),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Action buttons
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 24, 16, 30),
                    child: Column(
                      children: [
                        // Follow button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loadingFollow ? null : _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _profile!.isFollowing
                                  ? _orange.withValues(alpha: 0.1)
                                  : _orange,
                              foregroundColor: _profile!.isFollowing
                                  ? _orange
                                  : Colors.white,
                              elevation: _profile!.isFollowing ? 0 : 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: _profile!.isFollowing
                                    ? BorderSide(
                                        color: _orange.withValues(alpha: 0.3))
                                    : BorderSide.none,
                              ),
                            ),
                            child: _loadingFollow
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        _profile!.isFollowing
                                            ? _orange
                                            : Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _profile!.isFollowing
                                        ? 'متابع بالفعل'
                                        : 'متابعة',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Message button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement messaging
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('الرسائل قريباً...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.mail_outline_rounded),
                            label: const Text('إرسال رسالة'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _orange.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Icon(icon, color: _orange, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 50,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
    );
  }
}
