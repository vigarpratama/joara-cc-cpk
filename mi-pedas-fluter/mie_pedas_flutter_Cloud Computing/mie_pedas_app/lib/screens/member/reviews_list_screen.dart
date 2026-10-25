// lib/screens/member/reviews_list_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class ReviewsListScreen extends StatefulWidget {
  final String targetId;
  final String targetName;
  final ReviewTarget target;
  const ReviewsListScreen({super.key, required this.targetId, required this.targetName, required this.target});
  @override
  State<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends State<ReviewsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ReviewProvider>().loadReviewsByTarget(widget.targetId));
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReviewProvider>();
    final avg = rp.avgRating;
    final reviews = rp.reviews;
    final dist = List.generate(5, (i) => reviews.where((r) => r.rating == 5 - i).length);

    return Scaffold(
      appBar: AppBar(title: Text('Ulasan ${widget.targetName}')),
      body: rp.isLoading
        ? const Center(child: CircularProgressIndicator())
        : reviews.isEmpty
          ? const EmptyState(icon: Icons.star_outline, title: 'Belum ada ulasan', subtitle: 'Jadilah yang pertama memberi penilaian!')
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        // Summary rating
                        Row(children: [
                          Column(children: [
                            Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            Row(children: List.generate(5, (i) => Icon(i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 18))),
                            Text('${reviews.length} ulasan', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ]),
                          const SizedBox(width: 20),
                          // Distribution bar
                          Expanded(child: Column(children: List.generate(5, (i) {
                            final count = dist[i];
                            final pct = reviews.isEmpty ? 0.0 : count / reviews.length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Text('${5 - i}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(width: 4),
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 6),
                                Expanded(child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(value: pct, backgroundColor: AppColors.divider, color: Colors.amber, minHeight: 8),
                                )),
                                const SizedBox(width: 6),
                                Text('$count', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ]),
                            );
                          }))),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
              SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _reviewCard(reviews[i]),
                childCount: reviews.length,
              )),
            ]),
    );
  }

  Widget _reviewCard(Review r) => Card(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          r.memberPhotoUrl.isNotEmpty
            ? CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: FileImage(File(r.memberPhotoUrl)),
                onBackgroundImageError: (_, __) {},
              )
            : CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(r.memberName[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.memberName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(formatDate(r.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ])),
          Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 16))),
        ]),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(r.comment, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
        if (r.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: r.photoUrls.map((path) => GestureDetector(
              onTap: () => _showFullImage(path),
              child: Container(
                width: 80, height: 80, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(path), fit: BoxFit.cover)),
              ),
            )).toList()),
          ),
        ],
      ]),
    ),
  );

  void _showFullImage(String path) => showDialog(
    context: context,
    builder: (_) => Dialog(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(path)))),
  );
}
