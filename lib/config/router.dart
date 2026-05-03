import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'env.dart';
import '../core/firebase/providers.dart';
import '../features/auth/auth_screen.dart';
import '../features/create/create_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/main_shell/main_shell.dart';
import '../features/map/map_screen.dart';
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
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
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
