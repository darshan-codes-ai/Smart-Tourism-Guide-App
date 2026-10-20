import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/models/review.dart';
import 'package:tourmate/models/trip.dart';
import 'package:tourmate/models/weather.dart';
import 'package:tourmate/screens/auth/login_screen.dart';
import 'package:tourmate/screens/auth/register_screen.dart';
import 'package:tourmate/services/geocoding_service.dart';
import 'package:tourmate/services/review_service.dart';
import 'package:tourmate/services/trip_service.dart';
import 'package:tourmate/services/weather_service.dart';
import 'package:tourmate/widgets/attraction_card.dart';
import 'package:tourmate/widgets/destination_search_sheet.dart';
import 'package:tourmate/widgets/reviews_section.dart';
import 'package:tourmate/widgets/trip_form_sheet.dart';
import 'package:tourmate/widgets/trip_weather_card.dart';
import 'package:tourmate/widgets/weather_section.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SavedPlacesStore.instance.resetForTest();
    TripService.resetForTest();
    WeatherService.resetInstance();
    GeocodingService.resetInstance();
    ReviewService.resetForTest();
  });

  tearDown(() {
    SavedPlacesStore.instance.resetForTest();
    TripService.resetForTest();
    WeatherService.resetInstance();
    GeocodingService.resetInstance();
    ReviewService.resetForTest();
  });

  group('Phase 10: Performance Optimization & Bounded Cache Tests', () {
    test('WeatherService bounds cache entries to maxCacheEntries (100) using FIFO pruning', () async {
      int requestCount = 0;
      final mockClient = MockHttpClient((request) async {
        requestCount++;
        final jsonResponse = jsonEncode({
          'latitude': 10.0,
          'longitude': 10.0,
          'timezone': 'UTC',
          'current': {
            'temperature_2m': 20.0,
            'apparent_temperature': 20.0,
            'relative_humidity_2m': 50,
            'precipitation': 0.0,
            'wind_speed_10m': 5.0,
            'weather_code': 0,
            'time': '2026-10-17T12:00',
          },
          'daily': {
            'time': ['2026-10-17'],
            'weather_code': [0],
            'temperature_2m_max': [25.0],
            'temperature_2m_min': [15.0],
          },
        });
        return http.Response(jsonResponse, 200);
      });

      final service = WeatherService(httpClient: mockClient);

      // Populate 105 distinct coordinate entries
      for (int i = 0; i < 105; i++) {
        final lat = 10.0 + (i * 0.1);
        final lng = 20.0 + (i * 0.1);
        await service.getWeather(latitude: lat, longitude: lng);
      }

      expect(requestCount, 105);

      // Earliest coordinate (10.0, 20.0) should have been pruned
      expect(service.hasValidCache(10.0, 20.0), isFalse);

      // Latest coordinate (10.0 + 104*0.1 = 20.4, 20.0 + 104*0.1 = 30.4) should still be cached
      final lastLat = 10.0 + (104 * 0.1);
      final lastLng = 20.0 + (104 * 0.1);
      expect(service.hasValidCache(lastLat, lastLng), isTrue);

      // Requesting the last coordinate should hit the cache without calling the network
      final initialCalls = mockClient.callCount;
      await service.getWeather(latitude: lastLat, longitude: lastLng);
      expect(mockClient.callCount, initialCalls);
    });

    test('GeocodingService bounds cache entries to maxCacheEntries (100) using FIFO pruning', () async {
      int requestCount = 0;
      final mockClient = MockHttpClient((request) async {
        requestCount++;
        final queryParam = request.url.queryParameters['name'] ?? 'City';
        final jsonResponse = jsonEncode({
          'results': [
            {
              'id': requestCount,
              'name': queryParam,
              'latitude': 35.0,
              'longitude': 139.0,
              'country': 'Japan',
              'country_code': 'JP',
            },
          ],
        });
        return http.Response(jsonResponse, 200);
      });

      final service = GeocodingService(httpClient: mockClient);

      // Populate 105 distinct geocoding query entries
      for (int i = 0; i < 105; i++) {
        await service.searchDestinations('City_$i');
      }

      expect(requestCount, 105);

      // Earliest query ('City_0') should have been pruned
      expect(service.hasValidCache('City_0'), isFalse);

      // Latest query ('City_104') should still be cached
      expect(service.hasValidCache('City_104'), isTrue);

      // Searching 'City_104' again should return cached results without a network call
      final initialCalls = mockClient.callCount;
      final cachedResults = await service.searchDestinations('City_104');
      expect(cachedResults, isNotEmpty);
      expect(mockClient.callCount, initialCalls);
    });
  });

  group('Phase 10: Accessibility & Semantics Widget Tests', () {
    const testAttraction = Attraction(
      id: 'test_attr_10',
      name: 'Eiffel Tower',
      category: 'Monument',
      description: 'Iconic iron lattice tower on the Champ de Mars.',
      imageUrl: 'https://example.com/eiffel.jpg',
      rating: 4.9,
      distance: '3.5 km',
      location: 'Paris, France',
      openingHours: '9:00 AM - 11:00 PM',
      entryFee: '€25',
      latitude: 48.8584,
      longitude: 2.2945,
    );

    testWidgets(
      'AttractionCard favorite button has accessible Tooltip and Semantics label',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(const AttractionCard(attraction: testAttraction)),
        );
        await tester.pumpAndSettle();

        // Verify Tooltip and Semantics initially indicate 'Add to favorites'
        expect(find.byTooltip('Add to favorites'), findsOneWidget);
        final semanticsFinder = find.bySemanticsLabel('Add to favorites');
        expect(semanticsFinder, findsOneWidget);

        // Tap the favorite button to save
        await tester.tap(find.byTooltip('Add to favorites'));
        await tester.pumpAndSettle();

        // Now Tooltip and Semantics should update to 'Remove from favorites'
        expect(find.byTooltip('Remove from favorites'), findsOneWidget);
        expect(find.bySemanticsLabel('Remove from favorites'), findsOneWidget);
      },
    );

    testWidgets(
      'WeatherSection displays semantic labels on condition icon and attribution link',
      (tester) async {
        final sampleWeather = WeatherData(
          latitude: 48.8584,
          longitude: 2.2945,
          timezone: 'Europe/Paris',
          current: CurrentWeather(
            temperature: 18.5,
            apparentTemperature: 18.0,
            relativeHumidity: 65,
            precipitation: 0.0,
            windSpeed: 10.0,
            weatherCode: 0,
            time: DateTime.now(),
          ),
          daily: [
            DailyForecast(
              date: DateTime.now(),
              weatherCode: 0,
              minTemperature: 12.0,
              maxTemperature: 20.0,
            ),
          ],
        );

        WeatherService.testMockWeather = sampleWeather;

        await tester.pumpWidget(
          buildTestableWidget(
            const WeatherSection(
              latitude: 48.8584,
              longitude: 2.2945,
              destinationName: 'Paris',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Condition icon should have semantics describing the weather condition
        expect(
          find.bySemanticsLabel('Weather condition: Clear sky'),
          findsOneWidget,
        );

        // Attribution link should have semantics for screen readers
        expect(
          find.bySemanticsLabel('Open Open-Meteo weather website'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TripWeatherCard displays semantic labels on condition icon and attribution link',
      (tester) async {
        final sampleWeather = WeatherData(
          latitude: 35.6762,
          longitude: 139.6503,
          timezone: 'Asia/Tokyo',
          current: CurrentWeather(
            temperature: 22.0,
            apparentTemperature: 21.0,
            relativeHumidity: 50,
            precipitation: 0.0,
            windSpeed: 8.0,
            weatherCode: 1,
            time: DateTime.now(),
          ),
          daily: [
            DailyForecast(
              date: DateTime.now(),
              weatherCode: 1,
              minTemperature: 15.0,
              maxTemperature: 23.0,
            ),
          ],
        );

        WeatherService.testMockWeather = sampleWeather;

        final testTrip = Trip(
          id: 'trip_10',
          userId: 'user_10',
          name: 'Tokyo Trip',
          destination: 'Tokyo, Japan',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 4)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            TripWeatherCard(
              trip: testTrip,
              fallbackLatitude: 35.6762,
              fallbackLongitude: 139.6503,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Condition icon should have semantics describing the weather condition
        expect(
          find.bySemanticsLabel('Weather condition: Mainly clear'),
          findsOneWidget,
        );

        // Attribution link should have semantics
        expect(
          find.bySemanticsLabel('Open Open-Meteo weather website'),
          findsOneWidget,
        );
      },
    );

    testWidgets('DestinationSearchSheet clear button has accessible tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const DestinationSearchSheet(initialQuery: 'Rome')),
      );
      await tester.pumpAndSettle();

      // Clear button should have tooltip 'Clear search'
      expect(find.byTooltip('Clear search'), findsOneWidget);
    });

    testWidgets(
      'TripFormSheet traveler count stepper buttons have accessible tooltips',
      (tester) async {
        await tester.pumpWidget(buildTestableWidget(const TripFormSheet()));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Decrease travelers'), findsOneWidget);
        expect(find.byTooltip('Increase travelers'), findsOneWidget);
      },
    );

    testWidgets(
      'LoginScreen password field has accessible visibility toggle tooltip',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
        );
        await tester.pumpAndSettle();

        // Initially password is obscured
        expect(find.byTooltip('Show password'), findsOneWidget);

        // Tap toggle
        await tester.tap(find.byTooltip('Show password'));
        await tester.pumpAndSettle();

        // Now tooltip should update to 'Hide password'
        expect(find.byTooltip('Hide password'), findsOneWidget);
      },
    );

    testWidgets(
      'RegisterScreen password field has accessible visibility toggle tooltip',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: const RegisterScreen()),
        );
        await tester.pumpAndSettle();

        // Initially password is obscured
        expect(find.byTooltip('Show password'), findsOneWidget);

        // Tap toggle
        await tester.tap(find.byTooltip('Show password'));
        await tester.pumpAndSettle();

        // Now tooltip should update to 'Hide password'
        expect(find.byTooltip('Hide password'), findsOneWidget);
      },
    );

    testWidgets('ReviewsSection write review stars have accessible tooltips', (
      tester,
    ) async {
      ReviewService.testStreamReviews = (_) => Stream.value(const <Review>[]);

      await tester.pumpWidget(
        buildTestableWidget(
          const ReviewsSection(
            attractionId: 'test_attr_10',
            currentUserId: 'test_user_1',
            currentUserName: 'Tester',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap write review button
      await tester.tap(find.byKey(const Key('reviews_section_write_button')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('1 star'), findsOneWidget);
      expect(find.byTooltip('2 stars'), findsOneWidget);
      expect(find.byTooltip('3 stars'), findsOneWidget);
      expect(find.byTooltip('4 stars'), findsOneWidget);
      expect(find.byTooltip('5 stars'), findsOneWidget);
    });
  });
}
