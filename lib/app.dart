import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/env.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'core/firebase/providers.dart';

class MomentoApp extends ConsumerWidget {
  const MomentoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Ensure the user doc exists right after sign-in so freemium counters
    // and rules-based reads (`get(/users/{uid}).data...`) succeed.
    ref.listen(authStateChangesProvider, (prev, next) {
      next.whenData((user) async {
        if (user == null) return;
        try {
          await ref.read(userRepositoryProvider).ensureUserDoc(user);
        } catch (_) {/* best-effort — surfaces on next write */}
      });
    });

    return MaterialApp.router(
      title: Env.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      scrollBehavior: const _NoScrollbarBehavior(),
    );
  }
}

/// App-wide ScrollBehavior that hides the platform scrollbar everywhere.
/// Flutter web/desktop attach a Material scrollbar to every Scrollable by
/// default — we want the Pinterest-style edge-to-edge feed with no bar.
/// Touch input keeps scroll-by-drag; mouse wheel still works.
class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
