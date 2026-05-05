import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:http/http.dart' as http;

import '../mock/mock_momentos.dart';
import '../models/momento.dart';

/// Lightweight ad-hoc seed for a fresh project. Fetches placeholder images
/// from picsum.photos, uploads them to Firebase Storage at the canonical
/// paths, then writes Firestore docs that reference the resulting download
/// URLs.
///
/// **Best-practice paths**:
///
/// - `users/{uid}/avatar.jpg` — one avatar per user; overwrite-safe.
/// - `momentos/{organizerUid}/{momentoId}/cover.jpg` — partitioned by
///   organizer so storage rules can scope writes by ownership and the
///   admin tools can list-by-organizer.
///
/// All uploads carry `Cache-Control: public, max-age=31536000, immutable`
/// since we never edit a file in place — a fresh upload uses a new path
/// (or just overwrites with content that's still semantically the same).
///
/// Caller must be an admin — Storage rules permit cross-organizer writes
/// only for `role == 'admin'`. The button is gated in [ProfileScreen] to
/// match.
class DemoSeed {
  DemoSeed({required this.firestore, required this.storage});

  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final _http = http.Client();

  /// Run the full seed. Calls [onProgress] with `(done, total)` so the UI
  /// can render a progress label.
  Future<DemoSeedResult> run({
    required void Function(int done, int total) onProgress,
  }) async {
    final organisors = _organisorsFromMock();
    final plainUsers = _plainUsers;
    final totalSteps =
        organisors.length + plainUsers.length + mockMomentos.length;
    int done = 0;
    void bump() => onProgress(++done, totalSteps);

    // 1. Demo organisors with avatars.
    final avatarUrlByOrganisor = <String, String>{};
    for (final o in organisors) {
      final avatarUrl = await _uploadImage(
        url: 'https://picsum.photos/seed/${o.id}-avatar/200/200',
        path: 'users/${o.id}/avatar.jpg',
      );
      avatarUrlByOrganisor[o.id] = avatarUrl;
      await firestore.collection('users').doc(o.id).set(_userDoc(
            displayName: o.name,
            email: '${o.id}@demo.momento.community',
            avatarUrl: avatarUrl,
            role: 'organisor',
            bio: o.bio,
          ));
      bump();
    }

    // 2. Plain demo users with avatars.
    for (final u in plainUsers) {
      final avatarUrl = await _uploadImage(
        url: 'https://picsum.photos/seed/${u.id}-avatar/200/200',
        path: 'users/${u.id}/avatar.jpg',
      );
      await firestore.collection('users').doc(u.id).set(_userDoc(
            displayName: u.name,
            email: '${u.id}@demo.momento.community',
            avatarUrl: avatarUrl,
            role: 'user',
            bio: u.bio,
          ));
      bump();
    }

    // 3. Momentos with cover photos.
    for (final m in mockMomentos) {
      final coverUrl = await _uploadImage(
        url: 'https://picsum.photos/seed/${m.id}/600/800',
        path: 'momentos/${m.organizerId}/${m.id}/cover.jpg',
      );
      final geo = GeoFirePoint(GeoPoint(m.locationLat, m.locationLng));
      await firestore.collection('momentos').doc(m.id).set({
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
        'images': [coverUrl],
        'event_website_url': m.eventWebsiteUrl,
        'instagram_post_url': m.instagramPostUrl,
        'eventbrite_url': m.eventbriteUrl,
        'other_ticket_url': m.otherTicketUrl,
        'organizer_id': m.organizerId,
        'organizer_name': m.organizerName,
        'organizer_avatar_url': avatarUrlByOrganisor[m.organizerId] ?? '',
        'like_count': 0,
        'liked_by': const <String>[],
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromDate(m.endDateTime),
      });
      bump();
    }

    return DemoSeedResult(
      organisors: organisors.length,
      plainUsers: plainUsers.length,
      momentos: mockMomentos.length,
    );
  }

  // ────────────────────────────────────────────────────────────────────

  Future<String> _uploadImage({
    required String url,
    required String path,
  }) async {
    final bytes = await _fetch(url);
    final ref = storage.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000, immutable',
      ),
    );
    return ref.getDownloadURL();
  }

  Future<Uint8List> _fetch(String url) async {
    final resp = await _http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw StateError('Image fetch failed: $url (${resp.statusCode})');
    }
    return resp.bodyBytes;
  }

  Map<String, Object?> _userDoc({
    required String displayName,
    required String email,
    required String avatarUrl,
    required String role,
    String bio = '',
  }) {
    return {
      'display_name': displayName,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'location_city': 'Berlin',
      'instagram_handle': null,
      'role': role,
      'momentos_organized_count': 0,
      'freemium_used': 0,
      'is_premium': false,
      'is_banned': false,
      'stripe_customer_id': null,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  /// Pull unique organisors from the mock fixture so the same set of
  /// organizer_ids we used pre-Storage are honoured in the seed.
  List<_DemoOrganisor> _organisorsFromMock() {
    final byId = <String, _DemoOrganisor>{};
    for (final Momento m in mockMomentos) {
      byId.putIfAbsent(
        m.organizerId,
        () => _DemoOrganisor(
          id: m.organizerId,
          name: m.organizerName,
          bio: _bioFor(m.organizerId),
        ),
      );
    }
    return byId.values.toList();
  }

  static String _bioFor(String id) {
    switch (id) {
      case 'studio-o':
        return 'Curators of light, silence, and form.';
      case 'farmers-collective':
        return 'Local growers. Saturdays on the cobblestones.';
      case 'cellar-bar':
        return 'Late-night jazz cellar in Friedrichstraße.';
      case 'maya-yoga':
        return 'Sunrise vinyasa in the park. Donations welcome.';
      case 'cinema-club':
        return 'Open-air screenings, weather permitting.';
      case 'kaffeerosterei':
        return 'Single-origin roastery. We pour, you learn.';
      case 'kollektiv-x':
        return 'Underground techno. Address by DM.';
      case 'studio-7':
        return 'Pottery + ceramic studio in Friedrichshain.';
      case 'rose-bloom':
        return 'Late-summer bouquets, single stems by the gram.';
      case 'night-runners':
        return '8km loop along the canal. Glow sticks provided.';
      case 'creative-circle':
        return 'Designers, illustrators, writers — drinks at golden hour.';
      default:
        return '';
    }
  }

  static const _plainUsers = [
    _DemoUser(
      id: 'demo-user-anna',
      name: 'Anna',
      bio: 'Looks for vinyl nights and pop-up markets.',
    ),
    _DemoUser(
      id: 'demo-user-felix',
      name: 'Felix',
      bio: 'Runs at sunrise, reads at sunset.',
    ),
    _DemoUser(
      id: 'demo-user-mia',
      name: 'Mia',
      bio: 'Saving good Momentos faster than she attends them.',
    ),
  ];
}

class DemoSeedResult {
  const DemoSeedResult({
    required this.organisors,
    required this.plainUsers,
    required this.momentos,
  });
  final int organisors;
  final int plainUsers;
  final int momentos;

  int get total => organisors + plainUsers + momentos;

  @override
  String toString() =>
      '$organisors organisor + $plainUsers user + $momentos momento docs';
}

class _DemoOrganisor {
  const _DemoOrganisor({
    required this.id,
    required this.name,
    required this.bio,
  });
  final String id;
  final String name;
  final String bio;
}

class _DemoUser {
  const _DemoUser({
    required this.id,
    required this.name,
    required this.bio,
  });
  final String id;
  final String name;
  final String bio;
}
