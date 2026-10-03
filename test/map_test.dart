import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/screens/main/explore_screen.dart';
import 'package:tourmate/screens/main/map_screen.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/widgets/attraction_card.dart';
import 'package:tourmate/widgets/category_chip.dart';

void main() {
  const sampleAttractions = [
    Attraction(
      id: 'm1',
      name: 'Charminar',
      category: 'Historical',
      description: 'Grand mosque in Hyderabad.',
      imageUrl: '',
      rating: 4.6,
      distance: '1.2 km',
      location: 'Hyderabad',
      openingHours: '9:30 AM - 5:30 PM',
      entryFee: '₹25',
      latitude: 17.3616,
      longitude: 78.4747,
    ),
    Attraction(
      id: 'm2',
      name: 'Golconda Fort',
      category: 'Historical',
      description: 'Hilltop fort with acoustics.',
      imageUrl: '',
      rating: 4.7,
      distance: '8.2 km',
      location: 'Hyderabad',
      openingHours: '9:00 AM - 5:30 PM',
      entryFee: '₹25',
      latitude: 17.3833,
      longitude: 78.4011,
    ),
    Attraction(
      id: 'm3_no_coords',
      name: 'Hidden Gem',
      category: 'Secret',
      description: 'No coordinates available yet.',
      imageUrl: '',
      rating: 4.0,
      distance: '5.0 km',
      location: 'Unknown',
      openingHours: 'Not available',
      entryFee: 'Free',
      latitude: null,
      longitude: null,
    ),
  ];

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  tearDown(() {
    AttractionService.testStream = null;
    SavedPlacesStore.instance.resetForTest();
  });

  group('ExploreScreen List/Map toggle tests', () {
    testWidgets('Explore defaults to LIST mode and displays attraction cards', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // List mode should be default
      expect(find.byType(AttractionCard), findsWidgets);
      expect(find.text('Charminar'), findsOneWidget);
      expect(find.text('Golconda Fort'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('Switching to MAP mode displays FlutterMap with OpenStreetMap attribution', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Tap Map toggle
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      // Map view should be active
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      // Switch back to List toggle
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byType(AttractionCard), findsWidgets);
    });

    testWidgets('Explore category filter defaults to All and shows all attractions on Map', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(DummyData.attractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Check 'All' CategoryChip is present and selected
      final allChipFinder = find.widgetWithText(CategoryChip, 'All');
      expect(allChipFinder, findsOneWidget);
      final allChip = tester.widget<CategoryChip>(allChipFinder);
      expect(allChip.selected, isTrue);

      // Historical chip should NOT be selected
      final historicalChip = tester.widget<CategoryChip>(
        find.widgetWithText(CategoryChip, 'Historical'),
      );
      expect(historicalChip.selected, isFalse);

      // Tap Map toggle
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      // FlutterMap should be active with all markers
      final markerLayerFinder = find.byType(MarkerLayer);
      expect(markerLayerFinder, findsOneWidget);
      final markerLayer = tester.widget<MarkerLayer>(markerLayerFinder);
      final expectedCount = DummyData.attractions
          .where((a) => a.latitude != null && a.longitude != null)
          .length;
      expect(markerLayer.markers.length, expectedCount);
    });

    testWidgets('Filtering by category updates Map markers and tapping All restores all markers', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(DummyData.attractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Select 'Historical'
      await tester.tap(find.widgetWithText(CategoryChip, 'Historical'));
      await tester.pumpAndSettle();

      // Tap Map toggle
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      final historicalCount = DummyData.attractions
          .where((a) =>
              a.category == 'Historical' &&
              a.latitude != null &&
              a.longitude != null)
          .length;
      var markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers.length, historicalCount);

      // Tap 'All' chip
      await tester.tap(find.widgetWithText(CategoryChip, 'All'));
      await tester.pumpAndSettle();

      // All markers restored
      markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      final totalCount = DummyData.attractions
          .where((a) => a.latitude != null && a.longitude != null)
          .length;
      expect(markerLayer.markers.length, totalCount);
    });
  });

  group('MapScreen marker and interaction tests', () {
    testWidgets('attractions with valid coordinates become markers, null coordinates are ignored', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const MapScreen(attractions: sampleAttractions)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);

      // Verify MarkerLayer exists and has 2 markers (for m1 and m2, ignoring m3_no_coords)
      final markerLayerFinder = find.byType(MarkerLayer);
      expect(markerLayerFinder, findsOneWidget);
      final markerLayer = tester.widget<MarkerLayer>(markerLayerFinder);
      expect(markerLayer.markers.length, 2);
    });

    testWidgets('empty attraction list does not crash MapScreen and uses Hyderabad fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const MapScreen(attractions: <Attraction>[])),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers, isEmpty);
    });

    testWidgets('tapping a marker displays preview card with details and favorite toggle', (
      tester,
    ) async {
      SavedPlacesStore.instance.resetForTest();

      await tester.pumpWidget(
        buildTestableWidget(const MapScreen(attractions: sampleAttractions)),
      );
      await tester.pumpAndSettle();

      // Tap on the first marker pin icon
      final markerPins = find.byIcon(Icons.location_on_rounded);
      expect(markerPins, findsNWidgets(2));

      await tester.tap(markerPins.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Preview card should be displayed with attraction name and rating
      expect(find.text('Charminar'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);

      // Toggle favorite on preview card
      expect(SavedPlacesStore.instance.isSaved('m1'), isFalse);
      final favoriteBtn = find.byTooltip('Save place');
      expect(favoriteBtn, findsOneWidget);

      await tester.tap(favoriteBtn);
      await tester.pumpAndSettle();

      expect(SavedPlacesStore.instance.isSaved('m1'), isTrue);

      // Close preview card
      final closeBtn = find.byTooltip('Close preview');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('4.6'), findsNothing);
    });

    testWidgets('tapping preview card opens attraction detail bottom sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const MapScreen(attractions: sampleAttractions)),
      );
      await tester.pumpAndSettle();

      final markerPins = find.byIcon(Icons.location_on_rounded);
      await tester.tap(markerPins.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tap anywhere on the preview card
      await tester.tap(find.text('Charminar'));
      await tester.pumpAndSettle();

      // showAttractionDetails modal bottom sheet opens
      expect(find.text('Opening hours: '), findsOneWidget);
      expect(find.text('9:30 AM - 5:30 PM'), findsOneWidget);
      expect(find.text('Entry fee: '), findsOneWidget);
      expect(find.text('₹25'), findsWidgets);
    });
  });
}
