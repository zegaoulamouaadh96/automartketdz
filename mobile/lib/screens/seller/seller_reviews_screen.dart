import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key});

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  List<dynamic> _reviews = [];
  bool _loading = true;
  Store? _store;
  double _avgRating = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final storeRes = await ApiService.getMyStore();
      final storeData = storeRes['data'] ?? storeRes['store'] ?? storeRes;
      _store = Store.fromJson(storeData);

      final reviewsRes = await ApiService.getStoreReviews(_store!.id);
      setState(() {
        _reviews = reviewsRes['data'] ?? reviewsRes['reviews'] ?? [];
        _avgRating = _store?.rating ?? 0;
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
        title: const Text('التقييمات'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Rating summary
                  _buildRatingSummary(),
                  const SizedBox(height: 20),

                  // Reviews list
                  if (_reviews.isEmpty)
                    _buildEmpty()
                  else
                    ..._reviews.map((r) => _reviewCard(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildRatingSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          // Big rating number
          Column(
            children: [
              Text(_avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < _avgRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        )),
              ),
              const SizedBox(height: 6),
              Text('${_reviews.length} تقييم',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13)),
            ],
          ),
          const SizedBox(width: 30),
          // Rating bars
          Expanded(child: _buildRatingBars()),
        ],
      ),
    );
  }

  Widget _buildRatingBars() {
    final counts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final rating = (r['rating'] ?? 0) as int;
      if (counts.containsKey(rating)) counts[rating] = counts[rating]! + 1;
    }
    final total = _reviews.length.clamp(1, double.infinity);

    return Column(
      children: [5, 4, 3, 2, 1].map((star) {
        final count = counts[star] ?? 0;
        final pct = count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('$star',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(width: 6),
              const Icon(Icons.star, color: Colors.amber, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.amber),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined,
              size: 64,
              color: isDark ? const Color(0xFF4B5563) : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا توجد تقييمات بعد',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('تقييمات العملاء ستظهر هنا',
              style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _reviewCard(dynamic review) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rating = (review['rating'] ?? 0);
    final ratingNum =
        rating is int ? rating : int.tryParse(rating.toString()) ?? 0;
    final comment = review['comment'] ?? review['content'] ?? '';
    final userName = review['user_name'] ?? review['reviewer_name'] ?? 'مستخدم';
    final productName = review['product_name'] ?? '';
    final date = review['created_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[300]!, Colors.orange[400]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    userName.toString().isNotEmpty
                        ? userName.toString()[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName.toString(),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827))),
                    if (date != null)
                      Text(_formatDate(date.toString()),
                          style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : Colors.grey[500],
                              fontSize: 11)),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < ratingNum ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        )),
              ),
            ],
          ),

          if (productName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2B1F12) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2,
                      size: 14, color: Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(productName,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFF97316)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(comment,
                style: TextStyle(
                    color: isDark ? const Color(0xFFD1D5DB) : Colors.grey[700],
                    height: 1.5,
                    fontSize: 13)),
          ],
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
