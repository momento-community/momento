import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'env.dart';
import '../core/firebase/providers.dart';
import '../features/admin/admin_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/create/create_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/main_shell/main_shell.dart';
import '../features/map/map_screen.dart';
import '../features/momento_detail/momento_detail_route.dart';
import '../features/my_moments/my_moments_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final refresh = _GoRouterRefreshStream(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (ctx, state) {
      // In mock-data builds (e2e + offline UI dev) the auth gate is wide
      // open. Production builds can never set USE_MOCK_DATA=true unless the
      // pipeline is misconfigured.
      if (Env.useMockData) return null;
      final loc = state.matchedLocation;
      final user = auth.currentUser;
      final unauthed = user == null;
      final inOpenZone =
          loc == '/splash' || loc == '/onboarding' || loc == '/auth';
      if (unauthed && !inOpenZone) return '/auth';
      // /admin is admin-only — non-admins land back on /discover.
      if (loc == '/admin') {
        final doc = ref.read(currentUserDocProvider).value;
        final role = (doc?.data()?['role'] as String?) ?? 'user';
        if (role != 'admin') return '/discover';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      // /admin lives outside the bottom-nav shell — it's a full-screen
      // operator surface. Redirect above gates non-admins.
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      // Deep link / share target. Lives outside the bottom-nav shell —
      // it's a focused full-screen view of a single Momento, the URL
      // people copy-paste. In-app navigation from Discover / Map keeps
      // its existing slide-up modal (single-pane) and embedded right
      // pane (ultra-wide) so this route doesn't disturb either flow.
      GoRoute(
        path: '/momento/:id',
        builder: (_, state) =>
            MomentoDetailRoute(id: state.pathParameters['id']!),
      ),
      // Public profile / organisor page. `/u/{uid}` is the canonical
      // shareable URL for any user. The screen reads the live
      // `users/{uid}` doc — so name/avatar are always fresh, even when
      // the organisor changed them after a Momento was created. When
      // the path-id matches the signed-in uid, the screen still renders
      // self mode (inline edits, freemium card, logout) so the URL is
      // copy-paste safe for the user themselves too.
      GoRoute(
        path: '/u/:id',
        builder: (_, state) =>
            ProfileScreen(userId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/discover',
                builder: (_, __) => const DiscoverScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/my-moments',
                builder: (_, __) => const MyMomentsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/create', builder: (_, __) => const CreateScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<User?> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
