import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Underline-style segmented tabs used by My Moments and Profile.
class SectionTabs extends StatelessWidget {
  const SectionTabs({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final active = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  labels[i],
                  style: AppText.titleSmall.copyWith(
                    color: active
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color:
                        active ? AppColors.primary : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppRadii.full),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
