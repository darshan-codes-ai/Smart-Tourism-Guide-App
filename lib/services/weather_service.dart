import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// Exception thrown when weather retrieval or parsing fails.
class WeatherException implements Exception {
  const WeatherException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'WeatherException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Represents a cached weather entry with timestamp.
class _CachedWeatherEntry {
  const _CachedWeatherEntry({required this.data, required this.cachedAt});

  final WeatherData data;
  final DateTime cachedAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;
}

/// Service providing weather forecasts from Open-Meteo REST API.
class WeatherService {
  WeatherService({
    http.Client? httpClient,
    this.cacheTtl = const Duration(minutes: 15),
    this.requestTimeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client();

  static WeatherService? _instance;
  static WeatherService get instance => _instance ??= WeatherService();

  /// For test overrides or resetting singleton.
  static void setInstance(WeatherService service) {
    _instance = service;
  }

  static void resetInstance() {
    _instance = null;
    testMockWeather = null;
  }

  /// Global test fixture to bypass network calls entirely in tests.
  static WeatherData? testMockWeather;

  final http.Client _httpClient;
  final Duration cacheTtl;
  final Duration requestTimeout;

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  // In-memory coordinate-based cache
  final Map<String, _CachedWeatherEntry> _cache = {};

  // In-flight request deduplication
  final Map<String, Future<WeatherData>> _inFlightRequests = {};

  /// Normalizes coordinates to 3 decimal places (~110 meters) for caching.
  static String normalizeCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
  }

  /// Retrieves weather for the specified [latitude] and [longitude].
  ///
  /// Uses in-memory cache if available and not expired, unless [forceRefresh] is true.
  /// Prevents concurrent duplicate requests for the same destination coordinates.
  Future<WeatherData> getWeather({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
    Duration? timeout,
  }) async {
    // Check test fixture
    if (testMockWeather != null) {
      return testMockWeather!;
    }

    // Validate coordinates
    if (latitude < -90.0 || latitude > 90.0) {
      throw const WeatherException(
        'Invalid latitude: must be between -90.0 and 90.0.',
      );
    }
    if (longitude < -180.0 || longitude > 180.0) {
      throw const WeatherException(
        'Invalid longitude: must be between -180.0 and 180.0.',
      );
    }

    final key = normalizeCoordinates(latitude, longitude);

    // Return cached entry if valid and not forcing refresh
    if (!forceRefresh && _cache.containsKey(key)) {
      final cached = _cache[key]!;
      if (!cached.isExpired(cacheTtl)) {
        return cached.data;
      }
    }

    // Return existing in-flight request if one is active
    if (_inFlightRequests.containsKey(key)) {
      return _inFlightRequests[key]!;
    }

    // Launch request with deduplication
    final future = _fetchFromNetwork(
      latitude: latitude,
      longitude: longitude,
      timeout: timeout ?? requestTimeout,
    );

    _inFlightRequests[key] = future;

    try {
      final result = await future;
      _cache[key] = _CachedWeatherEntry(data: result, cachedAt: DateTime.now());
      return result;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  Future<WeatherData> _fetchFromNetwork({
    required double latitude,
    required double longitude,
    required Duration timeout,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum',
        'timezone': 'auto',
        'forecast_days': '7',
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
      throw const WeatherException(
        'Weather request timed out. Please try again.',
      );
    } catch (e) {
      if (e is WeatherException) rethrow;
      throw WeatherException('Unable to reach weather service: $e');
    }

    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        return WeatherData.fromOpenMeteoJson(json);
      } catch (e) {
        throw WeatherException('Malformed weather data response: $e');
      }
    } else if (response.statusCode == 400) {
      throw const WeatherException(
        'Invalid weather request parameters.',
        statusCode: 400,
      );
    } else if (response.statusCode == 429) {
      throw const WeatherException(
        'Open-Meteo rate limit exceeded. Please wait a moment.',
        statusCode: 429,
      );
    } else if (response.statusCode >= 500) {
      throw WeatherException(
        'Weather service temporarily unavailable.',
        statusCode: response.statusCode,
      );
    } else {
      throw WeatherException(
        'Unexpected weather service response.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Returns cached weather data even if expired (for offline/graceful degradation).
  WeatherData? getStaleWeather(double latitude, double longitude) {
    final key = normalizeCoordinates(latitude, longitude);
    return _cache[key]?.data;
  }

  /// Check whether valid cache exists for coordinates.
  bool hasValidCache(double latitude, double longitude) {
    final key = normalizeCoordinates(latitude, longitude);
    final entry = _cache[key];
    return entry != null && !entry.isExpired(cacheTtl);
  }

  /// Clears in-memory cache and in-flight tracking.
  void clearCache() {
    _cache.clear();
    _inFlightRequests.clear();
  }
}
