import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/env.dart';

/// Lightweight typeahead row — what the suggestions list shows while
/// the user is still typing. Holds just enough to render the list and
/// follow up with a `resolve(placeId)` on tap.
class PlacePrediction {
  const PlacePrediction({required this.label, required this.placeId});
  final String label;
  final String placeId;
}

/// Final picked-place payload returned to the UI. Carries everything we
/// need to write the Momento doc + drop a pin on the Map page.
class PickedPlace {
  const PickedPlace({
    required this.label,
    required this.city,
    required this.lat,
    required this.lng,
  });

  /// Human-readable single-line label, e.g. "Brandenburger Tor, Mitte,
  /// 10117 Berlin, Germany". Stored as `location_address`.
  final String label;

  /// City name pulled from Google's `addressComponents` (`locality` type),
  /// stored as `location_city`. Falls back to empty when the geocoder
  /// didn't surface one — UI then writes "Unknown".
  final String city;
  final double lat;
  final double lng;
}

/// Geocoding backend.
///
/// Google **Places API (New)** at `places.googleapis.com/v1/...`. Two-step:
///
/// 1. `autocomplete(query)` POSTs to `/places:autocomplete`, returns a
///    light list of `PlacePrediction` (label + placeId).
/// 2. On tap, `resolve(placeId)` GETs `/places/{id}` for the lat/lng +
///    address components. Returns `PickedPlace`.
///
/// Why the new API and not the legacy one at `maps.googleapis.com`:
/// the legacy endpoint is CORS-blocked from browsers and would need a
/// Cloud Functions proxy. The new API supports CORS out of the box.
///
/// Auth: re-uses the existing `GOOGLE_MAPS_KEY_WEB` repo secret (passed
/// via `--dart-define`). The same key needs **Places API (New)** added
/// to its API restrictions in GCP Console — see CLAUDE.md.
class PlaceSearchService {
  PlaceSearchService({String? apiKey, http.Client? client})
      : _apiKey = apiKey ?? Env.googleMapsKeyWeb,
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static String _detailsUrl(String placeId) =>
      'https://places.googleapis.com/v1/places/$placeId';

  /// Returns up to ~5 typeahead predictions for [query]. Empty queries +
  /// missing API keys short-circuit to `[]` so callers can safely call
  /// this on every keystroke (still recommend debouncing in the UI).
  Future<List<PlacePrediction>> autocomplete(String query) async {
    final q = query.trim();
    if (q.isEmpty || _apiKey.isEmpty) return const [];
    try {
      final res = await _client
          .post(
            Uri.parse(_autocompleteUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              // Field mask is mandatory on the new API — without it the
              // request returns 400. Keep this minimal: just what the
              // suggestions list renders.
              'X-Goog-FieldMask':
                  'suggestions.placePrediction.placeId,suggestions.placePrediction.text',
            },
            body: json.encode({'input': q}),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List?) ?? const [];
      return suggestions
          .map((s) => _decodePrediction(s as Map<String, dynamic>))
          .whereType<PlacePrediction>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Resolves a [placeId] to its lat/lng + city + formatted address.
  /// Returns null when the place doesn't exist or the API fails.
  Future<PickedPlace?> resolve(String placeId) async {
    if (placeId.isEmpty || _apiKey.isEmpty) return null;
    try {
      final res = await _client
          .get(
            Uri.parse(_detailsUrl(placeId)),
            headers: {
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask':
                  'location,formattedAddress,addressComponents',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body) as Map<String, dynamic>;
      final loc = data['location'] as Map<String, dynamic>?;
      if (loc == null) return null;
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      final label = data['formattedAddress'] as String? ?? '';
      final components =
          (data['addressComponents'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      String city = '';
      for (final c in components) {
        final types = (c['types'] as List?)?.cast<String>() ?? const [];
        if (types.contains('locality')) {
          city = (c['longText'] as String?) ??
              (c['shortText'] as String?) ??
              '';
          break;
        }
      }
      return PickedPlace(label: label, city: city, lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }

  PlacePrediction? _decodePrediction(Map<String, dynamic> m) {
    final pred = m['placePrediction'] as Map<String, dynamic>?;
    if (pred == null) return null;
    final placeId = pred['placeId'] as String?;
    final text = pred['text'] as Map<String, dynamic>?;
    final label = text?['text'] as String?;
    if (placeId == null || label == null || label.isEmpty) return null;
    return PlacePrediction(label: label, placeId: placeId);
  }
}
