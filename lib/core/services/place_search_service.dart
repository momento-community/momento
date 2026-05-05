import 'dart:convert';

import 'package:http/http.dart' as http;

/// Single autocomplete suggestion returned by the place-search service.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
    required this.city,
  });

  /// Human-readable single-line label, e.g. "Brandenburger Tor, Berlin,
  /// Germany". Used as the `location_address` we store on the Momento.
  final String label;
  final double lat;
  final double lng;

  /// Best-effort city name extracted from the result. Used for our
  /// `location_city` field. Falls back to empty when the geocoder didn't
  /// surface a city (rural / wilderness coords).
  final String city;
}

/// Place-search backend.
///
/// We use **Photon** (https://photon.komoot.io) — an open-source geocoder
/// that wraps OpenStreetMap data and supports browser CORS without an API
/// key or backend proxy.
///
/// Trade-off: Google Places gives better quality for venues + businesses,
/// but its REST autocomplete endpoint doesn't allow direct browser calls
/// (CORS-blocked) — using it on web requires either the JS Maps API
/// (different surface) or a Cloud Functions proxy. Photon punches above
/// its weight for landmarks + addresses in major cities, costs zero
/// dollars, and works on every platform we care about (web + iOS +
/// Android). Switch to Google Places when v1 quality complaints arrive
/// AND a backend proxy is on the roadmap.
class PlaceSearchService {
  PlaceSearchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://photon.komoot.io';

  /// Returns up to [limit] suggestions for [query]. Empty / whitespace-only
  /// queries short-circuit to `[]` so callers can safely call this on every
  /// keystroke without a debounce (we still recommend debouncing — see
  /// `LocationSearchSheet`).
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    int limit = 6,
    String lang = 'en',
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$_base/api/').replace(queryParameters: {
      'q': q,
      'limit': '$limit',
      'lang': lang,
    });
    final res = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return const [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? const [];
    return features
        .map((f) => _decode(f as Map<String, dynamic>))
        .whereType<PlaceSuggestion>()
        .toList(growable: false);
  }

  PlaceSuggestion? _decode(Map<String, dynamic> feature) {
    final geom = feature['geometry'] as Map<String, dynamic>?;
    final coords = (geom?['coordinates'] as List?)?.cast<num>();
    if (coords == null || coords.length < 2) return null;
    // GeoJSON is [lng, lat], not [lat, lng]. Don't get this wrong.
    final lng = coords[0].toDouble();
    final lat = coords[1].toDouble();

    final props = feature['properties'] as Map<String, dynamic>? ?? const {};
    final name = (props['name'] as String?)?.trim();
    final street = (props['street'] as String?)?.trim();
    final houseNumber = (props['housenumber'] as String?)?.trim();
    final city = (props['city'] as String?)?.trim() ??
        (props['town'] as String?)?.trim() ??
        (props['village'] as String?)?.trim() ??
        (props['county'] as String?)?.trim() ??
        '';
    final country = (props['country'] as String?)?.trim();

    // Compose a readable label. Order: street + number > name > city +
    // country. Drop empty + duplicate segments so we don't emit
    // ", , Berlin, Germany".
    final segments = <String>[];
    if ((street ?? '').isNotEmpty) {
      segments.add(houseNumber == null || houseNumber.isEmpty
          ? street!
          : '$street $houseNumber');
    } else if ((name ?? '').isNotEmpty) {
      segments.add(name!);
    }
    if (city.isNotEmpty) segments.add(city);
    if ((country ?? '').isNotEmpty) segments.add(country!);
    final label = segments
        .where((s) => s.isNotEmpty)
        .toSet() // de-dupe in case name == city for big landmarks
        .join(', ');

    if (label.isEmpty) return null;
    return PlaceSuggestion(label: label, lat: lat, lng: lng, city: city);
  }
}
