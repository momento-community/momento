import 'package:cloud_firestore/cloud_firestore.dart';

/// Status enum for `organisor_requests/{uid}`. Stored as the lowercase
/// string id; never the enum's `toString()`.
enum OrganisorRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const OrganisorRequestStatus(this.id);
  final String id;

  static OrganisorRequestStatus fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => pending);
}

/// Plain immutable view of a single request doc — keeps the UI free of
/// raw `DocumentSnapshot` plumbing. The denormalised `user_*` fields are
/// the snapshot of the requester's profile at request time, used by the
/// admin queue so the page renders without a second per-row read.
class OrganisorRequest {
  const OrganisorRequest({
    required this.uid,
    required this.status,
    required this.requestedAt,
    required this.userEmail,
    required this.userDisplayName,
    this.userAvatarUrl,
    this.decidedAt,
    this.decidedBy,
    this.decidedReason,
  });

  final String uid;
  final OrganisorRequestStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? decidedReason;
  final String userEmail;
  final String userDisplayName;
  final String? userAvatarUrl;

  factory OrganisorRequest.fromSnap(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return OrganisorRequest(
      uid: snap.id,
      status: OrganisorRequestStatus.fromId(d['status'] as String? ?? 'pending'),
      requestedAt:
          (d['requested_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      decidedAt: (d['decided_at'] as Timestamp?)?.toDate(),
      decidedBy: d['decided_by'] as String?,
      decidedReason: d['decided_reason'] as String?,
      userEmail: d['user_email'] as String? ?? '',
      userDisplayName: d['user_display_name'] as String? ?? '',
      userAvatarUrl: d['user_avatar_url'] as String?,
    );
  }
}

class OrganisorRequestsRepository {
  OrganisorRequestsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('organisor_requests');

  /// The signed-in user's own request (or null if none has ever been
  /// submitted). Stream so the Profile / Create screens react to admin
  /// approval / rejection without a manual refresh.
  Stream<OrganisorRequest?> watchMine(String uid) {
    return _col.doc(uid).snapshots().map((s) =>
        s.exists ? OrganisorRequest.fromSnap(s) : null);
  }

  /// Admin queue: every pending request, oldest first (FIFO review).
  Stream<List<OrganisorRequest>> watchPending() {
    return _col
        .where('status', isEqualTo: 'pending')
        .orderBy('requested_at')
        .snapshots()
        .map((q) => q.docs.map(OrganisorRequest.fromSnap).toList());
  }

  /// Submit (or re-submit after rejection). The denormalised user fields
  /// are passed in by the caller because the repo doesn't know about
  /// FirebaseAuth — keep dependencies one-way.
  Future<void> submit({
    required String uid,
    required String userEmail,
    required String userDisplayName,
    String? userAvatarUrl,
  }) async {
    final ref = _col.doc(uid);
    final snap = await ref.get();
    final payload = <String, Object?>{
      'status': 'pending',
      'requested_at': FieldValue.serverTimestamp(),
      'decided_at': null,
      'decided_by': null,
      'decided_reason': null,
      'user_email': userEmail,
      'user_display_name': userDisplayName,
      'user_avatar_url': userAvatarUrl,
    };
    if (snap.exists) {
      // Re-submission after rejection — rule enforces the rejected→pending
      // transition; if the doc is currently approved this update is
      // pointless (and rejected by the rule).
      await ref.update(payload);
    } else {
      await ref.set(payload);
    }
  }

  /// Admin: approve a request. Atomic batch — flips request status AND
  /// promotes the user's role in `users/{uid}` so the UI reflects the
  /// transition in one snapshot, not two staggered ones.
  Future<void> approve({
    required String uid,
    required String adminUid,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col.doc(uid), {
      'status': 'approved',
      'decided_at': FieldValue.serverTimestamp(),
      'decided_by': adminUid,
      'decided_reason': null,
    });
    batch.update(_firestore.collection('users').doc(uid), {
      'role': 'organisor',
    });
    await batch.commit();
  }

  /// Admin: reject a request, with optional reason shown to the user
  /// next to a "Try again" button.
  Future<void> reject({
    required String uid,
    required String adminUid,
    String? reason,
  }) async {
    await _col.doc(uid).update({
      'status': 'rejected',
      'decided_at': FieldValue.serverTimestamp(),
      'decided_by': adminUid,
      'decided_reason': reason,
    });
  }
}
