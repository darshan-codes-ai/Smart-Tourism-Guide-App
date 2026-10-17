import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/models/destination_result.dart';
import 'package:tourmate/models/trip.dart';
import 'package:tourmate/models/weather.dart';
import 'package:tourmate/services/geocoding_service.dart';
import 'package:tourmate/services/weather_service.dart';
import 'package:tourmate/widgets/destination_search_sheet.dart';
import 'package:tourmate/widgets/trip_weather_card.dart';
import 'package:tourmate/widgets/weather_section.dart';

/// Deterministic mock HTTP client for test suite.
class MockHttpClient extends http.BaseClient {
  MockHttpClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    final response = await _handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

Widget buildTestableWidget(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  tearDown(() {
    WeatherService.resetInstance();
    GeocodingService.resetInstance();
  });

  group('1. Weather Model & WMO Code Tests', () {
    test('maps standard WMO weather codes to conditions and icons', () {
      expect(WeatherCondition.fromWmoCode(0).description, 'Clear sky');
      expect(WeatherCondition.fromWmoCode(1).description, 'Mainly clear');
      expect(WeatherCondition.fromWmoCode(2).description, 'Partly cloudy');
      expect(WeatherCondition.fromWmoCode(3).description, 'Overcast');
      expect(WeatherCondition.fromWmoCode(45).description, 'Fog');
      expect(WeatherCondition.fromWmoCode(51).description, 'Light drizzle');
      expect(WeatherCondition.fromWmoCode(61).description, 'Slight rain');
      expect(WeatherCondition.fromWmoCode(63).description, 'Moderate rain');
      expect(WeatherCondition.fromWmoCode(65).description, 'Heavy rain');
      expect(WeatherCondition.fromWmoCode(71).description, 'Slight snow');
      expect(
        WeatherCondition.fromWmoCode(80).description,
        'Slight rain showers',
      );
      expect(WeatherCondition.fromWmoCode(95).description, 'Thunderstorm');
      expect(
        WeatherCondition.fromWmoCode(96).description,
        'Thunderstorm with hail',
      );
      expect(WeatherCondition.fromWmoCode(null).description, 'Unknown');
      expect(WeatherCondition.fromWmoCode(999).description, contains('999'));
    });

    test(
      'CurrentWeather parses valid JSON and handles missing optional fields',
      () {
        final json = <String, dynamic>{
          'temperature_2m': 22.5,
          'apparent_temperature': 21.0,
          'relative_humidity_2m': 55,
          'precipitation': 0.0,
          'wind_speed_10m': 14.2,
          'weather_code': 2,
          'time': '2026-10-17T12:00',
        };

        final current = CurrentWeather.fromJson(json);
        expect(current.temperature, 22.5);
        expect(current.apparentTemperature, 21.0);
        expect(current.relativeHumidity, 55);
        expect(current.precipitation, 0.0);
        expect(current.windSpeed, 14.2);
        expect(current.weatherCode, 2);
        expect(current.condition.description, 'Partly cloudy');

        // Minimal JSON with only required temperature
        final minJson = <String, dynamic>{'temperature': 18.0};
        final minCurrent = CurrentWeather.fromJson(minJson);
        expect(minCurrent.temperature, 18.0);
        expect(minCurrent.apparentTemperature, isNull);
        expect(minCurrent.relativeHumidity, isNull);
        expect(minCurrent.precipitation, isNull);
        expect(minCurrent.windSpeed, isNull);
      },
    );

    test(
      'CurrentWeather throws FormatException when temperature is missing',
      () {
        expect(
          () => CurrentWeather.fromJson(<String, dynamic>{'weather_code': 0}),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'WeatherData parses complete Open-Meteo payload and roundtrips to JSON',
      () {
        final payload = <String, dynamic>{
          'latitude': 48.8566,
          'longitude': 2.3522,
          'timezone': 'Europe/Paris',
          'timezone_abbreviation': 'CEST',
          'elevation': 42.0,
          'current': <String, dynamic>{
            'temperature_2m': 19.5,
            'apparent_temperature': 18.2,
            'relative_humidity_2m': 62,
            'precipitation': 0.1,
            'wind_speed_10m': 11.5,
            'weather_code': 1,
            'time': '2026-10-17T14:00',
          },
          'daily': <String, dynamic>{
            'time': ['2026-10-17', '2026-10-18', '2026-10-19'],
            'weather_code': [1, 2, 61],
            'temperature_2m_max': [21.0, 20.5, 17.0],
            'temperature_2m_min': [12.0, 11.5, 9.0],
            'precipitation_sum': [0.0, 0.2, 3.5],
          },
        };

        final weather = WeatherData.fromOpenMeteoJson(payload);
        expect(weather.latitude, 48.8566);
        expect(weather.longitude, 2.3522);
        expect(weather.timezone, 'Europe/Paris');
        expect(weather.current.temperature, 19.5);
        expect(weather.daily.length, 3);
        expect(weather.daily[0].maxTemperature, 21.0);
        expect(weather.daily[0].minTemperature, 12.0);
        expect(weather.daily[2].condition.description, 'Slight rain');

        // Check forecastForDate helper
        final targetDate = DateTime(2026, 10, 18);
        final match = weather.forecastForDate(targetDate);
        expect(match, isNotNull);
        expect(match!.maxTemperature, 20.5);

        final nonExistentDate = DateTime(2026, 11, 1);
        expect(weather.forecastForDate(nonExistentDate), isNull);

        // JSON serialization
        final serialized = weather.toJson();
        expect(serialized['latitude'], 48.8566);
        expect(serialized['current']['temperature_2m'], 19.5);
      },
    );

    test('WeatherData throws FormatException when coordinates are missing', () {
      expect(
        () =>
            WeatherData.fromOpenMeteoJson(<String, dynamic>{'timezone': 'UTC'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('2. Destination Geocoding Model Tests', () {
    test('DestinationResult parses valid Open-Meteo geocoding JSON', () {
      final json = <String, dynamic>{
        'id': 2988507,
        'name': 'Paris',
        'latitude': 48.8534,
        'longitude': 2.3488,
        'country': 'France',
        'country_code': 'FR',
        'admin1': 'Île-de-France',
        'elevation': 42.0,
        'timezone': 'Europe/Paris',
        'population': 2138551,
      };

      final dest = DestinationResult.fromJson(json);
      expect(dest.id, 2988507);
      expect(dest.name, 'Paris');
      expect(dest.latitude, 48.8534);
      expect(dest.longitude, 2.3488);
      expect(dest.displayName, 'Paris, Île-de-France, France');
      expect(dest.subtitle, 'Île-de-France, France');

      final serialized = dest.toJson();
      expect(serialized['name'], 'Paris');
      expect(serialized['country'], 'France');
    });

    test('DestinationResult throws FormatException when name or coordinates are missing', () {
      expect(
        () => DestinationResult.fromJson(<String, dynamic>{
          'latitude': 48.0,
          'longitude': 2.0,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DestinationResult.fromJson(<String, dynamic>{'name': 'Rome'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('3. WeatherService Unit Tests', () {
    test('retrieves weather successfully via HTTP', () async {
      final mockPayload = jsonEncode(<String, dynamic>{
        'latitude': 35.6762,
        'longitude': 139.6503,
        'timezone': 'Asia/Tokyo',
        'current': <String, dynamic>{
          'temperature_2m': 17.8,
          'weather_code': 0,
          'time': '2026-10-17T15:00',
        },
        'daily': <String, dynamic>{
          'time': ['2026-10-17'],
          'weather_code': [0],
          'temperature_2m_max': [20.0],
          'temperature_2m_min': [13.0],
        },
      });

      final mockClient = MockHttpClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.queryParameters['latitude'], '35.6762');
        return http.Response(mockPayload, 200);
      });

      final service = WeatherService(httpClient: mockClient);
      final weather = await service.getWeather(
        latitude: 35.6762,
        longitude: 139.6503,
      );

      expect(weather.current.temperature, 17.8);
      expect(weather.timezone, 'Asia/Tokyo');
      expect(mockClient.callCount, 1);
    });

    test('validates coordinate boundaries', () async {
      final service = WeatherService();
      expect(
        () => service.getWeather(latitude: 95.0, longitude: 0.0),
        throwsA(
          isA<WeatherException>().having(
            (e) => e.message,
            'msg',
            contains('latitude'),
          ),
        ),
      );
      expect(
        () => service.getWeather(latitude: 0.0, longitude: -185.0),
        throwsA(
          isA<WeatherException>().having(
            (e) => e.message,
            'msg',
            contains('longitude'),
          ),
        ),
      );
    });

    test(
      'uses in-memory cache and prevents repeated requests within TTL',
      () async {
        final mockPayload = jsonEncode(<String, dynamic>{
          'latitude': 41.9028,
          'longitude': 12.4964,
          'current': {
            'temperature_2m': 20.0,
            'weather_code': 0,
            'time': '2026-10-17T12:00',
          },
          'daily': {
            'time': [],
            'weather_code': [],
            'temperature_2m_max': [],
            'temperature_2m_min': [],
          },
        });

        final mockClient = MockHttpClient(
          (_) async => http.Response(mockPayload, 200),
        );
        final service = WeatherService(
          httpClient: mockClient,
          cacheTtl: const Duration(minutes: 15),
        );

        // First call -> network request
        final weather1 = await service.getWeather(
          latitude: 41.9028,
          longitude: 12.4964,
        );
        expect(weather1.current.temperature, 20.0);
        expect(mockClient.callCount, 1);

        // Second call -> cached, no additional HTTP call
        final weather2 = await service.getWeather(
          latitude: 41.9028,
          longitude: 12.4964,
        );
        expect(weather2.current.temperature, 20.0);
        expect(mockClient.callCount, 1);

        // Force refresh -> bypasses cache and triggers call
        final weather3 = await service.getWeather(
          latitude: 41.9028,
          longitude: 12.4964,
          forceRefresh: true,
        );
        expect(weather3.current.temperature, 20.0);
        expect(mockClient.callCount, 2);
      },
    );

    test('deduplicates concurrent identical requests', () async {
      final completer = Completer<http.Response>();
      final mockPayload = jsonEncode(<String, dynamic>{
        'latitude': 51.5074,
        'longitude': -0.1278,
        'current': {
          'temperature_2m': 15.0,
          'weather_code': 3,
          'time': '2026-10-17T12:00',
        },
        'daily': {
          'time': [],
          'weather_code': [],
          'temperature_2m_max': [],
          'temperature_2m_min': [],
        },
      });

      final mockClient = MockHttpClient((_) => completer.future);
      final service = WeatherService(httpClient: mockClient);

      // Launch 3 requests concurrently
      final f1 = service.getWeather(latitude: 51.5074, longitude: -0.1278);
      final f2 = service.getWeather(latitude: 51.5074, longitude: -0.1278);
      final f3 = service.getWeather(latitude: 51.5074, longitude: -0.1278);

      completer.complete(http.Response(mockPayload, 200));

      final results = await Future.wait([f1, f2, f3]);
      expect(results[0].current.temperature, 15.0);
      expect(results[1].current.temperature, 15.0);
      expect(results[2].current.temperature, 15.0);
      // Only 1 network call was initiated!
      expect(mockClient.callCount, 1);
    });

    test('handles HTTP errors and does not cache failures', () async {
      final mockClient = MockHttpClient(
        (_) async => http.Response('Rate limit exceeded', 429),
      );
      final service = WeatherService(httpClient: mockClient);

      expect(
        () => service.getWeather(latitude: 40.7128, longitude: -74.0060),
        throwsA(
          isA<WeatherException>().having(
            (e) => e.statusCode,
            'statusCode',
            429,
          ),
        ),
      );

      // Ensure failed request was not cached
      expect(service.hasValidCache(40.7128, -74.0060), isFalse);
    });

    test('handles network timeouts gracefully', () async {
      final mockClient = MockHttpClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });

      final service = WeatherService(
        httpClient: mockClient,
        requestTimeout: const Duration(milliseconds: 10),
      );

      expect(
        () => service.getWeather(latitude: 0.0, longitude: 0.0),
        throwsA(
          isA<WeatherException>().having(
            (e) => e.message,
            'msg',
            contains('timed out'),
          ),
        ),
      );
    });
  });

  group('4. GeocodingService Unit Tests', () {
    test('returns empty results for queries under 2 characters without network call', () async {
      final mockClient = MockHttpClient((_) async => http.Response('{}', 200));
      final service = GeocodingService(httpClient: mockClient);

      final empty1 = await service.searchDestinations('');
      final empty2 = await service.searchDestinations('A');

      expect(empty1, isEmpty);
      expect(empty2, isEmpty);
      expect(mockClient.callCount, 0);
    });

    test('searches destinations and parses results', () async {
      final mockPayload = jsonEncode(<String, dynamic>{
        'results': [
          {
            'id': 2988507,
            'name': 'Paris',
            'latitude': 48.8534,
            'longitude': 2.3488,
            'country': 'France',
            'admin1': 'Île-de-France',
          },
          {
            'id': 4717560,
            'name': 'Paris',
            'latitude': 33.6609,
            'longitude': -95.5555,
            'country': 'United States',
            'admin1': 'Texas',
          },
        ],
      });

      final mockClient = MockHttpClient((request) async {
        expect(request.url.queryParameters['name'], 'Paris');
        return http.Response(mockPayload, 200);
      });

      final service = GeocodingService(httpClient: mockClient);
      final results = await service.searchDestinations('Paris');

      expect(results.length, 2);
      expect(results[0].name, 'Paris');
      expect(results[0].country, 'France');
      expect(results[1].country, 'United States');
      expect(mockClient.callCount, 1);

      // Cache test
      final cached = await service.searchDestinations('Paris');
      expect(cached.length, 2);
      expect(mockClient.callCount, 1);
    });

    test('geocodeDestination helper returns top result or null', () async {
      final mockPayload = jsonEncode(<String, dynamic>{
        'results': [
          {
            'id': 1850147,
            'name': 'Tokyo',
            'latitude': 35.6895,
            'longitude': 139.6917,
            'country': 'Japan',
          },
        ],
      });

      final mockClient = MockHttpClient(
        (_) async => http.Response(mockPayload, 200),
      );
      final service = GeocodingService(httpClient: mockClient);

      final tokyo = await service.geocodeDestination('Tokyo');
      expect(tokyo, isNotNull);
      expect(tokyo!.name, 'Tokyo');
      expect(tokyo.latitude, 35.6895);

      final emptyMock = MockHttpClient(
        (_) async => http.Response('{"results": []}', 200),
      );
      final emptyService = GeocodingService(httpClient: emptyMock);
      final none = await emptyService.geocodeDestination('NonExistentCityXYZ');
      expect(none, isNull);
    });
  });

  group('5. Weather UI Widget Tests', () {
    final sampleWeatherData = WeatherData(
      latitude: 48.8566,
      longitude: 2.3522,
      timezone: 'Europe/Paris',
      current: CurrentWeather(
        temperature: 21.4,
        apparentTemperature: 20.0,
        relativeHumidity: 58,
        precipitation: 0.0,
        windSpeed: 12.0,
        weatherCode: 1,
        time: DateTime.now(),
      ),
      daily: [
        DailyForecast(
          date: DateTime.now(),
          weatherCode: 1,
          minTemperature: 14.0,
          maxTemperature: 23.0,
        ),
        DailyForecast(
          date: DateTime.now().add(const Duration(days: 1)),
          weatherCode: 2,
          minTemperature: 13.0,
          maxTemperature: 22.0,
        ),
      ],
    );

    testWidgets('WeatherSection displays loading state then weather metrics', (
      tester,
    ) async {
      WeatherService.testMockWeather = sampleWeatherData;

      await tester.pumpWidget(
        buildTestableWidget(
          const WeatherSection(
            latitude: 48.8566,
            longitude: 2.3522,
            destinationName: 'Paris',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Destination title
      expect(find.text('Paris Weather'), findsOneWidget);
      // Temperature
      expect(find.text('21°C'), findsOneWidget);
      expect(find.text('Feels like 20°C'), findsOneWidget);
      expect(find.text('Mainly clear'), findsOneWidget);
      expect(find.text('58% humidity'), findsOneWidget);
      expect(find.text('12 km/h wind'), findsOneWidget);
      // Forecast header
      expect(find.text('7-Day Forecast'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      // Attribution
      expect(find.text('Weather data by Open-Meteo'), findsOneWidget);
      expect(
        find.byKey(const Key('open_meteo_attribution_link')),
        findsOneWidget,
      );
    });

    testWidgets(
      'WeatherSection displays empty state when coordinates are missing and cannot be geocoded',
      (tester) async {
        WeatherService.testMockWeather = null;
        GeocodingService.testMockResults = const [];

        await tester.pumpWidget(
          buildTestableWidget(
            const WeatherSection(
              latitude: null,
              longitude: null,
              destinationName: '',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Weather forecast unavailable for this destination.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('WeatherSection displays error state with retry button', (
      tester,
    ) async {
      final mockClient = MockHttpClient(
        (_) async => http.Response('Server Error', 500),
      );
      WeatherService.setInstance(WeatherService(httpClient: mockClient));

      await tester.pumpWidget(
        buildTestableWidget(
          const WeatherSection(
            latitude: 48.8566,
            longitude: 2.3522,
            destinationName: 'Paris',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weather information unavailable'), findsOneWidget);
      expect(find.byKey(const Key('weather_retry_button')), findsOneWidget);
    });

    testWidgets('TripWeatherCard correlates trip dates with forecast horizon', (
      tester,
    ) async {
      WeatherService.testMockWeather = sampleWeatherData;

      final now = DateTime.now();
      final currentTrip = Trip(
        id: 'trip-weather-1',
        userId: 'u1',
        name: 'Weekend in Paris',
        destination: 'Paris',
        startDate: now,
        endDate: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          TripWeatherCard(
            trip: currentTrip,
            fallbackLatitude: 48.8566,
            fallbackLongitude: 2.3522,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paris Weather Forecast'), findsOneWidget);
      expect(find.text('21°C'), findsOneWidget);
      expect(find.text('Forecast for your Trip Days:'), findsOneWidget);
      expect(find.textContaining('Day 1'), findsOneWidget);
      expect(
        find.byKey(const Key('trip_weather_open_meteo_attribution')),
        findsOneWidget,
      );
    });

    testWidgets(
      'TripWeatherCard displays notice when trip is beyond forecast horizon',
      (tester) async {
        WeatherService.testMockWeather = sampleWeatherData;

        final now = DateTime.now();
        final futureTrip = Trip(
          id: 'trip-weather-future',
          userId: 'u1',
          name: 'Future Summer Vacation',
          destination: 'Paris',
          startDate: now.add(const Duration(days: 30)),
          endDate: now.add(const Duration(days: 35)),
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            TripWeatherCard(
              trip: futureTrip,
              fallbackLatitude: 48.8566,
              fallbackLongitude: 2.3522,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('beyond the 7-day forecast horizon'),
          findsOneWidget,
        );
      },
    );
  });

  group('6. DestinationSearchSheet Integration Tests', () {
    testWidgets(
      'DestinationSearchSheet allows searching and selecting destinations',
      (tester) async {
        GeocodingService.testMockResults = [
          const DestinationResult(
            id: 3117735,
            name: 'Madrid',
            latitude: 40.4168,
            longitude: -3.7038,
            country: 'Spain',
            admin1: 'Madrid',
          ),
        ];
        WeatherService.testMockWeather = WeatherData(
          latitude: 40.4168,
          longitude: -3.7038,
          current: CurrentWeather(
            temperature: 25.0,
            weatherCode: 0,
            time: DateTime.now(),
          ),
        );

        DestinationResult? selectedResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: DestinationSearchSheet(
                onDestinationSelected: (res) => selectedResult = res,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Destination Search & Weather'), findsOneWidget);
        final searchInput = find.byKey(
          const Key('destination_search_input_field'),
        );
        expect(searchInput, findsOneWidget);

        await tester.enterText(searchInput, 'Madrid');
        // Wait for 350ms debounce
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Madrid'), findsWidgets);
        expect(find.text('Spain'), findsWidgets);

        // Tap on Madrid result tile
        await tester.tap(
          find.byKey(const Key('destination_result_tile_3117735')),
        );
        await tester.pumpAndSettle();

        // Destination expanded: shows weather and actions
        expect(find.text('Madrid Weather'), findsOneWidget);
        expect(find.text('Select Destination'), findsOneWidget);
        expect(find.text('Plan Trip'), findsOneWidget);

        await tester.tap(find.text('Select Destination'));
        await tester.pumpAndSettle();

        expect(selectedResult, isNotNull);
        expect(selectedResult!.name, 'Madrid');
        expect(selectedResult!.country, 'Spain');
      },
    );
  });
}
