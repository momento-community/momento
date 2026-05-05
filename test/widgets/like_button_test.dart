import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:momento/core/firebase/providers.dart';
import 'package:momento/core/repositories/momento_repository.dart';
import 'package:momento/core/widgets/like_button.dart';

class _FakeUser extends Mock implements User {}

class _FakeMomentoRepository extends Mock implements MomentoRepository {}

void main() {
  late _FakeMomentoRepository repo;
  late _FakeUser user;

  setUp(() {
    repo = _FakeMomentoRepository();
    user = _FakeUser();
    when(() => user.uid).thenReturn('user-a');
  });

  /// Pump a LikeButton inside a ProviderScope with the auth + repo
  /// providers overridden so we can observe the optimistic flip and
  /// failure-revert without touching real Firebase.
  Future<void> pump(
    WidgetTester tester, {
    required List<String> likedBy,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider
              .overrideWith((_) => Stream<User?>.value(user)),
          momentoRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LikeButton(momentoId: 'm1', likedBy: likedBy),
          ),
        ),
      ),
    );
    // Drain the auth stream so the widget sees the user.
    await tester.pump();
  }

  testWidgets('renders outline heart when not liked', (tester) async {
    await pump(tester, likedBy: const []);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('renders filled heart when current user is in liked_by',
      (tester) async {
    await pump(tester, likedBy: const ['user-a']);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });

  testWidgets('optimistically flips to filled on tap, then commits',
      (tester) async {
    when(() => repo.toggleLike(any(), any())).thenAnswer((_) async {});
    await pump(tester, likedBy: const []);

    await tester.tap(find.byType(LikeButton));
    // First pump: SetState applies the optimistic flip BEFORE the
    // Firestore call resolves.
    await tester.pump();

    expect(
      find.byIcon(Icons.favorite_rounded),
      findsOneWidget,
      reason: 'optimistic flip should fill the heart immediately',
    );
    verify(() => repo.toggleLike('m1', 'user-a')).called(1);
  });

  testWidgets('reverts the optimistic flip + shows snackbar on error',
      (tester) async {
    when(() => repo.toggleLike(any(), any()))
        .thenThrow(Exception('network down'));
    await pump(tester, likedBy: const []);

    await tester.tap(find.byType(LikeButton));
    // Two pumps: first commits the optimistic flip, second processes the
    // synchronous throw + revert.
    await tester.pump();
    await tester.pump();

    expect(
      find.byIcon(Icons.favorite_border_rounded),
      findsOneWidget,
      reason: 'failure should revert the heart back to outline',
    );
    expect(find.text('Could not update like — try again.'), findsOneWidget);
  });

  testWidgets('signed-out user: tap is a no-op (onTap == null)',
      (tester) async {
    // Mount directly without the helper, since the helper's
    // `overrideUser ?? user` fallback would substitute the default
    // authed user when a `null` user is what we want to test.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider
              .overrideWith((_) => Stream<User?>.value(null)),
          momentoRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LikeButton(momentoId: 'm1', likedBy: []),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(LikeButton));
    await tester.pump();

    verifyNever(() => repo.toggleLike(any(), any()));
  });
}
