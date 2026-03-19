import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../chat_screen.dart';

class SellerMessagesScreen extends StatefulWidget {
  const SellerMessagesScreen({super.key});

  @override
  State<SellerMessagesScreen> createState() => _SellerMessagesScreenState();
}

class _SellerMessagesScreenState extends State<SellerMessagesScreen> {
  List<dynamic> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final res = await ApiService.getConversations();
      setState(() {
        _conversations = res['data'] ?? res['conversations'] ?? [];
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
        title: const Text('الرسائل'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmpty(isDark)
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    itemBuilder: (ctx, i) =>
                        _conversationCard(_conversations[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final textSecondary =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
                  (isDark ? const Color(0xFF312012) : const Color(0xFFFED7AA))
                      .withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline,
                size: 64, color: Color(0xFFF97316)),
          ),
          const SizedBox(height: 20),
          Text('لا توجد رسائل',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('رسائل العملاء ستظهر هنا',
              style: TextStyle(color: textSecondary)),
        ],
      ),
    );
  }

  Widget _conversationCard(dynamic conv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build real name from first_name + last_name if available
    final firstName = conv['other_first_name'] ?? '';
    final lastName = conv['other_last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final otherUser = fullName.isNotEmpty
        ? fullName
        : (conv['other_user_name'] ?? conv['other_user'] ?? 'مستخدم');
    final otherAvatar = conv['other_avatar']?.toString();
    final otherStoreLogo = conv['other_store_logo']?.toString();
    final avatarPath = (otherAvatar != null && otherAvatar.isNotEmpty)
        ? otherAvatar
        : otherStoreLogo;
    final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
    final productName = conv['product_name']?.toString();
    final lastMsg = conv['last_message'] ?? conv['content'] ?? '';
    final unread = conv['unread_count'] ?? 0;
    final date =
        conv['updated_at'] ?? conv['last_message_at'] ?? conv['created_at'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: conv['id']?.toString() ??
                    conv['conversation_id']?.toString() ??
                    '',
                otherUserName: otherUser.toString(),
                otherUserAvatar: avatarPath,
                productName: productName,
              ),
            )).then((_) => _loadConversations());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread > 0
              ? (isDark ? const Color(0xFF2B1F12) : const Color(0xFFFFF7ED))
              : (isDark ? const Color(0xFF111827) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
          ],
          border: unread > 0
              ? Border.all(
                  color: const Color(0xFFF97316).withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: hasAvatar
                    ? Image.network(
                        ApiService.resolveMediaUrl(avatarPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            otherUser.toString().isNotEmpty
                                ? otherUser.toString()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          otherUser.toString().isNotEmpty
                              ? otherUser.toString()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(otherUser.toString(),
                            style: TextStyle(
                              fontWeight: unread > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            )),
                      ),
                      if (date != null)
                        Text(_formatTime(date.toString()),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg.toString(),
                          style: TextStyle(
                            color: unread > 0
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.grey[600]),
                            fontSize: 13,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} د';
      if (diff.inHours < 24) return '${diff.inHours} س';
      if (diff.inDays < 7) return '${diff.inDays} ي';
      return '${date.month}/${date.day}';
    } catch (_) {
      return '';
    }
  }
}
