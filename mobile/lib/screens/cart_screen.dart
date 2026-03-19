import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المشتريات'),
        actions: [
          if (cart.itemCount > 0)
            TextButton(
              onPressed: () {
                cart.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تفريغ السلة')),
                );
              },
              child: const Text('تفريغ', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('سلة المشتريات فارغة',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('أضف منتجات للبدء بالتسوق',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('تصفح المنتجات'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5)
                          ],
                        ),
                        child: Row(
                          children: [
                            // Product image
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: item.product.images.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        ApiService.resolveMediaUrl(
                                            item.product.images[0]),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.build,
                                                color: Colors.grey),
                                      ),
                                    )
                                  : const Icon(Icons.build, color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            // Product info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${item.product.price.toStringAsFixed(0)} د.ج',
                                      style: const TextStyle(
                                          color: Color(0xFFF97316),
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            // Quantity controls
                            Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => cart.updateQuantity(
                                          item.product.id, item.quantity - 1),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey[300]!),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child:
                                            const Icon(Icons.remove, size: 16),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text('${item.quantity}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    InkWell(
                                      onTap: () => cart.updateQuantity(
                                          item.product.id, item.quantity + 1),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.add,
                                            size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => cart.removeItem(item.product.id),
                                  child: const Text('حذف',
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Bottom checkout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع:',
                              style: TextStyle(fontSize: 16)),
                          Text('${cart.totalAmount.toStringAsFixed(0)} د.ج',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!auth.isLoggedIn) {
                              Navigator.pushNamed(context, '/login');
                              return;
                            }
                            _showCheckout(context, cart, auth);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('إتمام الطلب',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showCheckout(
      BuildContext context, CartProvider cart, AuthProvider auth) {
    final user = auth.user;
    final initialName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    final shippingNameCtrl = TextEditingController(text: initialName);
    final shippingPhoneCtrl = TextEditingController(text: user?.phone ?? '');
    final shippingWilayaCtrl = TextEditingController(text: user?.wilaya ?? '');
    final addressCtrl = TextEditingController();
    String paymentMethod = 'cash_on_delivery';
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إتمام الطلب',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: shippingNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المستلم',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: shippingPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: shippingWilayaCtrl,
                  decoration: InputDecoration(
                    labelText: 'الولاية',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(
                    labelText: 'عنوان الشحن',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('طريقة الدفع',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...['cash_on_delivery', 'ccp', 'baridimob', 'bank_transfer']
                    .map((m) {
                  final labels = {
                    'cash_on_delivery': 'الدفع عند الاستلام',
                    'ccp': 'CCP',
                    'baridimob': 'بريدي موب',
                    'bank_transfer': 'تحويل بنكي',
                  };
                  return RadioListTile<String>(
                    title:
                        Text(labels[m]!, style: const TextStyle(fontSize: 14)),
                    value: m,
                    groupValue: paymentMethod,
                    activeColor: const Color(0xFFF97316),
                    onChanged: (v) => setModalState(() => paymentMethod = v!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المجموع:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${cart.totalAmount.toStringAsFixed(0)} د.ج',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (shippingNameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أدخل اسم المستلم')),
                        );
                        return;
                      }

                      if (shippingPhoneCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أدخل رقم الهاتف')),
                        );
                        return;
                      }

                      if (shippingWilayaCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أدخل الولاية')),
                        );
                        return;
                      }

                      if (addressCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أدخل عنوان الشحن')),
                        );
                        return;
                      }
                      try {
                        final items = cart.items
                            .map((item) => {
                                  'product_id': item.product.id,
                                  'quantity': item.quantity,
                                })
                            .toList();

                        await ApiService.createOrder({
                          'items': items,
                          'shipping_name': shippingNameCtrl.text.trim(),
                          'shipping_phone': shippingPhoneCtrl.text.trim(),
                          'shipping_wilaya': shippingWilayaCtrl.text.trim(),
                          'shipping_address': addressCtrl.text.trim(),
                          'payment_method': paymentMethod,
                        });

                        cart.clear();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تم إنشاء الطلب بنجاح!'),
                                backgroundColor: Colors.green),
                          );
                          Navigator.pushReplacementNamed(context, '/orders');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('تأكيد الطلب',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
