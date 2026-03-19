import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final res = await ApiService.getOrders();
      final data = res['data'] ?? res['orders'] ?? [];
      setState(() {
        if (data is List) _orders = data.map((o) => Order.fromJson(o)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('طلباتي')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('سجّل دخولك لعرض طلباتك'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white),
                child: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('لا توجد طلبات',
                          style: TextStyle(
                              fontSize: 18,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Text('ابدأ بالتسوق لإنشاء طلبك الأول',
                          style: TextStyle(color: textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (ctx, i) => _orderCard(_orders[i]),
                  ),
                ),
    );
  }

  Widget _orderCard(Order order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statusInfo = _getStatusInfo(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderNumber,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF111827))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo['bgColor'],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusInfo['label'],
                      style: TextStyle(
                          fontSize: 12,
                          color: statusInfo['color'],
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _infoRow('المتجر', order.storeName ?? '-'),
                _infoRow('التاريخ', _formatDate(order.createdAt)),
                _infoRow('المنتجات', '${order.items.length} منتج'),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المجموع',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827))),
                    Text('${order.totalAmount.toStringAsFixed(0)} د.ج',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF97316),
                            fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          if (order.status == 'pending')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelOrder(order.id),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('إلغاء الطلب'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600],
                  fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF111827))),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'label': 'بانتظار',
          'color': Colors.orange[700],
          'bgColor': Colors.orange[50]
        };
      case 'confirmed':
        return {
          'label': 'مؤكد',
          'color': Colors.blue[700],
          'bgColor': Colors.blue[50]
        };
      case 'processing':
        return {
          'label': 'قيد التحضير',
          'color': Colors.indigo[700],
          'bgColor': Colors.indigo[50]
        };
      case 'shipped':
        return {
          'label': 'تم الشحن',
          'color': Colors.teal[700],
          'bgColor': Colors.teal[50]
        };
      case 'delivered':
        return {
          'label': 'تم التوصيل',
          'color': Colors.green[700],
          'bgColor': Colors.green[50]
        };
      case 'cancelled':
        return {
          'label': 'ملغي',
          'color': Colors.red[700],
          'bgColor': Colors.red[50]
        };
      default:
        return {
          'label': status,
          'color': Colors.grey[700],
          'bgColor': Colors.grey[50]
        };
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.cancelOrder(orderId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إلغاء الطلب'), backgroundColor: Colors.green),
        );
        _loadOrders();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
