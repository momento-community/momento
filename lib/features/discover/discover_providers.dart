import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../core/firebase/providers.dart';
import '../../core/mock/mock_momentos.dart';
import '../../core/models/momento.dart';
import '../../shared/filter_state.dart';

/// Active Momentos as a stream from Firestore (or mock when --dart-define
/// USE_MOCK_DATA=true). UI watches `discoverFeedProvider` for the filtered
/// view and falls back to the loading flag from this stream.
final allMomentosStreamProvider = StreamProvider<List<Momento>>((ref) {
  if (Env.useMockData) {
    return Stream.value(mockMomentos);
  }
  return ref.watch(momentoRepositoryProvider).watchActive();
});

/// Synchronous list view — empty while the stream is loading.
final allMomentosProvider = Provider<List<Momento>>((ref) {
  return ref.watch(allMomentosStreamProvider).value ?? const [];
});

/// Discover feed: applies the shared filter state to the source list.
final discoverFeedProvider = Provider<List<Momento>>((ref) {
  final all = ref.watch(allMomentosProvider);
  final filter = ref.watch(filterStateProvider);

  Iterable<Momento> out = all.where((m) => m.isActive);

  if (filter.categories.isNotEmpty) {
    out = out.where((m) => filter.categories.contains(m.category));
  }

  if (filter.timeStart != null) {
    final start = filter.timeStart!;
    final end = filter.timeEnd ?? start.add(const Duration(days: 7));
    out = out.where(
      (m) => m.startDateTime.isBefore(end) && m.endDateTime.isAfter(start),
    );
  }

  final list = out.toList();
  switch (filter.sortBy) {
    case SortBy.newest:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case SortBy.popular:
      list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    case SortBy.closest:
      // No location yet — fall back to newest.
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return list;
});
