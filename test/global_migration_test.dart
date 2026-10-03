import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/constants/app_constants.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/core/utils/currency_formatter.dart';
import 'package:tourmate/core/utils/location_helper.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/screens/main/explore_screen.dart';
import 'package:tourmate/screens/main/home_screen.dart';
import 'package:tourmate/screens/main/map_screen.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/seed_service.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  tearDown(() {
    AttractionService.testStream = null;
    SavedPlacesStore.instance.resetForTest();
  });

  group('Global Migration - CurrencyFormatter tests', () {
    test('formats zero fees as Free', () {
      expect(CurrencyFormatter.format(0, currency: 'USD'), 'Free');
      expect(CurrencyFormatter.format(0, currency: 'EUR'), 'Free');
      expect(CurrencyFormatter.format(0, currency: 'INR'), 'Free');
    });

    test('formats diverse global currencies correctly', () {
      expect(CurrencyFormatter.format(29, currency: 'EUR'), '€29');
      expect(CurrencyFormatter.format(25, currency: 'USD'), '\$25');
      expect(CurrencyFormatter.format(30, currency: 'GBP'), '£30');
      expect(CurrencyFormatter.format(2100, currency: 'JPY'), '¥2,100');
      expect(CurrencyFormatter.format(50, currency: 'INR'), '₹50');
      expect(CurrencyFormatter.format(179, currency: 'AED'), 'AED 179');
      expect(CurrencyFormatter.format(43, currency: 'AUD'), 'A\$43');
      expect(CurrencyFormatter.format(80, currency: 'BRL'), 'R\$80');
      expect(CurrencyFormatter.format(240, currency: 'EGP'), 'EGP 240');
      expect(CurrencyFormatter.format(28, currency: 'SGD'), 'S\$28');
    });
  });

  group('Global Migration - LocationHelper tests', () {
    test('calculates approximate distance using Haversine formula', () {
      // Paris (48.8584, 2.2945) to London (51.5007, -0.1246) is ~343 km
      final dist = LocationHelper.distanceBetween(
        48.8584,
        2.2945,
        51.5007,
        -0.1246,
      );
      expect(dist, greaterThan(330));
      expect(dist, lessThan(360));
    });

    test('formats distance into human-friendly strings', () {
      expect(LocationHelper.formatDistance(0.45), '450 m');
      expect(LocationHelper.formatDistance(4.5), '4.5 km');
      expect(LocationHelper.formatDistance(343.2), '343 km');
      expect(LocationHelper.formatDistance(12400.0), '12,400 km');
    });
  });

  group('Global Migration - Attraction model worldwide fields', () {
    test('serializes and deserializes worldwide fields with backward compatibility', () {
      final doc = <String, dynamic>{
        'name': 'Eiffel Tower',
        'category': 'Historical',
        'description': 'Lattice tower in Paris.',
        'imageUrl': 'https://example.com/paris.jpg',
        'rating': 4.7,
        'city': 'Paris',
        'country': 'France',
        'countryCode': 'FR',
        'reviewCount': 324000,
        'popularity': 98.5,
        'currency': 'EUR',
        'openingTime': '09:00',
        'closingTime': '23:45',
        'distance': '2.5 km',
        'location': 'Paris, France',
        'openingHours': '9:00 AM - 11:45 PM',
        'entryFee': '€29',
        'latitude': 48.8584,
        'longitude': 2.2945,
      };

      final attraction = Attraction.fromFirestore('eiffel', doc);
      expect(attraction.city, 'Paris');
      expect(attraction.country, 'France');
      expect(attraction.countryCode, 'FR');
      expect(attraction.reviewCount, 324000);
      expect(attraction.popularity, 98.5);
      expect(attraction.currency, 'EUR');
      expect(attraction.displayLocation, 'Paris, France');
      expect(attraction.formattedFee, '€29');

      final serialized = attraction.toFirestore();
      expect(serialized['city'], 'Paris');
      expect(serialized['country'], 'France');
      expect(serialized['countryCode'], 'FR');
      expect(serialized['currency'], 'EUR');
    });

    test('backward compatibility: missing city/country does not default to Hyderabad or India', () {
      final legacyDoc = <String, dynamic>{
        'name': 'Ancient Monument',
        'category': 'Historical',
        'description': 'Historic site without city tag',
        'location': 'Unknown region',
      };

      final attraction = Attraction.fromFirestore('legacy_1', legacyDoc);
      expect(attraction.city, '');
      expect(attraction.country, '');
      expect(attraction.countryCode, isNull);
      expect(attraction.displayLocation, 'Unknown region');
      expect(attraction.city.contains('Hyderabad'), isFalse);
      expect(attraction.country.contains('India'), isFalse);
    });
  });

  group('Global Migration - Dummy dataset representation', () {
    test('contains at least 20 attractions across >= 10 countries', () {
      final attractions = DummyData.attractions;
      expect(attractions.length, greaterThanOrEqualTo(20));

      final countries = attractions
          .map((a) => a.country)
          .where((c) => c.isNotEmpty)
          .toSet();
      expect(countries.length, greaterThanOrEqualTo(10));

      final cities = attractions
          .map((a) => a.city)
          .where((c) => c.isNotEmpty)
          .toSet();
      expect(cities.length, greaterThanOrEqualTo(10));

      // Check all have coordinates
      for (final a in attractions) {
        expect(a.latitude, isNotNull, reason: '${a.name} missing latitude');
        expect(a.longitude, isNotNull, reason: '${a.name} missing longitude');
        expect(a.currency, isNotNull, reason: '${a.name} missing currency');
      }
    });
  });

  group('Global Migration - HomeScreen & ExploreScreen global UI', () {
    testWidgets('HomeScreen displays Worldwide scope instead of Hyderabad', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(DummyData.attractions);

      await tester.pumpWidget(buildTestable(const HomeScreen()));
      await tester.pumpAndSettle();

      // Check that Worldwide indicator is rendered
      expect(find.text(AppConstants.globalScope), findsOneWidget);
      expect(find.text('Top Attractions Worldwide'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
    });

    testWidgets('ExploreScreen search matches across name, city, country, category', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(DummyData.attractions);

      await tester.pumpWidget(buildTestable(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Search by Country: 'France' -> matches Eiffel Tower & Louvre
      await tester.enterText(find.byType(TextField), 'France');
      await tester.pumpAndSettle();
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsOneWidget);
      expect(find.text('Colosseum'), findsNothing);

      // Search by City: 'Tokyo' -> matches Tokyo Skytree & Tsukiji Outer Market
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pumpAndSettle();
      expect(find.text('Tokyo Skytree'), findsOneWidget);
      expect(find.text('Tsukiji Outer Market'), findsOneWidget);
      expect(find.text('Eiffel Tower'), findsNothing);
    });
  });

  group('Global Migration - MapScreen global bounds and fallback', () {
    test('worldCenter is neutral coordinates (20.0, 0.0)', () {
      expect(MapScreen.worldCenter.latitude, 20.0);
      expect(MapScreen.worldCenter.longitude, 0.0);
    });

    testWidgets('MapScreen renders global bounds without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(MapScreen(attractions: DummyData.attractions)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers.length, DummyData.attractions.length);
    });
  });

  group('Global Migration - SeedService test', () {
    test('SeedService instance is accessible', () {
      expect(SeedService.instance, isNotNull);
    });
  });
}
