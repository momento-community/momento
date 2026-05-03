import 'package:flutter/material.dart';

import '../../config/theme.dart';

enum MomentoButtonVariant { outline, primary, ghost, dark }

enum MomentoButtonSize { small, medium, large }

/// `@std.button` from the design export. White-bg/charcoal-border by default;
/// `primary` is the high-emphasis sage CTA (max one per screen).
class MomentoButton extends StatelessWidget {
  const MomentoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = MomentoButtonVariant.outline,
    this.size = MomentoButtonSize.medium,
    this.fullWidth = false,
    this.icon,
    this.iconColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final MomentoButtonVariant variant;
  final MomentoButtonSize size;
  final bool fullWidth;
  final IconData? icon;
  final Color? iconColor;

  double get _height => switch (size) {
        MomentoButtonSize.small => 36,
        MomentoButtonSize.medium => 48,
        MomentoButtonSize.large => 56,
      };

  EdgeInsets get _padding => switch (size) {
        MomentoButtonSize.small =>
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        MomentoButtonSize.medium =>
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        MomentoButtonSize.large =>
          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      MomentoButtonVariant.outline => (
          AppColors.background,
          AppColors.primaryText,
          AppColors.primaryText
        ),
      MomentoButtonVariant.primary => (
          AppColors.primary,
          AppColors.onPrimary,
          AppColors.primary
        ),
      MomentoButtonVariant.dark => (
          AppColors.primaryText,
          AppColors.background,
          AppColors.primaryText
        ),
      MomentoButtonVariant.ghost => (
          Colors.transparent,
          AppColors.secondaryText,
          Colors.transparent
        ),
    };

    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: iconColor ?? fg),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: AppText.bodyMedium.copyWith(
            color: fg,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    return SizedBox(
      height: _height,
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.full),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.full),
              border: Border.all(color: border, width: 1),
            ),
            padding: _padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
