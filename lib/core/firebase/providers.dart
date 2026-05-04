import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../repositories/follow_repository.dart';
import '../repositories/momento_repository.dart';
import '../repositories/storage_repository.dart';
import '../repositories/user_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final storageProvider =
    Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref.watch(storageProvider));
});

final momentoRepositoryProvider = Provider<MomentoRepository>((ref) {
  return MomentoRepository(
    ref.watch(firestoreProvider),
    ref.watch(storageRepositoryProvider),
  );
});

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref.watch(firestoreProvider));
});

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.watch(firestoreProvider));
});

/// Live "is the signed-in user following [followingId]?" — null when signed
/// out, else true/false.
final isFollowingProvider =
    StreamProvider.family<bool, String>((ref, followingId) {
  final me = ref.watch(authStateChangesProvider).value;
  if (me == null) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsFollowing(
        followerId: me.uid,
        followingId: followingId,
      );
});

/// Live follower count for any user (organisor surface). Re-runs on every
/// follow/unfollow under the listener, since the underlying query stream
/// will emit. We use a stream that reissues count() on every change.
final followerCountProvider =
    StreamProvider.family<int, String>((ref, followingId) {
  final col = ref.watch(firestoreProvider).collection('follows');
  return col
      .where('following_id', isEqualTo: followingId)
      .snapshots()
      .map((q) => q.size);
});


final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Lives next to auth state — emits the signed-in user's `users/{uid}` doc
/// snapshot. Null while signed out or doc not yet created.
final currentUserDocProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUserDoc(user.uid);
});

/// Lifetime freemium count for the signed-in user. 0 when signed out.
final freemiumUsedProvider = Provider<int>((ref) {
  final doc = ref.watch(currentUserDocProvider).value;
  return (doc?.data()?['freemium_used'] as num?)?.toInt() ?? 0;
});

final isPremiumProvider = Provider<bool>((ref) {
  final doc = ref.watch(currentUserDocProvider).value;
  return doc?.data()?['is_premium'] as bool? ?? false;
});

/// Current user's role: `user` | `organisor` | `admin`. Defaults to `user`
/// while loading or if the field is missing on legacy docs.
final userRoleProvider = Provider<String>((ref) {
  final doc = ref.watch(currentUserDocProvider).value;
  return (doc?.data()?['role'] as String?) ?? 'user';
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == 'admin';
});

final isOrganisorProvider = Provider<bool>((ref) {
  final r = ref.watch(userRoleProvider);
  return r == 'organisor' || r == 'admin';
});

/// Admin-panel data streams. These hit Firestore directly (no mock
/// fallback) since the panel is only meaningful against a live project.
final adminAllMomentosProvider = StreamProvider((ref) {
  return ref.watch(momentoRepositoryProvider).watchAll();
});

final adminAllUsersProvider = StreamProvider((ref) {
  return ref.watch(userRepositoryProvider).watchAllUsers();
});

final adminAuditLogProvider = StreamProvider((ref) {
  return ref.watch(auditLogRepositoryProvider).watchRecent();
});
