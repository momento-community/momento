import 'package:cloud_firestore/cloud_firestore.dart';

import 'momento_category.dart';

/// Plain immutable model for a Momento. We'll swap to freezed when wiring real
/// Firestore writes; for read-only mock + Firestore-decode this is enough.
class Momento {
  const Momento({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.startDateTime,
    required this.endDateTime,
    required this.locationAddress,
    required this.locationCity,
    required this.locationLat,
    required this.locationLng,
    required this.images,
    required this.organizerId,
    required this.organizerName,
    required this.organizerAvatarUrl,
    required this.likeCount,
    required this.viewCount,
    required this.likedBy,
    required this.isActive,
    required this.createdAt,
    this.eventWebsiteUrl,
    this.instagramPostUrl,
    this.eventbriteUrl,
    this.otherTicketUrl,
  });

  final String id;
  final String title;
  final String description;
  final MomentoCategory category;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String locationAddress;
  final String locationCity;
  final double locationLat;
  final double locationLng;
  final List<String> images;
  final String organizerId;
  final String organizerName;
  final String organizerAvatarUrl;
  final int likeCount;
  final int viewCount;
  final List<String> likedBy;
  final bool isActive;
  final DateTime createdAt;
  final String? eventWebsiteUrl;
  final String? instagramPostUrl;
  final String? eventbriteUrl;
  final String? otherTicketUrl;

  String get heroImage => images.isNotEmpty
      ? images.first
      : 'https://picsum.photos/seed/$id/600/600';

  Duration get duration => endDateTime.difference(startDateTime);
  int get durationDays => (duration.inHours / 24).ceil().clamp(1, 5);

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startDateTime) && now.isBefore(endDateTime);
  }

  bool get isExpired => DateTime.now().isAfter(endDateTime);

  factory Momento.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final start = (d['start_datetime'] as Timestamp).toDate();
    final end = (d['end_datetime'] as Timestamp).toDate();
    final geo = d['location_geopoint'] as GeoPoint;
    return Momento(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: MomentoCategory.fromId(d['category'] as String? ?? 'other'),
      startDateTime: start,
      endDateTime: end,
      locationAddress: d['location_address'] as String? ?? '',
      locationCity: d['location_city'] as String? ?? '',
      locationLat: geo.latitude,
      locationLng: geo.longitude,
      images: (d['images'] as List?)?.cast<String>() ?? const [],
      organizerId: d['organizer_id'] as String? ?? '',
      organizerName: d['organizer_name'] as String? ?? 'Organizer',
      organizerAvatarUrl: d['organizer_avatar_url'] as String? ?? '',
      likeCount: (d['like_count'] as num?)?.toInt() ?? 0,
      viewCount: (d['view_count'] as num?)?.toInt() ?? 0,
      likedBy: (d['liked_by'] as List?)?.cast<String>() ?? const [],
      isActive: d['is_active'] as bool? ?? true,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventWebsiteUrl: d['event_website_url'] as String?,
      instagramPostUrl: d['instagram_post_url'] as String?,
      eventbriteUrl: d['eventbrite_url'] as String?,
      otherTicketUrl: d['other_ticket_url'] as String?,
    );
  }
}
