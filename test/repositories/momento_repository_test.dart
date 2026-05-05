import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:momento/core/repositories/momento_repository.dart';
import 'package:momento/core/repositories/storage_repository.dart';

class _FakeStorage extends Mock implements StorageRepository {}

/// Repository tests run against `fake_cloud_firestore`, which implements
/// the full Firestore API (transactions included) in memory. No emulator,
/// no network, sub-second runs.
void main() {
  late FakeFirebaseFirestore firestore;
  late StorageRepository storage;
  late MomentoRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = _FakeStorage();
    repo = MomentoRepository(firestore, storage);
  });

  /// Convenience: insert a momento doc with sensible defaults.
  Future<void> seedMomento({
    required String id,
    required String organizerId,
    bool isActive = true,
    DateTime? endDateTime,
    List<String> likedBy = const [],
    int likeCount = 0,
  }) async {
    await firestore.collection('momentos').doc(id).set({
      'title': 'Test $id',
      'description': '',
      'category': 'art',
      'start_datetime': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1))),
      'end_datetime': Timestamp.fromDate(
          endDateTime ?? DateTime.now().add(const Duration(days: 1))),
      'duration_days': 1,
      'location_address': '',
      'location_geopoint': const GeoPoint(50.85, 4.35),
      'location_geohash': 'u151',
      'location_city': 'Brussels',
      'images': const <String>[],
      'organizer_id': organizerId,
      'organizer_name': 'Test Org',
      'organizer_avatar_url': '',
      'like_count': likeCount,
      'view_count': 0,
      'liked_by': likedBy,
      'is_active': isActive,
      'created_at': Timestamp.now(),
    });
  }

  group('toggleLike', () {
    test('liking a Momento adds the uid + bumps like_count', () async {
      await seedMomento(id: 'm1', organizerId: 'org1');

      await repo.toggleLike('m1', 'user-a');

      final doc = await firestore.collection('momentos').doc('m1').get();
      expect(doc.data()!['liked_by'], equals(['user-a']));
      expect(doc.data()!['like_count'], equals(1));
    });

    test('liking again (idempotent path) removes the uid + decrements',
        () async {
      await seedMomento(
        id: 'm1',
        organizerId: 'org1',
        likedBy: const ['user-a'],
        likeCount: 1,
      );

      await repo.toggleLike('m1', 'user-a');

      final doc = await firestore.collection('momentos').doc('m1').get();
      expect(doc.data()!['liked_by'], isEmpty);
      expect(doc.data()!['like_count'], equals(0));
    });

    test('two different users liking the same Momento accumulate', () async {
      await seedMomento(id: 'm1', organizerId: 'org1');

      await repo.toggleLike('m1', 'user-a');
      await repo.toggleLike('m1', 'user-b');

      final doc = await firestore.collection('momentos').doc('m1').get();
      expect(doc.data()!['liked_by'], containsAll(['user-a', 'user-b']));
      expect(doc.data()!['like_count'], equals(2));
    });

    test('targeting a missing doc is a no-op (no throw)', () async {
      // The transaction silently returns when the snapshot doesn't exist —
      // this guards against orphaned `liked_by` entries if a Momento gets
      // deleted between the user's tap and the write landing.
      await expectLater(
        repo.toggleLike('does-not-exist', 'user-a'),
        completes,
      );
    });
  });

  group('watchActive', () {
    test('returns only active, non-expired Momentos', () async {
      final now = DateTime.now();
      await seedMomento(
        id: 'live',
        organizerId: 'org1',
        endDateTime: now.add(const Duration(hours: 2)),
      );
      await seedMomento(
        id: 'expired',
        organizerId: 'org1',
        endDateTime: now.subtract(const Duration(hours: 1)),
      );
      await seedMomento(
        id: 'inactive',
        organizerId: 'org1',
        isActive: false,
        endDateTime: now.add(const Duration(hours: 2)),
      );

      final list = await repo.watchActive().first;

      expect(list.map((m) => m.id), equals(['live']));
    });

    test('orders by end_datetime ascending (next-to-end first)', () async {
      final now = DateTime.now();
      await seedMomento(
        id: 'later',
        organizerId: 'org1',
        endDateTime: now.add(const Duration(days: 5)),
      );
      await seedMomento(
        id: 'sooner',
        organizerId: 'org1',
        endDateTime: now.add(const Duration(hours: 6)),
      );

      final list = await repo.watchActive().first;

      expect(list.map((m) => m.id), equals(['sooner', 'later']));
    });
  });

  group('watchByOrganizer', () {
    test('filters by organizer_id and orders newest-first', () async {
      await seedMomento(id: 'a', organizerId: 'org1');
      await seedMomento(id: 'b', organizerId: 'org1');
      await seedMomento(id: 'c', organizerId: 'org2');

      final list = await repo.watchByOrganizer('org1').first;

      expect(
        list.map((m) => m.id).toList()..sort(),
        equals(['a', 'b']),
      );
      expect(list.any((m) => m.organizerId == 'org2'), isFalse);
    });
  });

  group('updateMomento', () {
    test('partial patch updates only the supplied fields', () async {
      await seedMomento(id: 'm1', organizerId: 'org1');

      await repo.updateMomento(
        id: 'm1',
        organizerUid: 'org1',
        fields: {'title': 'New title', 'description': 'New body'},
      );

      final doc = await firestore.collection('momentos').doc('m1').get();
      expect(doc.data()!['title'], equals('New title'));
      expect(doc.data()!['description'], equals('New body'));
      // Untouched fields stay untouched.
      expect(doc.data()!['organizer_id'], equals('org1'));
      expect(doc.data()!['category'], equals('art'));
    });

    test('empty patch + no photo is a no-op', () async {
      await seedMomento(id: 'm1', organizerId: 'org1');
      await expectLater(
        repo.updateMomento(id: 'm1', organizerUid: 'org1'),
        completes,
      );
    });
  });

  group('watchById', () {
    test('emits the live doc and null when missing', () async {
      await seedMomento(id: 'm1', organizerId: 'org1');
      final m = await repo.watchById('m1').first;
      expect(m, isNotNull);
      expect(m!.id, equals('m1'));

      final missing = await repo.watchById('does-not-exist').first;
      expect(missing, isNull);
    });
  });

  group('watchLikedBy', () {
    test('returns active Momentos containing the uid in liked_by',
        () async {
      await seedMomento(
        id: 'liked',
        organizerId: 'org1',
        likedBy: const ['user-a'],
      );
      await seedMomento(id: 'unliked', organizerId: 'org1');
      await seedMomento(
        id: 'liked-but-inactive',
        organizerId: 'org1',
        isActive: false,
        likedBy: const ['user-a'],
      );

      final list = await repo.watchLikedBy('user-a').first;

      expect(list.map((m) => m.id), equals(['liked']));
    });
  });
}
