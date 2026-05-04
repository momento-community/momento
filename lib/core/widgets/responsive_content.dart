import 'package:flutter/widgets.dart';

import '../../config/breakpoints.dart';
import '../../config/theme.dart';

/// Centered max-width content wrapper. Every screen body should sit inside
/// one of these so we don't get edge-to-edge sprawl on desktop.
///
/// Convention by intent:
///   * `560`  — auth, create form, sticky reserve bar (focused-input width)
///   * `720`  — Profile, MyMoments, MomentoDetail body (reading width)
///   * `1080` — Discover masonry, OrganizerDetail (gallery width)
///
/// Important: keep the parent scrollable viewport-wide and put the
/// `ResponsiveContent` *inside* each scroll item (per-sliver). That way
/// mouse-wheel scroll works in the empty side margins on desktop.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Picks a `crossAxisCount` based on the **constrained** width (NOT
/// `MediaQuery`). Wrap the masonry in a `LayoutBuilder` and pass
/// `constraints.maxWidth` here — that way a Profile masonry capped at
/// 720 px stays 2-col even on a 4K screen, while a Discover masonry capped
/// at 1080 fans out to 3 cols.
int adaptiveCols(double width) {
  if (width >= Breakpoints.wide) return 4;
  if (width >= Breakpoints.desktop) return 3;
  return 2; // 1-col looks anaemic with our card aspect ratio; 2 is the floor.
}
