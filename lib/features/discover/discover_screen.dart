import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/models/momento.dart';
import '../../core/widgets/momento_card.dart';
import '../../core/widgets/momento_logo.dart';
import '../../core/widgets/slide_up_route.dart';
import '../../shared/filter_state.dart';
import '../filter/filter_bottom_sheet.dart';
import '../momento_detail/momento_detail_screen.dart';
import 'discover_providers.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(allMomentosStreamProvider);
    final feed = ref.watch(discoverFeedProvider);
    final filter = ref.watch(filterStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(filter: filter),
            Expanded(
              child: stream.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Could not load Momentos.\n$e',
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ),
                data: (_) => feed.isEmpty
                    ? const _EmptyState()
                    : _MasonryFeed(items: feed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.filter});
  final FilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const MomentoLogo(),
          const Spacer(),
          _TimeSelectorPill(
            label: filter.isFilteringTime
                ? '${DateFormat('d MMM').format(filter.timeStart!)} ▾'
                : 'Now',
            onTap: () => _pickTime(context, ref),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.tune_rounded, size: 22),
            color: AppColors.primaryText,
            onPressed: () => showFilterBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.timeStart ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'When?',
    );
    if (picked == null) return;
    if (picked.day == now.day && picked.month == now.month) {
      ref.read(filterStateProvider.notifier).setTimeRange(null, null);
    } else {
      ref
          .read(filterStateProvider.notifier)
          .setTimeRange(picked, picked.add(const Duration(days: 1)));
    }
  }
}

class _TimeSelectorPill extends StatelessWidget {
  const _TimeSelectorPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.full),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.labelMedium),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.primaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasonryFeed extends StatelessWidget {
  const _MasonryFeed({required this.items});
  final List<Momento> items;

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        // Pseudo-random but stable per-id height to mimic the design fixture.
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

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: AppColors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.md),
          Text('No Momentos for this filter',
              style: AppText.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try widening the time range or removing categories.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall
                .copyWith(color: AppColors.secondaryText, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () =>
                ref.read(filterStateProvider.notifier).resetAll(),
            child: Text(
              'Clear filters',
              style:
                  AppText.labelLarge.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
