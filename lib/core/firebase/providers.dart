import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../features/auth/auth_repository.dart';
import '../mock/mock_momentos.dart';
import '../models/momento.dart';
import '../repositories/audit_log_repository.dart';
import '../repositories/follow_repository.dart';
import '../repositories/momento_repository.dart';
import '../repositories/organisor_requests_repository.dart';
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

/// Live `users/{uid}` doc for any user — powers `/u/:id` profiles, the
/// organizer card on Momento detail, and the (future) admin user inspector.
/// Null when the doc doesn't exist (e.g. just-deleted account).
final userDocByIdProvider =
    StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchUserDoc(uid),
);

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

/// Follower count for any user (organisor surface). Uses Firestore's
/// `count()` aggregate query — billed as **1 read** regardless of follower
/// count, vs the prior `.snapshots()` listener that read every doc. Trade-
/// off: this is one-shot, so a brand-new follow doesn't auto-update the
/// number on screen until the screen rebuilds (route push, pull-to-refresh,
/// `ref.invalidate(followerCountProvider(uid))` after a follow toggle).
/// For Pinterest-style profiles that's fine; reactivity is rarely
/// load-bearing.
final followerCountProvider =
    FutureProvider.family<int, String>((ref, followingId) async {
  final col = ref.watch(firestoreProvider).collection('follows');
  final snap = await col
      .where('following_id', isEqualTo: followingId)
      .count()
      .get();
  return snap.count ?? 0;
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

final organisorRequestsRepositoryProvider =
    Provider<OrganisorRequestsRepository>((ref) {
  return OrganisorRequestsRepository(ref.watch(firestoreProvider));
});

/// Live state of the signed-in user's organisor request — null when never
/// submitted. Drives the "Request to host" / "Pending review" / "Try
/// again" three-state CTA on Profile + CreateScreen.
final myOrganisorRequestProvider =
    StreamProvider<OrganisorRequest?>((ref) {
  final me = ref.watch(authStateChangesProvider).value;
  if (me == null) return Stream.value(null);
  return ref.watch(organisorRequestsRepositoryProvider).watchMine(me.uid);
});

/// Admin queue: every pending organisor request, oldest first.
final pendingOrganisorRequestsProvider = StreamProvider((ref) {
  return ref.watch(organisorRequestsRepositoryProvider).watchPending();
});

/// Live single-Momento doc, by id. Powers the deep-link `/momento/:id`
/// route and the inline-edit refresh on the detail screen so Firestore is
/// the source of truth (no stale snapshots after an edit). Falls back to
/// the in-memory mock fixture when `USE_MOCK_DATA=true`.
final momentoByIdProvider =
    StreamProvider.family<Momento?, String>((ref, id) {
  if (Env.useMockData) {
    final m = mockMomentos.where((x) => x.id == id).firstOrNull;
    return Stream.value(m);
  }
  return ref.watch(momentoRepositoryProvider).watchById(id);
});

/// True when the signed-in user can edit/delete [momento] — owner OR admin.
bool canEditMomento(WidgetRef ref, Momento momento) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return false;
  if (uid == momento.organizerId) return true;
  return ref.watch(isAdminProvider);
}
