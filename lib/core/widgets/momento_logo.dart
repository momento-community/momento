import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';

/// MOMENTŌ wordmark — Josefin Sans Light, wide tracking, all caps.
/// The macron Ō is the Unicode character U+014C (literal in the string).
class MomentoLogo extends StatelessWidget {
  const MomentoLogo({
    super.key,
    this.color = AppColors.primaryText,
    this.fontSize = 18,
    this.letterSpacing = 4.5,
  });

  final Color color;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      'MOMENTŌ',
      style: GoogleFonts.josefinSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.0,
      ),
    );
  }
}

/// Centre Ō badge used on bottom-nav and onboarding top-right corner.
class OBadge extends StatelessWidget {
  const OBadge({
    super.key,
    this.size = 48,
    this.filled = false,
    this.color,
  });

  final double size;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final bg = filled ? accent : accent.withValues(alpha: 0.10);
    final glyphColor = filled ? AppColors.onPrimary : accent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: filled ? null : Border.all(color: accent, width: 1),
        boxShadow: filled ? AppShadows.sm : null,
      ),
      alignment: Alignment.center,
      child: Text(
        'Ō',
        style: GoogleFonts.josefinSans(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w300,
          color: glyphColor,
          height: 1.0,
        ),
      ),
    );
  }
}
