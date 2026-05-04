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

  /// Self-service `user → organisor` upgrade. The Firestore rule allows
  /// exactly this transition; any other role change requires an admin.
  Future<void> upgradeToOrganisor(String uid) {
    return _users.doc(uid).update({'role': 'organisor'});
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

  /// Admin-only: stream every user doc, newest first. Cheap for v1 scale
  /// (a few hundred users); switch to paginated queries once we cross ~1k.
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> watchAllUsers() {
    return _users
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((q) => q.docs);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) {
    return _users.doc(uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) {
    return _users.doc(uid).get();
  }

  Future<void> updateProfile(String uid, Map<String, Object?> patch) {
    return _users.doc(uid).update(patch);
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
