// lib/screens/member/track_order_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../utils/database_helper.dart';
import '../shared/chat_screen.dart';
import '../../widgets/widgets.dart';

class TrackOrderScreen extends StatefulWidget {
  final Order order;
  const TrackOrderScreen({super.key, required this.order});
  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  Timer? _timer;
  Order? _order;
  String? _kurirPhotoUrl;

  final List<Map<String, dynamic>> _journey = [
    {'label': 'Pesanan Diterima', 'desc': 'Restoran menerima pesananmu', 'icon': Icons.receipt_long, 'status': OrderStatus.pending},
    {'label': 'Sedang Dimasak', 'desc': 'Koki sedang menyiapkan pesananmu', 'icon': Icons.restaurant, 'status': OrderStatus.processing},
    {'label': 'Siap Diantar', 'desc': 'Pesanan siap, menunggu kurir', 'icon': Icons.check_circle_outline, 'status': OrderStatus.ready},
    {'label': 'Kurir Menuju Lokasimu', 'desc': 'Kurir dalam perjalanan ke rumahmu', 'icon': Icons.delivery_dining, 'status': OrderStatus.delivering},
    {'label': 'Pesanan Tiba!', 'desc': 'Pesanan telah sampai di lokasimu', 'icon': Icons.home, 'status': OrderStatus.delivered},
  ];

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadKurirPhoto();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshOrder());
  }

  Future<void> _loadKurirPhoto() async {
    final kurirId = _order?.kurirId ?? '';
    if (kurirId.isEmpty) return;
    final kurir = await DatabaseHelper().getUserById(kurirId);
    if (mounted) setState(() => _kurirPhotoUrl = kurir?.photoUrl);
  }

  Future<void> _refreshOrder() async {
    if (!mounted) return;
    final orders = context.read<OrderProvider>();
    await orders.loadMemberOrders(widget.order.memberId);
    final updated = orders.orders.where((o) => o.id == widget.order.id).firstOrNull;
    if (updated != null && mounted) {
      final kurirChanged = updated.kurirId != _order?.kurirId;
      setState(() => _order = updated);
      if (kurirChanged) _loadKurirPhoto();
    }
  }

  int get _currentStep {
    final status = _order?.orderStatus ?? OrderStatus.pending;
    for (int i = 0; i < _journey.length; i++) {
      if (_journey[i]['status'] == status) return i;
    }
    return 0;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final o = _order ?? widget.order;
    final step = _currentStep;
    final isDelivering = o.orderStatus == OrderStatus.delivering;
    final isDone = o.orderStatus == OrderStatus.delivered || o.orderStatus == OrderStatus.done;
    final isCancelled = o.orderStatus == OrderStatus.cancelled;
    final hasKurir = o.kurirId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak Pesanan'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshOrder),
          // Tombol chat — hanya muncul kalau kurir sudah ada
          if (hasKurir)
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: 'Chat dengan Kurir',
              onPressed: () {
                final auth = context.read<AuthProvider>();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    orderId: o.id,
                    memberName: o.memberName,
                    kurirName: o.kurirName,
                    isKurir: false,
                    memberPhotoUrl: auth.currentUser?.photoUrl,
                    memberPhone: auth.currentUser?.phone,
                    kurirPhotoUrl: _kurirPhotoUrl,
                    kurirPhone: o.kurirPhone,
                  ),
                ));
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // Visual peta
          Container(
            height: 220, width: double.infinity,
            color: Colors.grey.shade200,
            child: Stack(children: [
              CustomPaint(size: const Size(double.infinity, 220), painter: _MapPainter(step: step, isDone: isDone)),
              Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (isDelivering) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
                      child: const Icon(Icons.delivery_dining, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                      child: IconText(Icons.two_wheeler, '${o.kurirName.isNotEmpty ? o.kurirName : "Kurir"} menuju lokasimu',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ] else if (isDone) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
                      child: const Icon(Icons.check_circle, color: AppColors.success, size: 40),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const IconText(Icons.check_circle, 'Pesanan telah tiba!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success)),
                    ),
                  ] else if (isCancelled) ...[
                    const Icon(Icons.cancel, color: AppColors.error, size: 48),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const IconText(Icons.cancel, 'Pesanan dibatalkan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
                      child: const Icon(Icons.restaurant, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const IconText(Icons.ramen_dining, 'Pesanan sedang disiapkan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ]),
              ),
              Positioned(bottom: 12, left: 16, child: _mapLabel('Restoran', Icons.storefront, AppColors.primary)),
              Positioned(bottom: 12, right: 16, child: _mapLabel('Rumahmu', Icons.home, Colors.green)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Tombol chat besar (kalau kurir sudah ada)
              if (hasKurir && !isDone && !isCancelled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            orderId: o.id,
                            memberName: o.memberName,
                            kurirName: o.kurirName,
                            isKurir: false,
                            memberPhotoUrl: auth.currentUser?.photoUrl,
                            memberPhone: auth.currentUser?.phone,
                    kurirPhotoUrl: _kurirPhotoUrl,
                    kurirPhone: o.kurirPhone,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.chat_outlined),
                      label: Text('Chat dengan ${o.kurirName}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

              // Info pesanan
              Card(
                child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                    Text(toRupiah(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
                  ]),
                  if (o.storeName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: o.storePhotoUrl.isNotEmpty ? FileImage(File(o.storePhotoUrl)) : null,
                        child: o.storePhotoUrl.isEmpty ? const Icon(Icons.storefront, size: 14, color: AppColors.primary) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(o.storeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ],
                  const Divider(height: 12),
                  Row(children: [
                    const Icon(Icons.location_on, color: AppColors.error, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(o.deliveryAddress, style: const TextStyle(fontSize: 13), maxLines: 2)),
                  ]),
                  if (o.kurirName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.delivery_dining, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text('Kurir: ${o.kurirName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  ],
                ])),
              ),

              const SizedBox(height: 16),

              // Timeline
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Status Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 16),
                    ...List.generate(_journey.length, (i) {
                      final done = i <= step && !isCancelled;
                      final current = i == step && !isCancelled;
                      return _timelineItem(
                        label: _journey[i]['label'], desc: _journey[i]['desc'],
                        icon: _journey[i]['icon'], isDone: done, isCurrent: current,
                        isLast: i == _journey.length - 1,
                      );
                    }),
                  ]),
                ),
              ),

              if (!isDone && !isCancelled) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.access_time, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Estimasi Waktu', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text(isDelivering ? '±10-15 menit lagi' : '±${o.estimatedTime} menit',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]),
                    const Spacer(),
                    const IconText(Icons.autorenew, 'Auto refresh', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _mapLabel(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
    child: IconText(icon, label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _timelineItem({required String label, required String desc, required IconData icon, required bool isDone, required bool isCurrent, required bool isLast}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isDone ? AppColors.primary : AppColors.divider,
            shape: BoxShape.circle,
            boxShadow: isCurrent ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)] : [],
          ),
          child: Icon(icon, color: isDone ? Colors.white : AppColors.textSecondary, size: 18),
        ),
        if (!isLast) Container(width: 2, height: 40, color: isDone ? AppColors.primary : AppColors.divider),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, fontSize: 14,
            color: isDone ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (isCurrent) Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: const Text('Sekarang', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      )),
    ]);
  }
}

class _MapPainter extends CustomPainter {
  final int step;
  final bool isDone;
  const _MapPainter({required this.step, required this.isDone});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFE8F5E9));
    final roadPaint = Paint()..color = Colors.white..strokeWidth = 20..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(40, size.height / 2), Offset(size.width - 40, size.height / 2), roadPaint);
    for (double x = 60; x < size.width - 60; x += 30) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 15, size.height / 2),
        Paint()..color = Colors.amber..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }
    if (step > 0) {
      final progress = (step / 4).clamp(0.0, 1.0);
      canvas.drawLine(Offset(40, size.height / 2), Offset(40 + (size.width - 80) * progress, size.height / 2),
        Paint()..color = AppColors.primary.withOpacity(0.6)..strokeWidth = 8..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(Offset(40, size.height / 2), 14, Paint()..color = AppColors.primary);
    canvas.drawCircle(Offset(size.width - 40, size.height / 2), 14, Paint()..color = isDone ? AppColors.success : Colors.green.shade400);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
