// lib/screens/shared/chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/database_helper.dart';
import '../../utils/push_notification_helper.dart';

// Palet warna ala WhatsApp — dipakai khusus di layar chat ini,
// gak menyentuh AppColors global biar tema branding utama app gak berubah.
class _Wa {
  static const header = Color(0xFF075E54);
  static const headerLight = Color(0xFF128C7E);
  static const chatBg = Color(0xFFE5DDD5);
  static const sentBubble = Color(0xFFDCF8C6);
  static const accent = Color(0xFF25D366);
  static const tickBlue = Color(0xFF34B7F1);
}

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String memberName;
  final String kurirName;
  final bool isKurir;
  final String? memberPhotoUrl;
  final String? kurirPhotoUrl;
  final String? memberPhone;
  final String? kurirPhone;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.memberName,
    required this.kurirName,
    required this.isKurir,
    this.memberPhotoUrl,
    this.kurirPhotoUrl,
    this.memberPhone,
    this.kurirPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  List<ChatMessage> _messages = [];
  Order? _order;
  bool _loading = true;
  bool _sending = false;
  bool _confirming = false;
  Timer? _pollTimer;

  // Voice note
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _recordFilePath;

  String get _myName => widget.isKurir ? widget.kurirName : widget.memberName;
  String get _otherName => widget.isKurir ? widget.memberName : widget.kurirName;
  String? get _myPhoto => widget.isKurir ? widget.kurirPhotoUrl : widget.memberPhotoUrl;
  String? get _otherPhoto => widget.isKurir ? widget.memberPhotoUrl : widget.kurirPhotoUrl;
  String? get _otherPhone => widget.isKurir ? widget.memberPhone : widget.kurirPhone;

  Future<void> _callOther() async {
    final phone = (_otherPhone ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor telepon tidak tersedia')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka aplikasi telepon')));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    final msgs = await DatabaseHelper().getChatMessages(widget.orderId);
    // Tandai pesan dari lawan bicara sebagai udah dibaca begitu chat dibuka
    await DatabaseHelper().markMessagesAsRead(widget.orderId, readerIsKurir: widget.isKurir);
    final order = await DatabaseHelper().getOrderById(widget.orderId);
    final hasNewMessage = msgs.length != _messages.length;
    setState(() { _messages = msgs; _order = order; _loading = false; });
    if (!silent || hasNewMessage) _scrollToBottom();
  }

  Future<void> _confirmOrder() async {
    setState(() => _confirming = true);
    await DatabaseHelper().confirmOrderByCustomer(widget.orderId);
    // Kirim pesan otomatis sebagai jejak konfirmasi di chat
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: widget.orderId, senderName: _myName, isKurir: widget.isKurir,
      message: '✅ Saya konfirmasi pesanan ini, silakan lanjutkan.',
    );
    await DatabaseHelper().insertChatMessage(msg);
    await PushNotificationHelper.showChatNotification(
      orderId: widget.orderId, senderName: _myName, message: msg.message, isKurir: widget.isKurir,
      senderPhotoUrl: _myPhoto,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(msg);
      if (_order != null) _order!.customerConfirmed = true;
      _confirming = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send({String? imagePath}) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && imagePath == null) return;
    _msgCtrl.clear();
    setState(() => _sending = true);

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: widget.orderId,
      senderName: _myName,
      isKurir: widget.isKurir,
      message: imagePath != null ? (text.isEmpty ? '📷 Foto' : text) : text,
      imageUrl: imagePath ?? '',
    );

    await DatabaseHelper().insertChatMessage(msg);

    // Kirim push notification ke pihak lain
    await PushNotificationHelper.showChatNotification(
      orderId: widget.orderId,
      senderName: _myName,
      message: msg.message,
      isKurir: widget.isKurir,
      senderPhotoUrl: _myPhoto,
    );

    setState(() { _messages.add(msg); _sending = false; });
    _scrollToBottom();
  }

  // ==================== VOICE NOTE ====================
  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin mikrofon diperlukan buat kirim pesan suara')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() { _isRecording = true; _recordDuration = Duration.zero; _recordFilePath = path; });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try { await _audioRecorder.stop(); } catch (_) {}
    if (_recordFilePath != null) {
      final f = File(_recordFilePath!);
      if (await f.exists()) await f.delete();
    }
    if (mounted) setState(() { _isRecording = false; _recordFilePath = null; _recordDuration = Duration.zero; });
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    final duration = _recordDuration;
    if (mounted) setState(() => _isRecording = false);

    if (path == null) return;
    if (duration.inMilliseconds < 800) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rekaman terlalu pendek')));
      return;
    }

    setState(() => _sending = true);
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: widget.orderId, senderName: _myName, isKurir: widget.isKurir,
      message: '🎤 Pesan suara', audioUrl: path, audioDurationMs: duration.inMilliseconds,
    );
    await DatabaseHelper().insertChatMessage(msg);
    await PushNotificationHelper.showChatNotification(
      orderId: widget.orderId, senderName: _myName, message: '🎤 Pesan suara', isKurir: widget.isKurir,
      senderPhotoUrl: _myPhoto,
    );
    if (!mounted) return;
    setState(() { _messages.add(msg); _sending = false; });
    _scrollToBottom();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final img = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 75);
      if (img != null && mounted) await _send(imagePath: img.path);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengambil foto')));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const Text('Kirim Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt, color: AppColors.primary)),
              title: const Text('Ambil Foto'), subtitle: const Text('Gunakan kamera HP'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library, color: Colors.blue)),
              title: const Text('Pilih dari Galeri'), subtitle: const Text('Pilih foto yang sudah ada'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _buildConfirmationBanner() {
    final confirmed = _order!.customerConfirmed;

    if (confirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.green.shade50,
        child: Row(children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          const Expanded(child: Text('Pesanan sudah dikonfirmasi customer. Kurir bisa melanjutkan transaksi.',
            style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600))),
        ]),
      );
    }

    if (widget.isKurir) {
      // Sisi kurir: hanya info menunggu, tombol konfirmasi ada di sisi customer
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.orange.shade50,
        child: Row(children: [
          const Icon(Icons.hourglass_top, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(child: Text('Menunggu konfirmasi customer sebelum pesanan bisa diambil.',
            style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600))),
        ]),
      );
    }

    // Sisi customer: tampilkan tombol konfirmasi
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.orange.shade50,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.help_outline, size: 16, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('Kurir menunggu konfirmasi kamu sebelum melanjutkan pesanan.',
            style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirming ? null : _confirmOrder,
            icon: _confirming
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 16),
            label: const Text('Ya, Konfirmasi Pesanan Ini'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
      ]),
    );
  }

  bool _isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.day == d2.day && d1.month == d2.month && d1.year == d2.year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Wa.chatBg,
      appBar: AppBar(
        backgroundColor: _Wa.header,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          // Foto profil lawan bicara
          _ProfileAvatar(name: _otherName, photoUrl: _otherPhoto, radius: 18, showOnline: true),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            Text(widget.isKurir ? 'Pembeli' : 'Kurir',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ])),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video call butuh infrastruktur khusus (belum tersedia di versi ini)'))),
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: _callOther,
          ),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'refresh') _load(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, size: 18), SizedBox(width: 10), Text('Refresh')])),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade50,
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.blue),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Order #${widget.orderId.length > 8 ? widget.orderId.substring(widget.orderId.length - 8) : widget.orderId}',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            )),
          ]),
        ),

        // Banner status konfirmasi pesanan
        if (_order != null) _buildConfirmationBanner(),

        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _messages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _ProfileAvatar(name: _otherName, photoUrl: _otherPhoto, radius: 40),
                  const SizedBox(height: 16),
                  Text(_otherName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Belum ada pesan', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Mulai percakapan sekarang!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i];
                    final isMe = msg.isKurir == widget.isKurir;
                    final showDate = i == 0 || !_isSameDay(_messages[i - 1].createdAt, msg.createdAt);
                    return Column(children: [
                      if (showDate) _DateSeparator(timestamp: msg.createdAt),
                      _ChatBubble(msg: msg, isMe: isMe),
                    ]);
                  },
                ),
        ),

        // Input ala WhatsApp: pill putih (emoji, teks, lampiran) + tombol bulat kirim/mic
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          color: const Color(0xFFF0F0F0),
          child: SafeArea(
            top: false,
            child: _isRecording ? _buildRecordingBar() : _buildNormalInputRow(),
          ),
        ),
      ]),
    );
  }

  Widget _buildRecordingBar() {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        onPressed: _cancelRecording,
        tooltip: 'Batalkan',
      ),
      const Icon(Icons.mic, color: AppColors.error, size: 22),
      const SizedBox(width: 8),
      Text(_fmtDuration(_recordDuration), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      const Expanded(child: Text('Merekam pesan suara...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
      GestureDetector(
        onTap: _stopRecordingAndSend,
        child: Container(
          width: 46, height: 46,
          decoration: const BoxDecoration(color: _Wa.accent, shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
        ),
      ),
    ]);
  }

  Widget _buildNormalInputRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                  child: Row(children: [
                    const SizedBox(width: 4),
                    const Icon(Icons.emoji_emotions_outlined, color: AppColors.textSecondary, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ketik pesan',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _send(),
                        maxLines: 4, minLines: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: AppColors.textSecondary, size: 22),
                      onPressed: _showImageOptions,
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _msgCtrl,
                builder: (_, value, __) {
                  final hasText = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: _sending
                      ? null
                      : hasText
                        ? () => _send()
                        : _startRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: _sending ? AppColors.divider : _Wa.accent,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                        ? const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(hasText ? Icons.send_rounded : Icons.mic, color: Colors.white, size: 22),
                    ),
                  );
                },
              ),
            ]);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

// ==================== PROFILE AVATAR ====================
class _ProfileAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool showOnline;

  const _ProfileAvatar({required this.name, this.photoUrl, this.radius = 20, this.showOnline = false});

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: photoUrl!.startsWith('/') ? FileImage(File(photoUrl!)) as ImageProvider : NetworkImage(photoUrl!),
        backgroundColor: AppColors.primaryLight.withOpacity(0.2),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryLight.withOpacity(0.2),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: radius * 0.7, color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (!showOnline) return avatar;

    return Stack(children: [
      avatar,
      Positioned(bottom: 0, right: 0, child: Container(
        width: radius * 0.55, height: radius * 0.55,
        decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5)),
      )),
    ]);
  }
}

// ==================== CHAT BUBBLE ====================
class _ChatBubble extends StatefulWidget {
  final ChatMessage msg;
  final bool isMe;
  const _ChatBubble({required this.msg, required this.isMe});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool get _hasAudio => widget.msg.audioUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasAudio) {
      _totalDuration = Duration(milliseconds: widget.msg.audioDurationMs);
      _player = AudioPlayer();
      _player!.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
      _player!.onPositionChanged.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });
      _player!.onPlayerComplete.listen((_) {
        if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_player == null) return;
    if (_isPlaying) {
      await _player!.pause();
    } else {
      if (_position >= _totalDuration || _position == Duration.zero) {
        await _player!.play(DeviceFileSource(widget.msg.audioUrl));
      } else {
        await _player!.resume();
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isMe = widget.isMe;
    final time = DateTime.fromMillisecondsSinceEpoch(msg.createdAt);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final hasImage = msg.imageUrl.isNotEmpty;
    final hasText = msg.message.isNotEmpty && msg.message != '📷 Foto' && msg.message != '🎤 Pesan suara';

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              margin: EdgeInsets.only(left: isMe ? 40 : 0, right: isMe ? 0 : 40),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: isMe ? _Wa.sentBubble : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10), topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe ? 10 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 10),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 2, offset: const Offset(0, 1))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10), topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe ? 10 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 10),
                ),
                child: Stack(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!isMe) Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                      child: Text(msg.senderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _Wa.headerLight)),
                    ),
                    if (hasImage) GestureDetector(
                      onTap: () => _showFullImage(context, msg.imageUrl),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(msg.imageUrl), width: 220, height: 200, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 220, height: 80, color: AppColors.divider,
                              child: const Center(child: Icon(Icons.broken_image, color: AppColors.textSecondary)))),
                        ),
                      ),
                    ),
                    if (_hasAudio) _buildAudioRow(isMe),
                    if (hasText)
                      Padding(
                        padding: EdgeInsets.fromLTRB(10, hasImage || _hasAudio ? 4 : 8, 54, 8),
                        child: Text(msg.message, style: const TextStyle(color: Colors.black87, fontSize: 14.5, height: 1.35)),
                      )
                    else if (!hasImage && !_hasAudio)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 54, 8),
                        child: Text(msg.message, style: const TextStyle(color: Colors.black87, fontSize: 14.5)),
                      )
                    else if (!hasText && !_hasAudio)
                      const SizedBox(height: 18) // ruang buat overlay jam di atas foto tanpa teks
                    else
                      const SizedBox(height: 4),
                  ]),
                  // Jam + centang, nempel di pojok kanan bawah bubble (ala WhatsApp)
                  Positioned(
                    right: 6, bottom: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: hasImage ? 6 : 0, vertical: hasImage ? 2 : 0),
                      decoration: hasImage
                        ? BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8))
                        : null,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(timeStr, style: TextStyle(fontSize: 10.5, color: hasImage ? Colors.white70 : Colors.black45)),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.done_all, size: 14, color: hasImage ? Colors.white70 : (msg.isRead ? _Wa.tickBlue : Colors.black45)),
                        ],
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioRow(bool isMe) {
    final progress = _totalDuration.inMilliseconds == 0 ? 0.0 : (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 4),
      child: Row(children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _Wa.headerLight, shape: BoxShape.circle),
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 20,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: _Wa.headerLight,
                  inactiveTrackColor: _Wa.headerLight.withOpacity(0.25),
                  thumbColor: _Wa.headerLight,
                ),
                child: Slider(
                  value: progress, min: 0, max: 1,
                  onChanged: (v) {
                    final newPos = Duration(milliseconds: (v * _totalDuration.inMilliseconds).round());
                    _player?.seek(newPos);
                  },
                ),
              ),
            ),
            Text(_fmt(_isPlaying || _position > Duration.zero ? _position : _totalDuration),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  void _showFullImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black, insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          Center(child: InteractiveViewer(child: Image.file(File(path)))),
          Positioned(top: 40, right: 16, child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white)),
          )),
        ]),
      ),
    );
  }
}

// ==================== DATE SEPARATOR ====================
class _DateSeparator extends StatelessWidget {
  final int timestamp;
  const _DateSeparator({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    String label;
    if (d.day == now.day && d.month == now.month && d.year == now.year) label = 'Hari ini';
    else if (d.day == now.day - 1) label = 'Kemarin';
    else label = '${d.day}/${d.month}/${d.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}
