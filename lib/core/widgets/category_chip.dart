import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Single-select category chip used in the Create form. Selected: sage primary
/// bg + white text; unselected: surface + charcoal text.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.surface;
    final fg = selected ? AppColors.onPrimary : AppColors.primaryText;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: AppText.labelMedium.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Multi-select filter chip used inside the Filter bottom sheet. Same visual
/// language but its container handles the selected state externally.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CategoryChip(label: label, selected: selected, onTap: onTap);
  }
}
