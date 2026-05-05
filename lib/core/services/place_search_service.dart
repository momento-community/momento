import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
///
/// **Latency optimisations:**
/// * Per-instance LRU/FIFO cache (cap [_cacheCap]) — re-typing a query the
///   user already saw returns instantly with no network call. The cache
///   is keyed by `<query>|<region>|<lang>` so different region biases
///   don't alias to the same entry.
/// * Optional `regionCode` + `languageCode` bias — narrows the
///   server-side search and tends to come back faster for in-region
///   queries.
/// * Optional `sessionToken` — Google's recommended pattern: pass the
///   same UUID across all autocomplete calls in one user session, then
///   pass it again on `resolve(...)`. Bills the whole session as one
///   call instead of N. Negligible latency win, real billing win.
/// * Stopwatch + `debugPrint` on every call — surfaces actual round-trip
///   times in DevTools console so future "search feels slow" reports
///   are diagnosable without instrumenting.
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

  /// Per-instance autocomplete cache, FIFO-evicted. ~32 entries is plenty
  /// for a single create-flow session — the search field rarely sees more
  /// distinct queries than that, and stale region-biased results would
  /// just be re-fetched once the cache rolls over.
  static const _cacheCap = 32;
  final LinkedHashMap<String, List<PlacePrediction>> _autocompleteCache =
      LinkedHashMap();

  /// Returns up to ~5 typeahead predictions for [query]. Empty queries +
  /// missing API keys short-circuit to `[]` so callers can safely call
  /// this on every keystroke (still recommend debouncing in the UI).
  ///
  /// [regionCode] / [languageCode] bias the server's search (ISO 3166-1
  /// alpha-2 + IETF BCP 47 respectively). [sessionToken] groups
  /// autocomplete calls into one billing session — pass the same UUID
  /// across the whole sheet's lifetime, then again on `resolve(...)`.
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    String? regionCode,
    String? languageCode,
    String? sessionToken,
  }) async {
    final q = query.trim();
    if (q.isEmpty || _apiKey.isEmpty) return const [];

    final cacheKey = '$q|${regionCode ?? ''}|${languageCode ?? ''}';
    final cached = _autocompleteCache[cacheKey];
    if (cached != null) {
      // Move to most-recent end so frequently-hit entries survive eviction.
      _autocompleteCache.remove(cacheKey);
      _autocompleteCache[cacheKey] = cached;
      if (kDebugMode) {
        debugPrint('[PlaceSearch] autocomplete "$q" → cache hit '
            '(${cached.length} predictions)');
      }
      return cached;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final body = <String, Object?>{
        'input': q,
        if (regionCode != null && regionCode.isNotEmpty) 'regionCode': regionCode,
        if (languageCode != null && languageCode.isNotEmpty)
          'languageCode': languageCode,
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
      };
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
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 6));
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[PlaceSearch] autocomplete "$q" → '
            '${res.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      }
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List?) ?? const [];
      final out = suggestions
          .map((s) => _decodePrediction(s as Map<String, dynamic>))
          .whereType<PlacePrediction>()
          .toList(growable: false);
      _autocompleteCache[cacheKey] = out;
      while (_autocompleteCache.length > _cacheCap) {
        _autocompleteCache.remove(_autocompleteCache.keys.first);
      }
      return out;
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[PlaceSearch] autocomplete "$q" failed in '
            '${stopwatch.elapsedMilliseconds}ms: $e');
      }
      return const [];
    }
  }

  /// Resolves a [placeId] to its lat/lng + city + formatted address.
  /// Returns null when the place doesn't exist or the API fails.
  Future<PickedPlace?> resolve(
    String placeId, {
    String? sessionToken,
    String? languageCode,
  }) async {
    if (placeId.isEmpty || _apiKey.isEmpty) return null;
    final stopwatch = Stopwatch()..start();
    try {
      final params = <String, String>{
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
        if (languageCode != null && languageCode.isNotEmpty)
          'languageCode': languageCode,
      };
      final uri = Uri.parse(_detailsUrl(placeId))
          .replace(queryParameters: params.isEmpty ? null : params);
      final res = await _client
          .get(
            uri,
            headers: {
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask':
                  'location,formattedAddress,addressComponents',
            },
          )
          .timeout(const Duration(seconds: 6));
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[PlaceSearch] resolve "$placeId" → '
            '${res.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      }
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
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[PlaceSearch] resolve "$placeId" failed in '
            '${stopwatch.elapsedMilliseconds}ms: $e');
      }
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
