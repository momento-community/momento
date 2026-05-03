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
      'momentos_organized_count': 0,
      'freemium_used': 0,
      'is_premium': false,
      'stripe_customer_id': null,
      'created_at': FieldValue.serverTimestamp(),
    });
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
