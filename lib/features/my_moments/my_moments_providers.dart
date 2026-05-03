import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../core/firebase/providers.dart';
import '../../core/mock/mock_momentos.dart';
import '../../core/models/momento.dart';

/// Momentos hosted by the signed-in user.
final myOrganisedMomentosProvider = Provider<List<Momento>>((ref) {
  if (Env.useMockData) {
    final all = mockMomentos;
    return all.take(3).toList();
  }
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return const [];
  return ref
          .watch(_organisedStreamProvider(uid))
          .value ??
      const [];
});

/// Momentos liked by the signed-in user.
final myLikedMomentosProvider = Provider<List<Momento>>((ref) {
  if (Env.useMockData) {
    return mockMomentos.skip(2).take(4).toList();
  }
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return const [];
  return ref.watch(_likedStreamProvider(uid)).value ?? const [];
});

final _organisedStreamProvider =
    StreamProvider.family<List<Momento>, String>((ref, uid) {
  return ref.watch(momentoRepositoryProvider).watchByOrganizer(uid);
});

final _likedStreamProvider =
    StreamProvider.family<List<Momento>, String>((ref, uid) {
  return ref.watch(momentoRepositoryProvider).watchLikedBy(uid);
});
