import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Append-only audit trail of admin-initiated mutations. Every doc captures
/// who did what to which target, with optional `before` / `after` snapshots
/// of the changed fields.
///
/// Schema:
///
/// ```
/// audit_log/{id} {
///   actor_id      String   // uid of the admin who acted
///   actor_email   String   // denormalised for human display
///   action        String   // e.g. 'momento.delete', 'user.role_change'
///   target_type   String   // 'momento' | 'user'
///   target_id     String
///   before        Map?     // changed-field snapshot before the action
///   after         Map?     // changed-field snapshot after the action
///   created_at    Timestamp (server)
/// }
/// ```
///
/// Rules in `firestore.rules` enforce: admin-only read, admin-only write,
/// `actor_id == request.auth.uid`, no updates, no deletes (true append-only).
class AuditLogRepository {
  AuditLogRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('audit_log');

  /// Whitelist of field names admins may store in `before` / `after`.
  /// Any other key is dropped silently — defends against a careless
  /// caller leaking PII (passwords, tokens, full user docs) into the
  /// permanent log. Add new entries deliberately as new audit codes
  /// arrive.
  static const _allowedDiffFields = <String>{
    'title',
    'description',
    'images',
    'organizer_id',
    'role',
    'is_banned',
    'reason',
    'decided_reason',
  };

  Future<void> log({
    required User actor,
    required String action,
    required String targetId,
    required String targetType,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  }) async {
    await _col.add({
      'actor_id': actor.uid,
      'actor_email': actor.email ?? '',
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'before': _filter(before),
      'after': _filter(after),
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Map<String, Object?>? _filter(Map<String, Object?>? m) {
    if (m == null) return null;
    return {
      for (final e in m.entries)
        if (_allowedDiffFields.contains(e.key)) e.key: e.value,
    };
  }

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> watchRecent({
    int limit = 100,
  }) {
    return _col
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs);
  }
}
