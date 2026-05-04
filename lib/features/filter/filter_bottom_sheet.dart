import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/models/momento_category.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/momento_button.dart';
import '../../shared/filter_state.dart';

Future<void> showFilterBottomSheet(BuildContext context) {
  // `constraints.maxWidth: 560` caps the sheet on tablet/desktop —
  // showModalBottomSheet defaults to viewport-wide which on a 1920 screen
  // makes the categories stretch awkwardly. The sheet is then centered
  // by the system (constraints.maxWidth < screen width).
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black.withValues(alpha: 0.27),
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  // Local working copy committed on Apply.
  late FilterState _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(filterStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          _Handle(),
          _Header(),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                _Section(title: 'CATEGORIES'),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: MomentoCategory.values.map((cat) {
                    final selected = _draft.categories.contains(cat);
                    return FilterChipPill(
                      label: cat.displayName,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          final next = {..._draft.categories};
                          selected ? next.remove(cat) : next.add(cat);
                          _draft = _draft.copyWith(categories: next);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  title: 'DISTANCE',
                  trailing: '${_draft.distanceKm.toStringAsFixed(1)} km',
                ),
                Slider(
                  value: _draft.distanceKm,
                  min: 0.5,
                  max: 50,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.divider,
                  onChanged: (v) =>
                      setState(() => _draft = _draft.copyWith(distanceKm: v)),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(title: 'TIME RANGE'),
                const SizedBox(height: AppSpacing.md),
                _TimeRangeRow(
                  start: _draft.timeStart,
                  end: _draft.timeEnd,
                  onTap: _pickTimeRange,
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(title: 'SORT BY'),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: SortBy.values.map((s) {
                    final selected = _draft.sortBy == s;
                    return Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(
                              () => _draft = _draft.copyWith(sortBy: s)),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.md),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              switch (s) {
                                SortBy.newest => 'Newest',
                                SortBy.popular => 'Popular',
                                SortBy.closest => 'Closest',
                              },
                              style: AppText.labelMedium.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                  top: BorderSide(color: AppColors.divider, width: 1)),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md +
                  MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: MomentoButton(
                    label: 'Reset',
                    variant: MomentoButtonVariant.ghost,
                    fullWidth: true,
                    onPressed: () =>
                        setState(() => _draft = FilterState.reset),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: MomentoButton(
                    label: 'Apply Filters',
                    variant: MomentoButtonVariant.primary,
                    size: MomentoButtonSize.large,
                    fullWidth: true,
                    onPressed: () {
                      ref
                          .read(filterStateProvider.notifier)
                          .replaceWith(_draft);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTimeRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _draft.timeStart != null
          ? DateTimeRange(
              start: _draft.timeStart!,
              end: _draft.timeEnd ?? _draft.timeStart!,
            )
          : null,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _draft =
          _draft.copyWith(timeStart: picked.start, timeEnd: picked.end);
    });
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text('Filter Momentos', style: AppText.titleLarge),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.primaryText,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              shape: const CircleBorder(),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppText.labelSmall.copyWith(
            color: AppColors.secondaryText,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: AppText.labelSmall
                .copyWith(color: AppColors.primary, letterSpacing: 0.5),
          ),
      ],
    );
  }
}

class _TimeRangeRow extends StatelessWidget {
  const _TimeRangeRow({
    required this.start,
    required this.end,
    required this.onTap,
  });

  final DateTime? start;
  final DateTime? end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            _TimeBlock(
              caption: 'Start',
              value: start == null ? 'Anytime' : fmt.format(start!),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 18, color: AppColors.secondaryText),
            ),
            _TimeBlock(
              caption: 'End',
              value: end == null
                  ? '+ 7 days'
                  : fmt.format(end!),
              alignEnd: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.caption,
    required this.value,
    this.alignEnd = false,
  });

  final String caption;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(caption,
              style: AppText.labelSmall
                  .copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: 2),
          Text(value,
              style: AppText.bodyMedium
                  .copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
