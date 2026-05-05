import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momento/core/widgets/responsive_content.dart';

void main() {
  group('adaptiveCols', () {
    test('returns 2 below desktop breakpoint', () {
      expect(adaptiveCols(0), 2);
      expect(adaptiveCols(393), 2); // iPhone
      expect(adaptiveCols(720), 2); // tablet floor
      expect(adaptiveCols(1079), 2); // just under desktop
    });

    test('returns 3 from desktop to wide', () {
      expect(adaptiveCols(1080), 3); // exactly the desktop breakpoint
      expect(adaptiveCols(1280), 3);
      expect(adaptiveCols(1439), 3);
    });

    test('returns 4 at wide and above', () {
      expect(adaptiveCols(1440), 4);
      expect(adaptiveCols(1920), 4);
      expect(adaptiveCols(3840), 4); // 4K
    });
  });

  group('ResponsiveContent', () {
    testWidgets('caps the child width at maxWidth on a wide viewport',
        (tester) async {
      // Force a 2000-wide viewport so the cap is the binding constraint.
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const childKey = Key('child');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContent(
              maxWidth: 720,
              padding: EdgeInsets.zero,
              child: SizedBox.expand(key: childKey),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(childKey));
      // Padding is zero — child width must equal the cap exactly.
      expect(size.width, 720);
    });

    testWidgets('does not over-stretch on a viewport narrower than maxWidth',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const childKey = Key('child');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContent(
              maxWidth: 720,
              padding: EdgeInsets.zero,
              child: SizedBox.expand(key: childKey),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(childKey));
      // Viewport (400) < maxWidth (720) ⇒ child fills viewport.
      expect(size.width, 400);
    });

    testWidgets('horizontally centres the child on a wide viewport',
        (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const childKey = Key('child');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContent(
              maxWidth: 720,
              padding: EdgeInsets.zero,
              child: SizedBox.expand(key: childKey),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(childKey));
      final leftMargin = rect.left;
      final rightMargin = 2000 - rect.right;
      // Allow 1 px slop for sub-pixel rounding.
      expect((leftMargin - rightMargin).abs(), lessThan(1.5));
    });
  });
}
