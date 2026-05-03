import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for Momentō's design tokens.
/// Mirrors `docs/design-export.md` — never inline hex codes outside this file.
class AppColors {
  AppColors._();

  // Light tokens
  static const Color primary = Color(0xFF8A9A5B); // sage
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF747A5E); // dark olive
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF1F1EC); // warm off-white
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF9E9E9E);
  static const Color hint = Color(0xFFE8E8E5);
  static const Color divider = Color(0xFFE8E8E5);
  static const Color error = Color(0xFFE63946);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF52B788);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadii {
  AppRadii._();
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double full = 9999;
}

class AppShadows {
  AppShadows._();
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F000000), offset: Offset(0, 2), blurRadius: 4),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 8),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x26000000), offset: Offset(0, 8), blurRadius: 16),
  ];
  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x33000000), offset: Offset(0, 12), blurRadius: 24),
  ];
}

/// Typography. Cormorant Garamond for display/titles, DM Sans for everything
/// else. Josefin Sans Light is reserved for the "MOMENTŌ" wordmark only.
class AppText {
  AppText._();

  static TextStyle get _cormorant => GoogleFonts.cormorantGaramond();
  static TextStyle get _dmSans => GoogleFonts.dmSans();
  static TextStyle get josefin =>
      GoogleFonts.josefinSans(fontWeight: FontWeight.w300);

  static TextStyle get headlineLarge => _cormorant.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: AppColors.primaryText,
      );

  static TextStyle get headlineMedium => _cormorant.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.primaryText,
      );

  static TextStyle get headlineSmall => _cormorant.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.primaryText,
      );

  static TextStyle get titleLarge => _cormorant.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.primaryText,
      );

  static TextStyle get titleMedium => _dmSans.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.primaryText,
      );

  static TextStyle get titleSmall => _dmSans.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.primaryText,
      );

  static TextStyle get bodyLarge => _dmSans.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.primaryText,
      );

  static TextStyle get bodyMedium => _dmSans.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.primaryText,
      );

  static TextStyle get bodySmall => _dmSans.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.primaryText,
      );

  static TextStyle get labelLarge => _dmSans.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.primaryText,
      );

  static TextStyle get labelMedium => _dmSans.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.primaryText,
      );

  static TextStyle get labelSmall => _dmSans.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.primaryText,
      );
}

ThemeData buildAppTheme() {
  final colorScheme = const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    surface: AppColors.background,
    onSurface: AppColors.primaryText,
    surfaceContainerHighest: AppColors.surface,
    error: AppColors.error,
    onError: AppColors.onError,
    outline: AppColors.divider,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.divider,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      headlineLarge: AppText.headlineLarge,
      headlineMedium: AppText.headlineMedium,
      headlineSmall: AppText.headlineSmall,
      titleLarge: AppText.titleLarge,
      titleMedium: AppText.titleMedium,
      titleSmall: AppText.titleSmall,
      bodyLarge: AppText.bodyLarge,
      bodyMedium: AppText.bodyMedium,
      bodySmall: AppText.bodySmall,
      labelLarge: AppText.labelLarge,
      labelMedium: AppText.labelMedium,
      labelSmall: AppText.labelSmall,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.background,
      foregroundColor: AppColors.primaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: AppText.bodyMedium.copyWith(color: AppColors.secondaryText),
    ),
  );
}
