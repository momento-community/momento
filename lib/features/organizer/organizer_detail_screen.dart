import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/models/momento.dart';
import '../../core/widgets/follow_button.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_card.dart';
import '../../core/widgets/slide_up_route.dart';
import '../discover/discover_providers.dart';
import '../momento_detail/momento_detail_screen.dart';

class OrganizerDetailScreen extends ConsumerWidget {
  const OrganizerDetailScreen({
    super.key,
    required this.organizerId,
    required this.fallbackName,
    required this.fallbackAvatarUrl,
  });

  final String organizerId;
  final String fallbackName;
  final String fallbackAvatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allMomentosProvider);
    final hosted =
        all.where((m) => m.organizerId == organizerId && m.isActive).toList();
    final name = hosted.isNotEmpty ? hosted.first.organizerName : fallbackName;
    final avatar =
        hosted.isNotEmpty ? hosted.first.organizerAvatarUrl : fallbackAvatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 700) Navigator.pop(context);
        },
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                organizerId: organizerId,
                name: name,
                avatarUrl: avatar,
                hostedCount: hosted.length,
                onClose: () => Navigator.pop(context),
              ),
              const Divider(color: AppColors.divider, height: 1),
              Expanded(
                child: hosted.isEmpty
                    ? _EmptyState(name: name)
                    : MasonryGridView.count(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.xl,
                        ),
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        itemCount: hosted.length,
                        itemBuilder: (_, i) {
                          final m = hosted[i];
                          final h = 150.0 + ((m.id.hashCode % 5) * 22);
                          return MomentoCard(
                            momento: m,
                            imageHeight: h,
                            onTap: () => Navigator.of(context)
                                .pushReplacement(
                              slideUpRoute(
                                  MomentoDetailScreen(momento: m)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.organizerId,
    required this.name,
    required this.avatarUrl,
    required this.hostedCount,
    required this.onClose,
  });

  final String organizerId;
  final String name;
  final String avatarUrl;
  final int hostedCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers =
        ref.watch(followerCountProvider(organizerId)).value ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.primaryText,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: const CircleBorder(),
                ),
                onPressed: onClose,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider, width: 2),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.surface),
                errorWidget: (_, _, _) =>
                    Container(color: AppColors.surface),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(name, style: AppText.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '$hostedCount active Momento${hostedCount == 1 ? '' : 's'} '
            '· $followers follower${followers == 1 ? '' : 's'}',
            style: AppText.labelSmall
                .copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FollowButton(organizerId: organizerId),
              const SizedBox(width: AppSpacing.sm),
              MomentoButton(
                label: 'Message',
                size: MomentoButtonSize.small,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text('$name has no active Momentos right now',
                textAlign: TextAlign.center,
                style: AppText.titleMedium),
          ],
        ),
      ),
    );
  }
}

extension OrganizerNav on Momento {
  void pushOrganizerDetail(BuildContext context) {
    Navigator.of(context).push(slideUpRoute(
      OrganizerDetailScreen(
        organizerId: organizerId,
        fallbackName: organizerName,
        fallbackAvatarUrl: organizerAvatarUrl,
      ),
    ));
  }
}
