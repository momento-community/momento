import 'package:flutter/widgets.dart';

/// Single source of truth for layout breakpoints. Used by `ResponsiveContent`,
/// `adaptiveCols`, and `MainShell`'s navigation switch (Phase 2).
///
/// Values picked deliberately:
///   * 720  → "side-by-side feels comfortable" line (Material's default 600
///            still leaves narrow cards).
///   * 1080 → 3-col masonry starts to breathe.
///   * 1440 → reserved for Phase 3 two-pane layouts.
class Breakpoints {
  Breakpoints._();
  static const double tablet = 720;
  static const double desktop = 1080;
  static const double wide = 1440;
}

extension BreakpointContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;
  bool get isTablet => _w >= Breakpoints.tablet && _w < Breakpoints.desktop;
  bool get isDesktop => _w >= Breakpoints.desktop;
  bool get isWide => _w >= Breakpoints.wide;
  bool get isMobile => _w < Breakpoints.tablet;
}
