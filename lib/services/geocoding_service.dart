import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/destination_result.dart';

/// Exception thrown when destination geocoding fails.
class GeocodingException implements Exception {
  const GeocodingException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'GeocodingException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Cache entry for geocoded search queries.
class _CachedGeocodingEntry {
  const _CachedGeocodingEntry({required this.results, required this.cachedAt});

  final List<DestinationResult> results;
  final DateTime cachedAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;
}

/// Service providing destination search and geocoding via Open-Meteo Geocoding API.
class GeocodingService {
  GeocodingService({
    http.Client? httpClient,
    this.cacheTtl = const Duration(minutes: 30),
    this.requestTimeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client();

  static GeocodingService? _instance;
  static GeocodingService get instance => _instance ??= GeocodingService();

  static void setInstance(GeocodingService service) {
    _instance = service;
  }

  static void resetInstance() {
    _instance = null;
    testMockResults = null;
  }

  /// Global test fixture to bypass network calls in tests.
  static List<DestinationResult>? testMockResults;

  final http.Client _httpClient;
  final Duration cacheTtl;
  final Duration requestTimeout;

  static const String _baseUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  // In-memory query cache
  final Map<String, _CachedGeocodingEntry> _cache = {};

  // In-flight request deduplication
  final Map<String, Future<List<DestinationResult>>> _inFlightRequests = {};

  /// Searches for destinations matching [query].
  ///
  /// Returns empty list if [query] is shorter than 2 characters.
  /// Deduplicates concurrent requests and caches non-empty results.
  Future<List<DestinationResult>> searchDestinations(
    String query, {
    int count = 5,
    Duration? timeout,
    bool forceRefresh = false,
  }) async {
    if (testMockResults != null) {
      return testMockResults!;
    }

    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const <DestinationResult>[];
    }

    final key = '${trimmed.toLowerCase()}_$count';

    if (!forceRefresh && _cache.containsKey(key)) {
      final cached = _cache[key]!;
      if (!cached.isExpired(cacheTtl)) {
        return cached.results;
      }
    }

    if (_inFlightRequests.containsKey(key)) {
      return _inFlightRequests[key]!;
    }

    final future = _fetchFromNetwork(
      query: trimmed,
      count: count,
      timeout: timeout ?? requestTimeout,
    );

    _inFlightRequests[key] = future;

    try {
      final results = await future;
      if (results.isNotEmpty) {
        _cache[key] = _CachedGeocodingEntry(
          results: results,
          cachedAt: DateTime.now(),
        );
      }
      return results;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  Future<List<DestinationResult>> _fetchFromNetwork({
    required String query,
    required int count,
    required Duration timeout,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'name': query,
        'count': count.toString(),
        'language': 'en',
        'format': 'json',
      },
    );

    http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'TourMate/1.0 (Smart Tourism Guide App)',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GeocodingException('Geocoding request timed out.');
    } catch (e) {
      if (e is GeocodingException) rethrow;
      throw GeocodingException('Unable to reach geocoding service: $e');
    }

    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final rawResults = json['results'] as List<dynamic>?;
        if (rawResults == null || rawResults.isEmpty) {
          return const <DestinationResult>[];
        }

        final list = <DestinationResult>[];
        for (final item in rawResults) {
          if (item is Map<String, dynamic>) {
            try {
              list.add(DestinationResult.fromJson(item));
            } catch (_) {
              // Ignore individual malformed entries
            }
          }
        }
        return List.unmodifiable(list);
      } catch (e) {
        throw GeocodingException('Malformed geocoding response: $e');
      }
    } else if (response.statusCode >= 500) {
      throw GeocodingException(
        'Geocoding service temporarily unavailable.',
        statusCode: response.statusCode,
      );
    } else {
      throw GeocodingException(
        'Geocoding request failed.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Geocodes a destination name to coordinates, returning the top match or null.
  Future<DestinationResult?> geocodeDestination(String destinationName) async {
    final results = await searchDestinations(destinationName, count: 1);
    if (results.isEmpty) return null;
    return results.first;
  }

  /// Clears geocoding cache.
  void clearCache() {
    _cache.clear();
    _inFlightRequests.clear();
  }
}
