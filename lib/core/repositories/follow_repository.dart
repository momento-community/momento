import 'package:cloud_firestore/cloud_firestore.dart';

/// Follow / unfollow / count helpers backed by `/follows/{id}`.
///
/// Doc id is deterministic — `${followerId}_${followingId}` — so a follow is
/// idempotent (re-creating == no-op) and unfollow can target a known id
/// without first looking it up. Schema:
///
/// ```
/// {
///   follower_id:  String   // who's doing the following (auth.uid)
///   following_id: String   // who's being followed (organisor uid)
///   created_at:   Timestamp
/// }
/// ```
///
/// Rules in `firestore.rules` enforce: create requires `follower_id ==
/// auth.uid` and `created_at == request.time`; delete requires the follower
/// or an admin.
class FollowRepository {
  FollowRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('follows');

  static String _docId(String followerId, String followingId) =>
      '${followerId}_$followingId';

  /// Live stream of the follow doc — exists ⇒ following.
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followingId,
  }) {
    return _col
        .doc(_docId(followerId, followingId))
        .snapshots()
        .map((s) => s.exists);
  }

  /// Live stream of every UID this user follows.
  Stream<List<String>> watchFollowing(String followerId) {
    return _col
        .where('follower_id', isEqualTo: followerId)
        .snapshots()
        .map((q) =>
            q.docs.map((d) => d.data()['following_id'] as String).toList());
  }

  /// Count of followers for an organisor. Uses Firestore's aggregation
  /// `count()` so we read 1 unit regardless of follower size.
  Future<int> followerCount(String followingId) async {
    final agg = await _col
        .where('following_id', isEqualTo: followingId)
        .count()
        .get();
    return agg.count ?? 0;
  }

  /// Toggle follow state. Idempotent on both sides — calling `follow` while
  /// already following is a no-op (Firestore ignores `set` on identical
  /// data); calling `unfollow` while not following is a `delete` on a
  /// missing doc, also a no-op.
  Future<void> toggle({
    required String followerId,
    required String followingId,
    required bool currentlyFollowing,
  }) async {
    final ref = _col.doc(_docId(followerId, followingId));
    if (currentlyFollowing) {
      await ref.delete();
    } else {
      await ref.set({
        'follower_id': followerId,
        'following_id': followingId,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }
}
