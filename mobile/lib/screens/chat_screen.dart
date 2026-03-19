import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? productName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.productName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;

  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _uploadingImage = false;
  bool _uploadingAudio = false;
  bool _isRecording = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  String? _recordPath;
  Timer? _refreshTimer;
  bool _showAttachMenu = false;
  String? _activeAudioUrl;
  PlayerState _playerState = PlayerState.stopped;

  // Animations
  late final AnimationController _headerAnim;
  late final AnimationController _inputAnim;
  late final AnimationController _attachAnim;
  late final Animation<double> _headerSlide;
  late final Animation<double> _inputSlide;

  static const _orange = Color(0xFFF97316);
  static const _deepOrange = Color(0xFFEA580C);
  static const _dark = Color(0xFF1E293B);
  static const _bubbleBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _inputAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _attachAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _headerSlide = Tween<double>(begin: -50, end: 0).animate(
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));
    _inputSlide = Tween<double>(begin: 80, end: 0).animate(
        CurvedAnimation(parent: _inputAnim, curve: Curves.easeOutCubic));

    _headerAnim.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _inputAnim.forward();
    });

    _loadMessages();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _loadMessages());

    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        if (state == PlayerState.stopped || state == PlayerState.completed) {
          _activeAudioUrl = null;
        }
      });
    });
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.getMessages(widget.conversationId);
      if (!mounted) return;
      final newMessages = res['data'] ?? res['messages'] ?? [];
      final changed = newMessages.length != _messages.length;
      setState(() {
        _messages = newMessages;
        _loading = false;
      });
      if (changed) _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ApiService.sendMessage(
          receiverId: '', conversationId: widget.conversationId, message: text);
      _msgCtrl.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) _showError('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    setState(() => _showAttachMenu = false);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final uploadRes = await ApiService.uploadChatImage(picked.path);
      final imageUrl = uploadRes['image_url'] as String? ?? '';
      if (imageUrl.isEmpty) throw Exception('فشل رفع الصورة');

      await ApiService.sendImageMessage(
        receiverId: '',
        conversationId: widget.conversationId,
        imageUrl: imageUrl,
        content: '',
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) _showError('$e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _sending || _uploadingAudio) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showError('يرجى السماح بالوصول إلى الميكروفون');
      return;
    }

    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _recordPath = path;
        _showAttachMenu = false;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) _showError('تعذر بدء التسجيل: $e');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_isRecording) return;

    _recordTimer?.cancel();
    final durationSeconds = _recordSeconds;

    String? filePath;
    try {
      filePath = await _recorder.stop();
    } catch (_) {
      filePath = _recordPath;
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordPath = null;
    });

    if (!send) {
      if (filePath != null && filePath.isNotEmpty) {
        unawaited(File(filePath).delete().catchError((_) {}));
      }
      return;
    }

    if (filePath == null || filePath.isEmpty || durationSeconds <= 0) {
      _showError('لم يتم تسجيل صوت صالح');
      return;
    }

    await _sendVoiceMessage(filePath, durationSeconds);
  }

  Future<void> _sendVoiceMessage(String filePath, int durationSeconds) async {
    setState(() {
      _sending = true;
      _uploadingAudio = true;
    });
    try {
      final uploadRes = await ApiService.uploadChatMedia(filePath);
      final audioUrl = (uploadRes['audio_url'] ?? '').toString();
      if (audioUrl.isEmpty) {
        throw Exception('فشل رفع الرسالة الصوتية');
      }

      final duration = _formatDuration(durationSeconds);
      await ApiService.sendVoiceMessage(
        receiverId: '',
        conversationId: widget.conversationId,
        content: 'رسالة صوتية ($duration)',
        audioUrl: audioUrl,
      );

      await _loadMessages();
    } catch (e) {
      if (mounted) _showError('$e');
    } finally {
      unawaited(File(filePath).delete().catchError((_) {}));
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadingAudio = false;
        });
      }
    }
  }

  Future<void> _toggleAudioPlayback(String rawUrl) async {
    final url = ApiService.resolveMediaUrl(rawUrl);
    if (url.isEmpty) return;

    try {
      if (_activeAudioUrl == rawUrl && _playerState == PlayerState.playing) {
        await _player.stop();
        return;
      }

      await _player.stop();
      setState(() => _activeAudioUrl = rawUrl);
      await _player.play(UrlSource(url));
    } catch (e) {
      if (mounted) _showError('تعذر تشغيل الصوت: $e');
    }
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _extractVoiceDuration(String content) {
    final durationMatch = RegExp(r'\((\d{2}:\d{2})\)').firstMatch(content);
    return durationMatch?.group(1) ?? '';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red[400],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String get _displayName {
    final name = widget.otherUserName;
    if (name.isNotEmpty && name != 'مستخدم') return name;
    return 'مستخدم';
  }

  String get _initials {
    final parts = _displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF0F2F5),
      body: Column(
        children: [
          _buildHeader(),
          if (widget.productName != null && widget.productName!.isNotEmpty)
            _buildProductBanner(),
          Expanded(child: _buildMessagesList(userId)),
          if (_showAttachMenu) _buildAttachMenu(),
          if (_uploadingImage) _buildUploadingIndicator(),
          if (_uploadingAudio)
            _buildUploadingIndicator(label: 'جاري رفع الرسالة الصوتية...'),
          _buildInputBar(),
        ],
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
          opacity: _headerAnim.value,
          child: Container(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 14,
                left: 16,
                right: 16),
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
                const SizedBox(width: 12),
                // Avatar
                _buildAvatar(),
                const SizedBox(width: 12),
                // Name & status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent[400],
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('متصل',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons
                _headerAction(Icons.phone_rounded, () {}),
                const SizedBox(width: 6),
                _headerAction(Icons.more_vert_rounded, () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final hasAvatar =
        widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
        ],
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                ApiService.resolveMediaUrl(widget.otherUserAvatar),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(_initials,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Product Banner ──
  Widget _buildProductBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: _orange, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محادثة حول المنتج',
                    style: TextStyle(
                        color:
                            isDark ? const Color(0xFF9CA3AF) : Colors.grey[500],
                        fontSize: 11)),
                const SizedBox(height: 2),
                Text(widget.productName!,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : _dark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  // ── Messages List ──
  Widget _buildMessagesList(dynamic userId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: _orange,
                strokeWidth: 3,
                backgroundColor: _orange.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 16),
            Text('جاري تحميل الرسائل...',
                style: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500],
                    fontSize: 14)),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_rounded, size: 56, color: _orange),
            ),
            const SizedBox(height: 20),
            Text('ابدأ المحادثة',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : _dark)),
            const SizedBox(height: 8),
            Text('أرسل رسالة أو صورة للتواصل',
                style: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500],
                    fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final isMe = msg['sender_id'] == userId;
        final showDate = i == 0 ||
            _differentDay(_messages[i - 1]['created_at'], msg['created_at']);
        return Column(
          children: [
            if (showDate) _dateSeparator(msg['created_at']),
            _messageBubble(msg, isMe, i),
          ],
        );
      },
    );
  }

  bool _differentDay(String? a, String? b) {
    if (a == null || b == null) return false;
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.day != db.day || da.month != db.month || da.year != db.year;
  }

  Widget _dateSeparator(String? dateStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final date = DateTime.tryParse(dateStr ?? '');
    String label = '';
    if (date != null) {
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) {
        label = 'اليوم';
      } else if (diff == 1) {
        label = 'أمس';
      } else {
        label = '${date.day}/${date.month}/${date.year}';
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: isDark ? const Color(0xFF374151) : Colors.grey[300],
                  thickness: 0.5)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
              ],
            ),
            child: Text(label,
                style: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Divider(
                  color: isDark ? const Color(0xFF374151) : Colors.grey[300],
                  thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _messageBubble(dynamic msg, bool isMe, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = msg['content'] as String? ?? '';
    final imageUrl = msg['image_url'] as String?;
    final audioUrl = msg['audio_url'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final time = _formatTime(msg['created_at']);
    final isRead = msg['is_read'] == true;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index % 5) * 50),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) {
        final safeOpacity = val.clamp(0.0, 1.0).toDouble();
        return Transform.translate(
          offset: Offset(isMe ? 30 * (1 - val) : -30 * (1 - val), 0),
          child: Opacity(opacity: safeOpacity, child: child),
        );
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: hasImage
                    ? const EdgeInsets.all(4)
                    : hasAudio
                        ? const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10)
                        : const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [_orange, _deepOrange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe
                      ? null
                      : (isDark ? const Color(0xFF1F2937) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isMe ? _orange : Colors.black)
                          .withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          onTap: () => _showFullImage(imageUrl),
                          child: Image.network(
                            ApiService.resolveMediaUrl(imageUrl),
                            width: 220,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 220,
                                height: 200,
                                color: isDark
                                    ? const Color(0xFF111827)
                                    : Colors.grey[200],
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        color: _orange, strokeWidth: 2)),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 100,
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : Colors.grey[200],
                              child: const Icon(Icons.broken_image_rounded,
                                  color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    if (hasImage && content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Text(content,
                            style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : (isDark ? Colors.white : _dark),
                                fontSize: 14,
                                height: 1.4)),
                      ),
                    // Voice message
                    if (hasAudio && !hasImage)
                      _buildVoiceBubble(
                        rawAudioUrl: audioUrl,
                        content: content,
                        isMe: isMe,
                      ),
                    // Normal text
                    if (!hasImage && !hasAudio)
                      Text(content,
                          style: TextStyle(
                              color: isMe
                                  ? Colors.white
                                  : (isDark ? Colors.white : _dark),
                              fontSize: 15,
                              height: 1.4)),
                  ],
                ),
              ),
              // Time & read status
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time,
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : Colors.grey[400],
                            fontSize: 10)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color:
                            isRead ? const Color(0xFF3B82F6) : Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceBubble({
    required String rawAudioUrl,
    required String content,
    required bool isMe,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive =
        _activeAudioUrl == rawAudioUrl && _playerState == PlayerState.playing;
    final duration = _extractVoiceDuration(content);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _toggleAudioPlayback(rawAudioUrl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isMe ? Colors.white : _orange).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isMe ? Colors.white : _orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          ...List.generate(
            12,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 3,
              height: (isActive ? (10 + (i % 5) * 4) : (8 + (i % 4) * 3))
                  .toDouble(),
              decoration: BoxDecoration(
                color: (isMe ? Colors.white : _orange)
                    .withValues(alpha: isActive ? 0.95 : 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            duration.isEmpty ? 'صوت' : duration,
            style: TextStyle(
              color: isMe ? Colors.white : (isDark ? Colors.white : _dark),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _FullImageView(url: ApiService.resolveMediaUrl(url)),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ── Attach Menu ──
  Widget _buildAttachMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _attachOption(
              Icons.photo_library_rounded,
              'المعرض',
              const Color(0xFF8B5CF6),
              () => _pickAndSendImage(ImageSource.gallery)),
          _attachOption(
              Icons.camera_alt_rounded,
              'الكاميرا',
              const Color(0xFF3B82F6),
              () => _pickAndSendImage(ImageSource.camera)),
          _attachOption(Icons.close_rounded, 'إلغاء', Colors.grey,
              () => setState(() => _showAttachMenu = false)),
        ],
      ),
    );
  }

  Widget _attachOption(
      IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFD1D5DB) : Colors.grey[700],
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Uploading Indicator ──
  Widget _buildUploadingIndicator({String label = 'جاري رفع الصورة...'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: _orange.withValues(alpha: 0.08),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: _orange,
              strokeWidth: 2,
              backgroundColor: _orange.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: _orange, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Input Bar ──
  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _inputAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _inputSlide.value),
        child: Opacity(
          opacity: _inputAnim.value,
          child: Container(
            padding: EdgeInsets.only(
              left: 10,
              right: 10,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 15,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: _isRecording ? _buildRecordingBar() : _buildNormalInput(),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Attach button
        GestureDetector(
          onTap: () => setState(() => _showAttachMenu = !_showAttachMenu),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _showAttachMenu
                  ? _orange.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF1F2937) : Colors.grey[100]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _showAttachMenu ? Icons.close_rounded : Icons.add_rounded,
              color: _showAttachMenu
                  ? _orange
                  : (isDark ? const Color(0xFFD1D5DB) : Colors.grey[600]),
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _msgCtrl,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[400],
                    fontSize: 14),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send or Voice button
        GestureDetector(
          onTap: () {
            if (_sending || _uploadingAudio || _uploadingImage) return;
            if (_msgCtrl.text.trim().isNotEmpty) {
              _sendMessage();
            } else {
              _startRecording();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: _msgCtrl.text.trim().isNotEmpty
                  ? const LinearGradient(colors: [_orange, _deepOrange])
                  : null,
              color: _msgCtrl.text.trim().isEmpty ? Colors.grey[100] : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _msgCtrl.text.trim().isNotEmpty
                  ? [
                      BoxShadow(
                          color: _orange.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ]
                  : null,
            ),
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(
                    _msgCtrl.text.trim().isNotEmpty
                        ? Icons.send_rounded
                        : Icons.mic_rounded,
                    color: _msgCtrl.text.trim().isNotEmpty
                        ? Colors.white
                        : (isDark ? const Color(0xFFD1D5DB) : Colors.grey[600]),
                    size: 22,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingBar() {
    final duration =
        '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        // Cancel
        GestureDetector(
          onTap: () => _stopRecording(send: false),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.delete_rounded, color: Colors.red[400], size: 22),
          ),
        ),
        const SizedBox(width: 12),
        // Recording indicator
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (_, val, __) => Opacity(
                    opacity: val,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('جاري التسجيل...',
                    style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(duration,
                    style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Send
        GestureDetector(
          onTap: () => _stopRecording(send: true),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_orange, _deepOrange]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _orange.withValues(alpha: 0.35), blurRadius: 10),
              ],
            ),
            child:
                const Icon(Icons.send_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _headerAnim.dispose();
    _inputAnim.dispose();
    _attachAnim.dispose();
    _refreshTimer?.cancel();
    _recordTimer?.cancel();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
//  Full Image Viewer
// ═══════════════════════════════════════════════════════════════
class _FullImageView extends StatelessWidget {
  final String url;
  const _FullImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white54,
                  size: 64)),
        ),
      ),
    );
  }
}
