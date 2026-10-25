// lib/screens/member/review_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class ReviewScreen extends StatefulWidget {
  final Order order;
  const ReviewScreen({super.key, required this.order});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // Penilaian Restoran
  int _storeRating = 5;
  final _storeCommentCtrl = TextEditingController();
  List<String> _storePhotos = [];
  bool _storeReviewed = false;

  // Penilaian Kurir
  int _kurirRating = 5;
  final _kurirCommentCtrl = TextEditingController();
  List<String> _kurirPhotos = [];
  bool _kurirReviewed = false;

  bool _isSubmitting = false;
  bool _loadingStatus = true;
  final _picker = ImagePicker();

  bool get _hasKurir => widget.order.kurirId.isNotEmpty;
  bool get _allDone => _storeReviewed && (!_hasKurir || _kurirReviewed);

  @override
  void initState() {
    super.initState();
    _checkExistingReviews();
  }

  Future<void> _checkExistingReviews() async {
    final rp = context.read<ReviewProvider>();
    _storeReviewed = await rp.hasReviewedOrder(widget.order.id, ReviewTarget.store);
    _kurirReviewed = _hasKurir && await rp.hasReviewedOrder(widget.order.id, ReviewTarget.kurir);
    if (mounted) setState(() => _loadingStatus = false);
  }

  Future<void> _pickPhoto(bool isStore) async {
    final photos = isStore ? _storePhotos : _kurirPhotos;
    if (photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimal 3 foto')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Ambil Foto'),
            onTap: () async { Navigator.pop(context); await _getImage(ImageSource.camera, isStore); }),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Pilih dari Galeri'),
            onTap: () async { Navigator.pop(context); await _getImage(ImageSource.gallery, isStore); }),
        ]),
      ),
    );
  }

  Future<void> _getImage(ImageSource source, bool isStore) async {
    try {
      final img = await _picker.pickImage(source: source, maxWidth: 800, imageQuality: 70);
      if (img != null) {
        setState(() {
          if (isStore) _storePhotos.add(img.path);
          else _kurirPhotos.add(img.path);
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengambil foto')));
    }
  }

  // Kirim SEMUA penilaian yang belum dikirim sekaligus, dalam satu tombol.
  Future<void> _submitAll() async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final rp = context.read<ReviewProvider>();
    final myPhoto = auth.currentUser?.photoUrl ?? '';

    if (!_storeReviewed) {
      final review = Review(
        id: const Uuid().v4(), orderId: widget.order.id,
        memberId: auth.currentUser!.id, memberName: auth.currentUser!.name,
        targetId: widget.order.storeId, targetName: 'Restoran',
        target: ReviewTarget.store, rating: _storeRating,
        comment: _storeCommentCtrl.text, photoUrls: _storePhotos,
        memberPhotoUrl: myPhoto,
      );
      await rp.submitReview(review);
    }

    if (_hasKurir && !_kurirReviewed) {
      final review = Review(
        id: const Uuid().v4(), orderId: widget.order.id,
        memberId: auth.currentUser!.id, memberName: auth.currentUser!.name,
        targetId: widget.order.kurirId, targetName: widget.order.kurirName,
        target: ReviewTarget.kurir, rating: _kurirRating,
        comment: _kurirCommentCtrl.text, photoUrls: _kurirPhotos,
        memberPhotoUrl: myPhoto,
      );
      await rp.submitReview(review);
    }

    if (!mounted) return;
    setState(() { _storeReviewed = true; _kurirReviewed = true; _isSubmitting = false; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: IconText(Icons.check_circle, 'Terima kasih atas penilaianmu!'), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_allDone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Beri Penilaian')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 16),
          const Text('Sudah Dinilai!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const IconText(Icons.sentiment_satisfied_alt, 'Terima kasih atas penilaianmu', iconColor: Colors.amber, style: TextStyle(color: AppColors.textSecondary)),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Beri Penilaian')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text(
            'Nilai pengalamanmu — restoran dan kurir dikirim sekaligus lewat satu tombol di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          _buildSection(
            isStore: true,
            title: 'Bagaimana pengalaman berbelanja?',
            subtitle: 'Nilai kualitas makanan dan pelayanan restoran',
            icon: Icons.restaurant,
            color: AppColors.primary,
            rating: _storeRating,
            onRating: (r) => setState(() => _storeRating = r),
            commentCtrl: _storeCommentCtrl,
            photos: _storePhotos,
            isReviewed: _storeReviewed,
          ),

          const SizedBox(height: 20),

          if (_hasKurir)
            _buildSection(
              isStore: false,
              title: 'Bagaimana pelayanan kurir?',
              subtitle: 'Nilai kecepatan dan keramahan kurir',
              icon: Icons.delivery_dining,
              color: Colors.green,
              rating: _kurirRating,
              onRating: (r) => setState(() => _kurirRating = r),
              commentCtrl: _kurirCommentCtrl,
              photos: _kurirPhotos,
              isReviewed: _kurirReviewed,
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.divider.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.delivery_dining, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Expanded(child: Text('Belum ada kurir yang ditugaskan untuk pesanan ini, jadi cuma restoran yang bisa dinilai.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              ]),
            ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitAll,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Mengirim...' : 'Kirim Semua Penilaian', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildSection({
    required bool isStore,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int rating,
    required Function(int) onRating,
    required TextEditingController commentCtrl,
    required List<String> photos,
    required bool isReviewed,
  }) {
    if (isReviewed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(Icons.check_circle, color: color, size: 36),
          const SizedBox(height: 8),
          IconText(Icons.check_circle, isStore ? 'Restoran sudah dinilai' : 'Kurir sudah dinilai', iconColor: Colors.green, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
      );
    }

    return Column(children: [
      // Header
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
        ]),
      ),
      const SizedBox(height: 14),

      // Bintang Rating
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            rating > 0
              ? IconText(_ratingIcon(rating), _ratingLabel(rating), style: TextStyle(color: color, fontWeight: FontWeight.w600))
              : const SizedBox.shrink(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => onRating(i + 1),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < rating ? Colors.amber : AppColors.divider, size: 40),
                ),
              )),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // Komentar
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: commentCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: isStore ? 'Ceritakan pengalamanmu tentang makanan...' : 'Bagaimana keramahan kurirnya?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Foto
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const IconText(Icons.photo_camera, 'Tambah Foto (opsional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${photos.length}/3', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ...photos.asMap().entries.map((e) => Stack(children: [
                  Container(
                    width: 80, height: 80, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(e.value), fit: BoxFit.cover)),
                  ),
                  Positioned(top: 4, right: 14, child: GestureDetector(
                    onTap: () => setState(() { if (isStore) _storePhotos.removeAt(e.key); else _kurirPhotos.removeAt(e.key); }),
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 12)),
                  )),
                ])),
                if (photos.length < 3) GestureDetector(
                  onTap: () => _pickPhoto(isStore),
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(12), color: color.withOpacity(0.05)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo, color: color, size: 24),
                      const SizedBox(height: 4),
                      Text('Foto', style: TextStyle(color: color, fontSize: 10)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  String _ratingLabel(int r) => switch (r) {
    1 => 'Sangat Buruk', 2 => 'Buruk', 3 => 'Cukup',
    4 => 'Bagus', 5 => 'Luar Biasa!', _ => '',
  };

  IconData _ratingIcon(int r) => switch (r) {
    1 => Icons.sentiment_very_dissatisfied, 2 => Icons.sentiment_dissatisfied, 3 => Icons.sentiment_neutral,
    4 => Icons.sentiment_satisfied, 5 => Icons.sentiment_very_satisfied, _ => Icons.sentiment_neutral,
  };

  @override
  void dispose() { _storeCommentCtrl.dispose(); _kurirCommentCtrl.dispose(); super.dispose(); }
}
