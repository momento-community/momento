import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momento/core/repositories/user_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = UserRepository(firestore);
  });

  Future<void> seedUser(
    String uid, {
    String role = 'organisor',
    String displayName = 'Old Name',
    String avatar = 'https://old.example/a.jpg',
  }) async {
    await firestore.collection('users').doc(uid).set({
      'display_name': displayName,
      'email': '$uid@example.com',
      'avatar_url': avatar,
      'bio': '',
      'location_city': '',
      'role': role,
      'is_premium': false,
      'is_banned': false,
      'freemium_used': 0,
      'momentos_organized_count': 0,
      'created_at': Timestamp.now(),
    });
  }

  Future<String> seedMomento(
    String organizerUid, {
    String name = 'Old Name',
    String avatar = 'https://old.example/a.jpg',
  }) async {
    final ref = firestore.collection('momentos').doc();
    await ref.set({
      'title': 'Test',
      'organizer_id': organizerUid,
      'organizer_name': name,
      'organizer_avatar_url': avatar,
      'is_active': true,
      'like_count': 0,
      'liked_by': const <String>[],
      'created_at': Timestamp.now(),
    });
    return ref.id;
  }

  group('updateProfile fan-out', () {
    test('avatar_url change patches every Momento by that organizer',
        () async {
      await seedUser('org1');
      final m1 = await seedMomento('org1');
      final m2 = await seedMomento('org1');
      // Another organizer's momento should NOT be touched.
      final mOther = await seedMomento('org2', avatar: 'https://other.x/b.jpg');

      const newUrl = 'https://new.example/avatar.jpg';
      await repo.updateProfile('org1', {'avatar_url': newUrl});

      final after1 = await firestore.collection('momentos').doc(m1).get();
      final after2 = await firestore.collection('momentos').doc(m2).get();
      final afterOther =
          await firestore.collection('momentos').doc(mOther).get();
      expect(after1.data()!['organizer_avatar_url'], equals(newUrl));
      expect(after2.data()!['organizer_avatar_url'], equals(newUrl));
      expect(
        afterOther.data()!['organizer_avatar_url'],
        equals('https://other.x/b.jpg'),
      );
    });

    test('display_name change patches organizer_name on owned Momentos',
        () async {
      await seedUser('org1');
      final m1 = await seedMomento('org1');

      await repo.updateProfile('org1', {'display_name': 'Brand New Name'});

      final after = await firestore.collection('momentos').doc(m1).get();
      expect(after.data()!['organizer_name'], equals('Brand New Name'));
    });

    test('bio-only / city-only patch does NOT trigger fan-out reads',
        () async {
      await seedUser('org1');
      final m1 = await seedMomento('org1');

      // No matter what, the denormalised fields stay put.
      await repo.updateProfile('org1', {'bio': 'I make pottery'});
      await repo.updateProfile('org1', {'location_city': 'Brussels'});

      final after = await firestore.collection('momentos').doc(m1).get();
      expect(after.data()!['organizer_avatar_url'],
          equals('https://old.example/a.jpg'));
      expect(after.data()!['organizer_name'], equals('Old Name'));
    });

    test('combined avatar + name patch updates both denormalised fields',
        () async {
      await seedUser('org1');
      final m1 = await seedMomento('org1');

      await repo.updateProfile('org1', {
        'avatar_url': 'https://new.example/avatar.jpg',
        'display_name': 'New Name',
      });

      final after = await firestore.collection('momentos').doc(m1).get();
      expect(after.data()!['organizer_avatar_url'],
          equals('https://new.example/avatar.jpg'));
      expect(after.data()!['organizer_name'], equals('New Name'));
    });

    test('user with zero hosted Momentos is a no-op fan-out', () async {
      await seedUser('org1');
      // No momentos seeded for org1. Should still update the user doc.
      await repo.updateProfile('org1', {
        'avatar_url': 'https://new.example/avatar.jpg',
      });
      final user = await firestore.collection('users').doc('org1').get();
      expect(user.data()!['avatar_url'],
          equals('https://new.example/avatar.jpg'));
    });
  });
}
