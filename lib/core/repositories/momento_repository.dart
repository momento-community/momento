import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/env.dart';
import '../models/momento.dart';
import '../models/momento_category.dart';
import 'storage_repository.dart';

class CreateMomentoInput {
  CreateMomentoInput({
    required this.title,
    required this.description,
    required this.category,
    required this.startDateTime,
    required this.endDateTime,
    required this.locationAddress,
    required this.locationCity,
    required this.lat,
    required this.lng,
    required this.coverPhoto,
    this.eventWebsiteUrl,
    this.instagramPostUrl,
    this.eventbriteUrl,
    this.otherTicketUrl,
  });

  final String title;
  final String description;
  final MomentoCategory category;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String locationAddress;
  final String locationCity;
  final double lat;
  final double lng;
  final XFile? coverPhoto;
  final String? eventWebsiteUrl;
  final String? instagramPostUrl;
  final String? eventbriteUrl;
  final String? otherTicketUrl;
}

class FreemiumExceeded implements Exception {
  const FreemiumExceeded();
  @override
  String toString() => 'Freemium limit reached';
}

class MomentoRepository {
  MomentoRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final StorageRepository _storage;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('momentos');

  /// Stream of currently-active Momentos, newest start first.
  Stream<List<Momento>> watchActive() {
    return _col
        .where('is_active', isEqualTo: true)
        .where('end_datetime', isGreaterThan: Timestamp.now())
        .orderBy('end_datetime')
        .snapshots()
        .map(_decodeList);
  }

  Stream<List<Momento>> watchByOrganizer(String uid) {
    return _col
        .where('organizer_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(_decodeList);
  }

  Stream<List<Momento>> watchLikedBy(String uid) {
    return _col
        .where('liked_by', arrayContains: uid)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(_decodeList);
  }

  /// Atomic transaction: create the momento doc + bump the user's
  /// `freemium_used`. Throws [FreemiumExceeded] if the user is at the cap.
  ///
  /// We don't enforce the 50m+time-overlap conflict here on the client — that
  /// requires a server-side query for full atomicity. For v1 we accept the
  /// vanishingly-small race window; if duplicates become a problem we can
  /// move this into a callable function later.
  Future<String> createMomento({
    required String organizerUid,
    required String organizerName,
    required String organizerAvatarUrl,
    required CreateMomentoInput input,
  }) async {
    final now = DateTime.now();
    final id = _col.doc().id;

    // Upload cover photo first (outside the transaction so we don't hold the
    // lock while waiting on Storage).
    String? imageUrl;
    if (input.coverPhoto != null) {
      imageUrl = await _storage.uploadMomentoImage(
        organizerUid: organizerUid,
        momentoId: id,
        file: input.coverPhoto!,
      );
    }

    final geoPoint = GeoFirePoint(GeoPoint(input.lat, input.lng));
    final durationDays = ((input.endDateTime.difference(input.startDateTime))
            .inHours /
        24)
        .ceil()
        .clamp(1, Env.maxMomentoDurationDays);

    final data = <String, Object?>{
      'title': input.title,
      'description': input.description,
      'category': input.category.id,
      'start_datetime': Timestamp.fromDate(input.startDateTime),
      'end_datetime': Timestamp.fromDate(input.endDateTime),
      'duration_days': durationDays,
      'location_address': input.locationAddress,
      'location_geopoint': GeoPoint(input.lat, input.lng),
      'location_geohash': geoPoint.geohash,
      'location_city': input.locationCity,
      'images': imageUrl == null ? <String>[] : <String>[imageUrl],
      'event_website_url': input.eventWebsiteUrl,
      'instagram_post_url': input.instagramPostUrl,
      'eventbrite_url': input.eventbriteUrl,
      'other_ticket_url': input.otherTicketUrl,
      'organizer_id': organizerUid,
      'organizer_name': organizerName,
      'organizer_avatar_url': organizerAvatarUrl,
      'like_count': 0,
      'view_count': 0,
      'liked_by': <String>[],
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(input.endDateTime),
    };

    await _firestore.runTransaction((tx) async {
      final userRef = _firestore.collection('users').doc(organizerUid);
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw StateError('User doc missing — sign in again.');
      }
      final freemiumUsed =
          (userSnap.data()!['freemium_used'] as num?)?.toInt() ?? 0;
      final isPremium = userSnap.data()!['is_premium'] as bool? ?? false;
      if (!isPremium && freemiumUsed >= Env.freemiumLimit) {
        throw const FreemiumExceeded();
      }

      tx.set(_col.doc(id), data);
      tx.update(userRef, {
        'freemium_used': freemiumUsed + 1,
        'momentos_organized_count': FieldValue.increment(1),
      });
    });

    // Best-effort logging — created_at is server-generated, so we don't echo
    // anything back; the client picks up the doc via the active stream.
    final _ = now;
    return id;
  }

  /// Toggle the current user's like on a Momento. Optimistic; collisions are
  /// resolved by Firestore's set-like semantics on `arrayUnion`/`arrayRemove`
  /// + a transaction-bumped counter.
  Future<void> toggleLike(String momentoId, String uid) async {
    final ref = _col.doc(momentoId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final liked = (snap.data()!['liked_by'] as List?)?.cast<String>() ??
          const <String>[];
      final isLiked = liked.contains(uid);
      tx.update(ref, {
        'liked_by': isLiked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
        'like_count': FieldValue.increment(isLiked ? -1 : 1),
      });
    });
  }

  Future<void> incrementViewCount(String momentoId) {
    return _col.doc(momentoId).update({
      'view_count': FieldValue.increment(1),
    });
  }

  /// DEV ONLY: batch-writes the in-memory mock fixture so a fresh project
  /// has something to look at on Discover. Idempotent — overwrites by id.
  ///
  /// All seeded Momentos are written as if [organizerUid] hosted them, so
  /// security rules accept the writes and the docs show up under that
  /// user's "Organised" tab too. Should be hidden behind `kDebugMode`.
  Future<int> seedDevMomentos({
    required List<Momento> mocks,
    required String organizerUid,
    required String organizerName,
    required String organizerAvatarUrl,
  }) async {
    // Rules permit one momento create per write; do them sequentially so a
    // single failure surfaces clearly instead of a cryptic batch rollback.
    for (final m in mocks) {
      final ref = _col.doc(m.id);
      final geo = GeoFirePoint(GeoPoint(m.locationLat, m.locationLng));
      await ref.set({
        'title': m.title,
        'description': m.description,
        'category': m.category.id,
        'start_datetime': Timestamp.fromDate(m.startDateTime),
        'end_datetime': Timestamp.fromDate(m.endDateTime),
        'duration_days': m.durationDays,
        'location_address': m.locationAddress,
        'location_geopoint': GeoPoint(m.locationLat, m.locationLng),
        'location_geohash': geo.geohash,
        'location_city': m.locationCity,
        'images': m.images,
        'event_website_url': m.eventWebsiteUrl,
        'instagram_post_url': m.instagramPostUrl,
        'eventbrite_url': m.eventbriteUrl,
        'other_ticket_url': m.otherTicketUrl,
        'organizer_id': organizerUid,
        'organizer_name': organizerName,
        'organizer_avatar_url': organizerAvatarUrl,
        'like_count': 0,
        'view_count': 0,
        'liked_by': const <String>[],
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromDate(m.endDateTime),
      });
    }
    return mocks.length;
  }

  List<Momento> _decodeList(QuerySnapshot<Map<String, dynamic>> q) {
    return q.docs.map(Momento.fromFirestore).toList();
  }
}
