import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Creates the user doc with safe defaults if it doesn't yet exist. Called
  /// on every sign-in by the auth flow — first sign-in creates the doc; later
  /// sign-ins are a no-op (using `set(..., merge: true)` would overwrite the
  /// counter, so we explicitly check).
  Future<void> ensureUserDoc(User user) async {
    final ref = _users.doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'display_name': user.displayName ?? _emailToName(user.email),
      'email': user.email ?? '',
      'avatar_url': user.photoURL ?? '',
      'bio': '',
      'location_city': '',
      'instagram_handle': null,
      'role': 'user',
      'momentos_organized_count': 0,
      'freemium_used': 0,
      'is_premium': false,
      'is_banned': false,
      'stripe_customer_id': null,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Admin-only: flip a user's role. Rule check (`isAdmin()`) on the
  /// server prevents misuse; this method just constructs the write.
  Future<void> setRole(String uid, String role) {
    return _users.doc(uid).update({'role': role});
  }

  /// Admin-only: ban or unban a user. Banned users keep read access but
  /// lose every write (rules check `is_banned` on user updates and on
  /// momentos / follows mutations).
  Future<void> setBanned(String uid, bool banned) {
    return _users.doc(uid).update({'is_banned': banned});
  }

  /// Admin-only: latest [limit] user docs, newest first. Capped at 100
  /// by default to keep the admin Users tab cheap on a growing collection
  /// — switch to cursor-based pagination if we ever need to surface older
  /// users than the most recent batch.
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> watchAllUsers({
    int limit = 100,
  }) {
    return _users
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) {
    return _users.doc(uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) {
    return _users.doc(uid).get();
  }

  /// Patches `users/{uid}` and — when `display_name` or `avatar_url` change —
  /// fans the new value out to every Momento where `organizer_id == uid`,
  /// keeping the denormalised `organizer_name` / `organizer_avatar_url`
  /// fields in cards + detail in sync with the live profile.
  ///
  /// The fan-out is a single `WriteBatch`, chunked at 450 ops so we stay
  /// well under Firestore's 500-write batch limit even if a power user
  /// hosts hundreds of Momentos.
  Future<void> updateProfile(String uid, Map<String, Object?> patch) async {
    await _users.doc(uid).update(patch);

    // Only avatar + display_name are denormalised onto Momento docs. If the
    // patch only changed bio / city / role / etc., skip the fan-out work.
    final momentoPatch = <String, Object?>{};
    if (patch.containsKey('avatar_url')) {
      momentoPatch['organizer_avatar_url'] = patch['avatar_url'];
    }
    if (patch.containsKey('display_name')) {
      momentoPatch['organizer_name'] = patch['display_name'];
    }
    if (momentoPatch.isEmpty) return;

    final query = await _firestore
        .collection('momentos')
        .where('organizer_id', isEqualTo: uid)
        .get();
    if (query.docs.isEmpty) return;

    const chunkSize = 450;
    for (var i = 0; i < query.docs.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = (i + chunkSize).clamp(0, query.docs.length);
      for (final doc in query.docs.sublist(i, end)) {
        batch.update(doc.reference, momentoPatch);
      }
      await batch.commit();
    }
  }

  static String _emailToName(String? email) {
    if (email == null || email.isEmpty) return 'Momento member';
    final local = email.split('@').first;
    return local
        .split(RegExp(r'[._-]'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }
}
