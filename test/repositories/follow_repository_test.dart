import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momento/core/repositories/follow_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FollowRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FollowRepository(firestore);
  });

  group('toggle', () {
    test(r'follow creates a doc with deterministic id ${followerId}_${followingId}',
        () async {
      await repo.toggle(
        followerId: 'alice',
        followingId: 'bob',
        currentlyFollowing: false,
      );

      final docs = await firestore.collection('follows').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.first.id, equals('alice_bob'));
      expect(docs.docs.first.data()['follower_id'], equals('alice'));
      expect(docs.docs.first.data()['following_id'], equals('bob'));
    });

    test('unfollow removes the doc', () async {
      await firestore.collection('follows').doc('alice_bob').set({
        'follower_id': 'alice',
        'following_id': 'bob',
        'created_at': null, // serverTimestamp at write time
      });

      await repo.toggle(
        followerId: 'alice',
        followingId: 'bob',
        currentlyFollowing: true,
      );

      final docs = await firestore.collection('follows').get();
      expect(docs.docs, isEmpty);
    });

    test('follow → unfollow → follow round trip leaves a single doc',
        () async {
      await repo.toggle(
        followerId: 'alice',
        followingId: 'bob',
        currentlyFollowing: false,
      );
      await repo.toggle(
        followerId: 'alice',
        followingId: 'bob',
        currentlyFollowing: true,
      );
      await repo.toggle(
        followerId: 'alice',
        followingId: 'bob',
        currentlyFollowing: false,
      );

      final docs = await firestore.collection('follows').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.first.id, equals('alice_bob'));
    });

    test('unfollow when no doc exists is a no-op (deterministic id ⇒ no lookup)',
        () async {
      await expectLater(
        repo.toggle(
          followerId: 'alice',
          followingId: 'bob',
          currentlyFollowing: true,
        ),
        completes,
      );
    });
  });

  group('watchIsFollowing', () {
    test('emits true when the doc exists, false otherwise', () async {
      // Initial: not following.
      expect(
        await repo
            .watchIsFollowing(followerId: 'alice', followingId: 'bob')
            .first,
        isFalse,
      );

      // After follow.
      await repo.toggle(
        followerId: 'alice',
        followingId: 'bob',
        currentlyFollowing: false,
      );
      expect(
        await repo
            .watchIsFollowing(followerId: 'alice', followingId: 'bob')
            .first,
        isTrue,
      );
    });
  });

  group('watchFollowing', () {
    test('returns every following_id for a follower', () async {
      await repo.toggle(
          followerId: 'alice', followingId: 'bob', currentlyFollowing: false);
      await repo.toggle(
          followerId: 'alice', followingId: 'carol', currentlyFollowing: false);
      // Different follower — must NOT show up in alice's stream.
      await repo.toggle(
          followerId: 'mallory', followingId: 'bob', currentlyFollowing: false);

      final list = await repo.watchFollowing('alice').first;

      expect(list..sort(), equals(['bob', 'carol']));
    });
  });

  group('followerCount', () {
    test('counts only docs where following_id matches', () async {
      await repo.toggle(
          followerId: 'alice', followingId: 'bob', currentlyFollowing: false);
      await repo.toggle(
          followerId: 'carol', followingId: 'bob', currentlyFollowing: false);
      // Different followee — irrelevant to bob's follower count.
      await repo.toggle(
          followerId: 'alice',
          followingId: 'dave',
          currentlyFollowing: false);

      expect(await repo.followerCount('bob'), equals(2));
      expect(await repo.followerCount('dave'), equals(1));
      expect(await repo.followerCount('nobody'), equals(0));
    });
  });
}
