import 'dart:async';
import 'package:flutter/services.dart';
import 'api_service.dart';

class ChatNotificationService {
  ChatNotificationService._();

  static final ChatNotificationService instance = ChatNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('automarket_dz/notifications');

  Timer? _pollTimer;
  bool _isRunning = false;
  bool _seededConversations = false;
  bool _seededSystemNotifications = false;
  Map<String, int> _lastUnreadByConversation = {};
  Set<String> _lastSystemNotificationIds = <String>{};
  DateTime? _rateLimitedUntil;

  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {
      // Notification permission flow is best-effort.
    }
  }

  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    _seededConversations = false;
    _seededSystemNotifications = false;
    _lastUnreadByConversation = {};
    _lastSystemNotificationIds = <String>{};
    _rateLimitedUntil = null;

    await _poll();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _poll(),
    );
  }

  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isRunning = false;
    _seededConversations = false;
    _seededSystemNotifications = false;
    _lastUnreadByConversation = {};
    _lastSystemNotificationIds = <String>{};
    _rateLimitedUntil = null;
  }

  Future<void> _poll() async {
    if (!_isRunning) return;

    final now = DateTime.now();
    if (_rateLimitedUntil != null && now.isBefore(_rateLimitedUntil!)) {
      return;
    }

    await _pollConversations();
    await _pollSystemNotifications();
  }

  Future<void> _pollConversations() async {
    if (!_isRunning) return;

    try {
      final res = await ApiService.getConversations();
      final rawConversations = res['data'] ?? res['conversations'] ?? [];
      if (rawConversations is! List) return;

      final latestUnread = <String, int>{};

      for (final conversation in rawConversations) {
        if (conversation is! Map) continue;

        final id =
            (conversation['id'] ?? conversation['conversation_id'])?.toString();
        if (id == null || id.isEmpty) continue;

        final unread = _parseInt(conversation['unread_count']);
        latestUnread[id] = unread;

        if (!_seededConversations) continue;

        final previousUnread = _lastUnreadByConversation[id] ?? 0;
        if (unread > previousUnread) {
          final senderName = _extractSenderName(conversation);
          final messageText = (conversation['last_message'] ??
                  conversation['content'] ??
                  'لديك رسالة جديدة')
              .toString();

          await _showNotification(
            title: 'رسالة جديدة',
            body: senderName.isNotEmpty
                ? '$senderName: $messageText'
                : messageText,
          );
        }
      }

      _lastUnreadByConversation = latestUnread;
      _seededConversations = true;
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        // Back off when the backend rate limiter is hit.
        _rateLimitedUntil = DateTime.now().add(const Duration(minutes: 2));
      }
    } catch (_) {
      // Keep polling quietly; network interruptions are expected on mobile.
    }
  }

  Future<void> _pollSystemNotifications() async {
    if (!_isRunning) return;

    try {
      final res = await ApiService.getNotifications();
      final rawNotifications = res['notifications'] ?? [];
      if (rawNotifications is! List) return;

      final latestIds = <String>{};

      for (final notification in rawNotifications) {
        if (notification is! Map) continue;

        final id = notification['id']?.toString();
        if (id == null || id.isEmpty) continue;
        latestIds.add(id);

        if (!_seededSystemNotifications) continue;
        if (_lastSystemNotificationIds.contains(id)) continue;
        if (notification['is_read'] == true) continue;

        final title =
            (notification['title']?.toString().trim().isNotEmpty ?? false)
                ? notification['title'].toString()
                : 'إشعار جديد';
        final body =
            (notification['message']?.toString().trim().isNotEmpty ?? false)
                ? notification['message'].toString()
                : 'لديك تحديث جديد في حسابك';

        await _showNotification(title: title, body: body);
      }

      _lastSystemNotificationIds = latestIds;
      _seededSystemNotifications = true;
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        _rateLimitedUntil = DateTime.now().add(const Duration(minutes: 2));
      }
    } catch (_) {
      // Keep polling quietly; network interruptions are expected on mobile.
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _extractSenderName(Map conversation) {
    final full = (conversation['other_user_name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;

    final first = (conversation['other_first_name'] ?? '').toString().trim();
    final last = (conversation['other_last_name'] ?? '').toString().trim();
    return [first, last].where((s) => s.isNotEmpty).join(' ').trim();
  }

  Future<void> _showNotification(
      {required String title, required String body}) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
      });
    } catch (_) {
      // If native notification fails, do nothing and continue app flow.
    }
  }
}
