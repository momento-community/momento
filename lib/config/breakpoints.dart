import 'package:flutter/widgets.dart';

/// Single source of truth for layout breakpoints. Used by `ResponsiveContent`,
/// `adaptiveCols`, `MainShell`'s nav switch, and the Phase 3 two-pane mode.
///
/// Values picked deliberately:
///   * 720  → "side-by-side feels comfortable" line (Material's default 600
///            still leaves narrow cards).
///   * 1080 → 3-col masonry starts to breathe.
///   * 1440 → 4-col masonry on Discover.
///   * 1600 → two-pane (Discover + MomentoDetail) activates. Picked so that
///            with the extended NavigationRail (~220) and a 50/50 split,
///            both panes get ≥ 690 px — wide enough for 2-col masonry on
///            the left and a comfortable detail on the right.
class Breakpoints {
  Breakpoints._();
  static const double tablet = 720;
  static const double desktop = 1080;
  static const double wide = 1440;
  static const double ultrawide = 1600;
}

extension BreakpointContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;
  bool get isTablet => _w >= Breakpoints.tablet && _w < Breakpoints.desktop;
  bool get isDesktop => _w >= Breakpoints.desktop;
  bool get isWide => _w >= Breakpoints.wide;
  bool get isUltrawide => _w >= Breakpoints.ultrawide;
  bool get isMobile => _w < Breakpoints.tablet;
}
