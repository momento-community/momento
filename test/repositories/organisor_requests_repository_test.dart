import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momento/core/repositories/organisor_requests_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late OrganisorRequestsRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = OrganisorRequestsRepository(firestore);
  });

  Future<void> seedUser(String uid, {String role = 'user'}) async {
    await firestore.collection('users').doc(uid).set({
      'role': role,
      'email': '$uid@example.com',
      'display_name': 'Test',
    });
  }

  group('submit', () {
    test('first-time submit creates a pending doc with denormalised fields',
        () async {
      await seedUser('u1');

      await repo.submit(
        uid: 'u1',
        userEmail: 'u1@example.com',
        userDisplayName: 'Alice',
        userAvatarUrl: 'https://avatars/a.jpg',
      );

      final snap = await firestore.collection('organisor_requests').doc('u1').get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['status'], equals('pending'));
      expect(snap.data()!['user_email'], equals('u1@example.com'));
      expect(snap.data()!['user_display_name'], equals('Alice'));
      expect(snap.data()!['user_avatar_url'], equals('https://avatars/a.jpg'));
      expect(snap.data()!['decided_at'], isNull);
    });

    test('re-submit after rejection rewrites the doc back to pending',
        () async {
      await seedUser('u1');
      // Seed a previously-rejected request.
      await firestore.collection('organisor_requests').doc('u1').set({
        'status': 'rejected',
        'requested_at': Timestamp.now(),
        'decided_at': Timestamp.now(),
        'decided_by': 'admin',
        'decided_reason': 'Try again next month',
        'user_email': 'old@example.com',
        'user_display_name': 'Old Name',
        'user_avatar_url': null,
      });

      await repo.submit(
        uid: 'u1',
        userEmail: 'u1@example.com',
        userDisplayName: 'Alice',
      );

      final snap = await firestore.collection('organisor_requests').doc('u1').get();
      expect(snap.data()!['status'], equals('pending'));
      expect(snap.data()!['decided_at'], isNull);
      expect(snap.data()!['decided_by'], isNull);
      expect(snap.data()!['decided_reason'], isNull);
      expect(snap.data()!['user_email'], equals('u1@example.com'));
      expect(snap.data()!['user_display_name'], equals('Alice'));
    });
  });

  group('approve', () {
    test('flips request status AND promotes user role atomically',
        () async {
      await seedUser('u1');
      await repo.submit(
        uid: 'u1',
        userEmail: 'u1@example.com',
        userDisplayName: 'Alice',
      );

      await repo.approve(uid: 'u1', adminUid: 'admin1');

      final reqSnap =
          await firestore.collection('organisor_requests').doc('u1').get();
      final userSnap = await firestore.collection('users').doc('u1').get();
      expect(reqSnap.data()!['status'], equals('approved'));
      expect(reqSnap.data()!['decided_by'], equals('admin1'));
      expect(reqSnap.data()!['decided_reason'], isNull);
      expect(userSnap.data()!['role'], equals('organisor'));
    });
  });

  group('reject', () {
    test('flips status to rejected with reason; user role unchanged',
        () async {
      await seedUser('u1');
      await repo.submit(
        uid: 'u1',
        userEmail: 'u1@example.com',
        userDisplayName: 'Alice',
      );

      await repo.reject(
        uid: 'u1',
        adminUid: 'admin1',
        reason: 'Need more context',
      );

      final reqSnap =
          await firestore.collection('organisor_requests').doc('u1').get();
      final userSnap = await firestore.collection('users').doc('u1').get();
      expect(reqSnap.data()!['status'], equals('rejected'));
      expect(reqSnap.data()!['decided_by'], equals('admin1'));
      expect(reqSnap.data()!['decided_reason'], equals('Need more context'));
      expect(userSnap.data()!['role'], equals('user'));
    });
  });

  group('watchPending', () {
    test('emits only pending requests, oldest first', () async {
      await seedUser('a');
      await seedUser('b');
      await seedUser('c');

      // Mix of pending + already-decided requests, in scrambled time order.
      final now = DateTime.now();
      await firestore.collection('organisor_requests').doc('a').set({
        'status': 'pending',
        'requested_at': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'user_email': 'a@x',
        'user_display_name': 'A',
      });
      await firestore.collection('organisor_requests').doc('b').set({
        'status': 'approved',
        'requested_at': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'user_email': 'b@x',
        'user_display_name': 'B',
      });
      await firestore.collection('organisor_requests').doc('c').set({
        'status': 'pending',
        'requested_at': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'user_email': 'c@x',
        'user_display_name': 'C',
      });

      final list = await repo.watchPending().first;
      expect(list.map((r) => r.uid), equals(['c', 'a']));
    });
  });
}
