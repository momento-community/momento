import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/models/momento.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_card.dart';
import '../../core/widgets/momento_logo.dart';
import '../../core/widgets/section_tabs.dart';
import '../../core/widgets/slide_up_route.dart';
import '../momento_detail/momento_detail_screen.dart';
import 'my_moments_providers.dart';

class MyMomentsScreen extends ConsumerStatefulWidget {
  const MyMomentsScreen({super.key});

  @override
  ConsumerState<MyMomentsScreen> createState() => _MyMomentsScreenState();
}

class _MyMomentsScreenState extends ConsumerState<MyMomentsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final organised = ref.watch(myOrganisedMomentosProvider);
    final liked = ref.watch(myLikedMomentosProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MomentoLogo(),
                  const SizedBox(height: AppSpacing.sm),
                  Text('My Moments', style: AppText.headlineMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg),
              child: SectionTabs(
                labels: const ['Organised', 'Liked'],
                activeIndex: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: _tab == 0
                  ? _OrganisedTab(items: organised)
                  : _LikedTab(items: liked),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganisedTab extends StatelessWidget {
  const _OrganisedTab({required this.items});
  final List<Momento> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _OrganisedEmpty();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) {
        if (i == items.length) return const _CreateAnotherCard();
        return _MomentoListItem(momento: items[i]);
      },
    );
  }
}

class _MomentoListItem extends StatelessWidget {
  const _MomentoListItem({required this.momento});
  final Momento momento;

  @override
  Widget build(BuildContext context) {
    final expired = momento.isExpired;
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => Navigator.of(context).push(
          slideUpRoute(MomentoDetailScreen(momento: momento)),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: CachedNetworkImage(
                  imageUrl: momento.heroImage,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: AppColors.surface),
                  errorWidget: (_, _, _) =>
                      Container(color: AppColors.surface),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      momento.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, y').format(momento.startDateTime),
                      style: AppText.bodySmall
                          .copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatusBadge(active: !expired),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.hint,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        active ? 'Active' : 'Expired',
        style: AppText.labelSmall.copyWith(
          color:
              active ? AppColors.onPrimary : AppColors.secondaryText,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CreateAnotherCard extends StatelessWidget {
  const _CreateAnotherCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.local_florist_outlined,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.7)),
          const SizedBox(height: AppSpacing.md),
          Text('Ready to host another?', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.md),
          MomentoButton(
            label: 'Create New Momento',
            icon: Icons.add_rounded,
            onPressed: () => GoRouter.of(context).go('/create'),
          ),
        ],
      ),
    );
  }
}

class _OrganisedEmpty extends StatelessWidget {
  const _OrganisedEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_outlined,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.md),
          Text('No Momentos yet', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your hosted Momentos will show up here.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall
                .copyWith(color: AppColors.secondaryText, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          MomentoButton(
            label: 'Create your first Momentō',
            icon: Icons.add_rounded,
            onPressed: () => GoRouter.of(context).go('/create'),
          ),
        ],
      ),
    );
  }
}

class _LikedTab extends StatelessWidget {
  const _LikedTab({required this.items});
  final List<Momento> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text('Your liked Momentos appear here',
                textAlign: TextAlign.center,
                style: AppText.titleMedium),
          ],
        ),
      );
    }
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        final h = 150.0 + ((m.id.hashCode % 5) * 22);
        return MomentoCard(
          momento: m,
          imageHeight: h,
          onTap: () => Navigator.of(context).push(
            slideUpRoute(MomentoDetailScreen(momento: m)),
          ),
        );
      },
    );
  }
}
