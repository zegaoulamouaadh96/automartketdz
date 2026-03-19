import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class StoreOrdersScreen extends StatefulWidget {
  const StoreOrdersScreen({super.key});

  @override
  State<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends State<StoreOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = [
    'الكل',
    'بانتظار',
    'مؤكد',
    'قيد التحضير',
    'تم الشحن',
    'تم التوصيل',
    'ملغي'
  ];
  final _statuses = [
    '',
    'pending',
    'confirmed',
    'processing',
    'shipped',
    'delivered',
    'cancelled'
  ];

  List<Order> _orders = [];
  bool _loading = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index != _currentTab) {
        _currentTab = _tabCtrl.index;
        _loadOrders();
      }
    });
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final status = _statuses[_currentTab];
      final res = await ApiService.getStoreOrders(
          status: status.isEmpty ? null : status);
      final data = res['data'] ?? res['orders'] ?? [];
      setState(() {
        if (data is List) _orders = data.map((o) => Order.fromJson(o)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await ApiService.updateOrderStatus(orderId, newStatus);
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تحديث حالة الطلب'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إلغاء الطلب'),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: 'سبب الإلغاء (اختياري)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تراجع')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('تأكيد الإلغاء',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (reason == null) return;

    try {
      await ApiService.updateOrderStatus(orderId, 'cancelled',
          cancelledReason: reason.isNotEmpty ? reason : null);
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إلغاء الطلب'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: const Color(0xFFF97316),
          labelColor: const Color(0xFFF97316),
          unselectedLabelColor:
              isDark ? const Color(0xFF9CA3AF) : Colors.grey[600],
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmpty()
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

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64,
              color: isDark ? const Color(0xFF4B5563) : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا توجد طلبات',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('الطلبات الجديدة ستظهر هنا',
              style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _orderCard(Order order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final status = _getStatusInfo(order.status);
    final nextAction = _getNextAction(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (status['color'] as Color).withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(status['icon'] as IconData,
                    color: status['color'] as Color, size: 20),
                const SizedBox(width: 8),
                Text(order.orderNumber,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            isDark ? Colors.white : const Color(0xFF111827))),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: (status['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status['label'] as String,
                      style: TextStyle(
                          color: status['color'] as Color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Items
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(item.productName,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('x${item.quantity}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13)),
                          const SizedBox(width: 10),
                          Text('${item.price.toStringAsFixed(0)} د.ج',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    )),

                const Divider(height: 20),

                // Order info
                _infoRow('التاريخ', _formatDate(order.createdAt)),
                if (order.shippingAddress != null)
                  _infoRow('العنوان', order.shippingAddress!),
                if (order.paymentMethod != null)
                  _infoRow('الدفع', _paymentLabel(order.paymentMethod!)),

                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2B1F12)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المجموع الكلي',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827))),
                      Text('${order.totalAmount.toStringAsFixed(0)} د.ج',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF97316),
                              fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (nextAction != null || order.status == 'pending')
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (order.status == 'pending' ||
                      order.status == 'confirmed') ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelOrder(order.id),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (nextAction != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(
                            order.id, nextAction['status'] as String),
                        icon: Icon(nextAction['icon'] as IconData, size: 18),
                        label: Text(nextAction['label'] as String),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600],
                    fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF111827)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'label': 'بانتظار التأكيد',
          'color': Colors.orange,
          'icon': Icons.hourglass_empty
        };
      case 'confirmed':
        return {
          'label': 'مؤكد',
          'color': Colors.blue,
          'icon': Icons.check_circle_outline
        };
      case 'processing':
        return {
          'label': 'قيد التحضير',
          'color': Colors.indigo,
          'icon': Icons.settings
        };
      case 'shipped':
        return {
          'label': 'تم الشحن',
          'color': Colors.teal,
          'icon': Icons.local_shipping
        };
      case 'delivered':
        return {
          'label': 'تم التوصيل',
          'color': Colors.green,
          'icon': Icons.done_all
        };
      case 'cancelled':
        return {
          'label': 'ملغي',
          'color': Colors.red,
          'icon': Icons.cancel_outlined
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.help_outline
        };
    }
  }

  Map<String, dynamic>? _getNextAction(String status) {
    switch (status) {
      case 'pending':
        return {'status': 'confirmed', 'label': 'قبول', 'icon': Icons.check};
      case 'confirmed':
        return {
          'status': 'processing',
          'label': 'بدء التحضير',
          'icon': Icons.settings
        };
      case 'processing':
        return {
          'status': 'shipped',
          'label': 'شحن',
          'icon': Icons.local_shipping
        };
      case 'shipped':
        return {
          'status': 'delivered',
          'label': 'تم التوصيل',
          'icon': Icons.done_all
        };
      default:
        return null;
    }
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash_on_delivery':
        return 'الدفع عند الاستلام';
      case 'ccp':
        return 'CCP';
      case 'baridi_mob':
        return 'بريدي موب';
      default:
        return method;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }
}
