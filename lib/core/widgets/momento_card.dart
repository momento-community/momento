import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../models/momento.dart';
import 'like_button.dart';

/// `@momento_card` from the design export — Pinterest-style card with
/// full-bleed top image, surface-coloured text section.
class MomentoCard extends StatelessWidget {
  const MomentoCard({
    super.key,
    required this.momento,
    this.onTap,
    this.imageHeight,
  });

  final Momento momento;
  final VoidCallback? onTap;

  /// Optional fixed image height. When null the image keeps its intrinsic
  /// aspect ratio (filled to column width). The masonry expects variable
  /// heights — pass values like 160/200/240 to mirror the design fixture.
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _humanDate(momento.startDateTime);
    final timeLabel = DateFormat.jm().format(momento.startDateTime);

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  imageHeight != null
                      ? SizedBox(
                          height: imageHeight,
                          child: _CardImage(url: momento.heroImage),
                        )
                      : AspectRatio(
                          aspectRatio: 4 / 5,
                          child: _CardImage(url: momento.heroImage),
                        ),
                  // Heart overlay — top right, sits above the image. Tapping
                  // toggles the like via Firestore transaction.
                  Positioned(
                    top: 8,
                    right: 8,
                    child: LikeButton(
                      momentoId: momento.id,
                      likedBy: momento.likedBy,
                      size: LikeButtonSize.compact,
                    ),
                  ),
                ],
              ),
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryBadge(label: momento.category.badge),
                    const SizedBox(height: 6),
                    Text(
                      momento.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelLarge.copyWith(
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel · $timeLabel',
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Stat(
                          icon: Icons.favorite_border_rounded,
                          value: momento.likeCount,
                        ),
                        const Spacer(),
                        _Avatar(url: momento.organizerAvatarUrl),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    // mem-cache the decoded bitmap at roughly card display size. Without
    // these, masonry mounts the source-resolution bitmap for every card
    // (often 2400px from the cover-photo upload) and memory balloons fast.
    // 600 covers retina display at the wide-desktop card sizes (~280px
    // logical) without obvious quality loss.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (300 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      memCacheWidth: cachePx,
      memCacheHeight: cachePx,
      placeholder: (_, __) => Container(color: AppColors.surface),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined,
            color: AppColors.primary.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: AppText.labelSmall.copyWith(
          color: AppColors.onSecondary,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.secondaryText),
        const SizedBox(width: 3),
        Text(
          _compact(value),
          style: AppText.labelSmall.copyWith(
            color: AppColors.secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.0,
          ),
        ),
      ],
    );
  }

  static String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 20,
        height: 20,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppColors.divider),
        errorWidget: (_, __, ___) => Container(color: AppColors.divider),
      ),
    );
  }
}

String _humanDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) return DateFormat.EEEE().format(dt);
  return DateFormat('MMM d').format(dt);
}
