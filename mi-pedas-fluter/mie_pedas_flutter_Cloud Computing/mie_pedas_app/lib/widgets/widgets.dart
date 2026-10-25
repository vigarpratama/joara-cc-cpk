// lib/widgets/widgets.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../utils/theme.dart';

// ==================== MENU CARD ====================
class MenuCard extends StatelessWidget {
  final Menu menu;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;

  const MenuCard({super.key, required this.menu, required this.onTap, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: menu.imageUrl.isNotEmpty
                      ? (menu.imageUrl.startsWith('/')
                          ? Image.file(File(menu.imageUrl), height: 110, width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder())
                          : Image.network(menu.imageUrl, height: 110, width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder()))
                      : _imagePlaceholder(),
                  ),
                  if (menu.isBestSeller)
                    Positioned(top: 8, left: 8, child: _badge('Best Seller', AppColors.primary)),
                  if (menu.isNew)
                    Positioned(top: 8, left: 8, child: _badge('Baru', AppColors.success)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(toRupiah(menu.price), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      if (onAddToCart != null)
                        GestureDetector(
                          onTap: onAddToCart,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text('${menu.rating} (${menu.totalReviews})', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

  Widget _imagePlaceholder() => Container(
    height: 110, width: double.infinity,
    color: AppColors.primaryLight.withOpacity(0.15),
    child: const Icon(Icons.ramen_dining, size: 50, color: AppColors.primaryLight),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

// ==================== ORDER STATUS CHIP ====================
class OrderStatusChip extends StatelessWidget {
  final OrderStatus status;
  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      OrderStatus.pending => (Colors.orange, Icons.hourglass_empty),
      OrderStatus.processing => (Colors.blue, Icons.restaurant),
      OrderStatus.ready => (Colors.green, Icons.check_circle_outline),
      OrderStatus.delivering => (AppColors.accent, Icons.delivery_dining),
      OrderStatus.delivered => (AppColors.success, Icons.done),
      OrderStatus.done => (Colors.grey, Icons.done_all),
      OrderStatus.cancelled => (AppColors.error, Icons.cancel),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(orderStatusLabel(status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==================== LOADING BUTTON ====================
class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final Color? color;

  const LoadingButton({super.key, required this.onPressed, required this.isLoading, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: color ?? AppColors.primary),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label),
      ),
    );
  }
}

// ==================== EMPTY STATE ====================
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.buttonLabel, this.onButton});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: AppColors.divider),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onButton, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== BANNER CARD ====================
class BannerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const BannerCard({super.key, required this.title, required this.subtitle, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Icon(icon, color: Colors.white.withOpacity(0.4), size: 64),
        ],
      ),
    );
  }
}

// ==================== ICON + TEXT (pengganti emoji) ====================
// Teks dengan ikon vector (Material Icons) di depannya, inline seperti Text biasa
// sehingga textAlign / maxLines / overflow tetap bekerja.
class IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle? style;
  final Color? iconColor;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  const IconText(this.icon, this.text, {
    super.key, this.style, this.iconColor, this.maxLines, this.overflow, this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final size = (base.fontSize ?? 14) * 1.25;
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(icon, size: size, color: iconColor ?? base.color),
        ),
        TextSpan(text: ' $text'),
      ]),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
