import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/screens/main/explore_screen.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/widgets/attraction_card.dart';
import 'package:tourmate/widgets/category_chip.dart';

void main() {
  const sampleAttractions = [
    Attraction(
      id: 'eiffel',
      name: 'Eiffel Tower',
      category: 'Historical',
      city: 'Paris',
      country: 'France',
      countryCode: 'FR',
      description: 'Iconic wrought-iron lattice tower.',
      imageUrl: '',
      rating: 4.7,
      distance: '2.5 km',
      location: 'Paris, France',
      openingHours: '9:00 AM - 11:45 PM',
      entryFee: '€29',
      latitude: 48.8584,
      longitude: 2.2945,
    ),
    Attraction(
      id: 'louvre',
      name: 'Louvre Museum',
      category: 'Historical',
      city: 'Paris',
      country: 'France',
      countryCode: 'FR',
      description: 'Famous art museum with Mona Lisa.',
      imageUrl: '',
      rating: 4.8,
      distance: '3.1 km',
      location: 'Paris, France',
      openingHours: '9:00 AM - 6:00 PM',
      entryFee: '€22',
      latitude: 48.8606,
      longitude: 2.3376,
    ),
    Attraction(
      id: 'skytree',
      name: 'Tokyo Skytree',
      category: 'Historical',
      city: 'Tokyo',
      country: 'Japan',
      countryCode: 'JP',
      description: 'Futuristic tower with panoramic city views.',
      imageUrl: '',
      rating: 4.6,
      distance: '5.0 km',
      location: 'Tokyo, Japan',
      openingHours: '10:00 AM - 9:00 PM',
      entryFee: '¥3,100',
      latitude: 35.7100,
      longitude: 139.8107,
    ),
    Attraction(
      id: 'fushimi',
      name: 'Fushimi Inari Taisha',
      category: 'Religious',
      city: 'Kyoto',
      country: 'Japan',
      countryCode: 'JP',
      description: 'Shinto shrine known for thousands of red torii gates.',
      imageUrl: '',
      rating: 4.8,
      distance: '12.0 km',
      location: 'Kyoto, Japan',
      openingHours: 'Open 24 hours',
      entryFee: 'Free',
      latitude: 34.9671,
      longitude: 135.7727,
    ),
    Attraction(
      id: 'central_park',
      name: 'Central Park',
      category: 'Nature',
      city: 'New York',
      country: 'United States',
      countryCode: 'US',
      description: 'Iconic urban park in Manhattan.',
      imageUrl: '',
      rating: 4.8,
      distance: '1.5 km',
      location: 'New York, USA',
      openingHours: '6:00 AM - 1:00 AM',
      entryFee: 'Free',
      latitude: 40.7850,
      longitude: -73.9682,
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

  group('ExploreScreen Search Interface Tests', () {
    testWidgets('Search button in header activates search and focuses field', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Find Search icon button in header
      final headerSearchBtn = find.byTooltip('Search');
      expect(headerSearchBtn, findsWidgets);

      // Tap search icon in header
      await tester.tap(headerSearchBtn.first);
      await tester.pumpAndSettle();

      // Verify TextField is focused
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('Prefix search icon in TextField activates search', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Find prefix icon button inside TextField
      final prefixSearchBtn = find.descendant(
        of: find.byType(TextField),
        matching: find.byIcon(Icons.search_rounded),
      );
      expect(prefixSearchBtn, findsOneWidget);

      await tester.tap(prefixSearchBtn);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('Search works by attraction name (e.g. "Eiffel")', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Eiffel');
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsNothing);
      expect(find.text('Tokyo Skytree'), findsNothing);
    });

    testWidgets('Search works by city (e.g. "Paris")', (tester) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsOneWidget);
      expect(find.text('Tokyo Skytree'), findsNothing);
      expect(find.text('Central Park'), findsNothing);
    });

    testWidgets('Search works by country (e.g. "France" and "Japan")', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Search "France"
      await tester.enterText(find.byType(TextField), 'France');
      await tester.pumpAndSettle();
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsOneWidget);
      expect(find.text('Tokyo Skytree'), findsNothing);

      // Search "Japan"
      await tester.enterText(find.byType(TextField), 'Japan');
      await tester.pumpAndSettle();
      expect(find.text('Tokyo Skytree'), findsOneWidget);
      expect(find.text('Fushimi Inari Taisha'), findsOneWidget);
      expect(find.text('Eiffel Tower'), findsNothing);
    });

    testWidgets('Search works by category (e.g. "Nature" or "Historical")', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Nature');
      await tester.pumpAndSettle();

      expect(find.text('Central Park'), findsOneWidget);
      expect(find.text('Eiffel Tower'), findsNothing);
    });

    testWidgets('Search is case-insensitive and supports partial matching', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Lowercase partial
      await tester.enterText(find.byType(TextField), 'eiff');
      await tester.pumpAndSettle();
      expect(find.text('Eiffel Tower'), findsOneWidget);

      // Uppercase partial
      await tester.enterText(find.byType(TextField), 'TOKY');
      await tester.pumpAndSettle();
      expect(find.text('Tokyo Skytree'), findsOneWidget);
    });

    testWidgets('Clear button clears search query and restores full list', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Type search
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pumpAndSettle();

      expect(find.byType(AttractionCard), findsNWidgets(2));

      // Clear search via suffixIcon
      final clearBtn = find.byTooltip('Clear search');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // All 5 sample attractions returned
      expect(find.byType(AttractionCard), findsNWidgets(5));
      expect(find.text('Tokyo Skytree'), findsOneWidget);
      expect(find.text('Central Park'), findsOneWidget);
    });

    testWidgets('Search and category filter work together in combination', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Select 'Historical' category
      await tester.tap(find.widgetWithText(CategoryChip, 'Historical'));
      await tester.pumpAndSettle();

      // Search 'Paris' -> Eiffel Tower & Louvre (both Historical + Paris)
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsOneWidget);
      expect(find.text('Tokyo Skytree'), findsNothing);

      // Search 'Tokyo' -> Tokyo Skytree (Historical + Tokyo)
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pumpAndSettle();

      expect(find.text('Tokyo Skytree'), findsOneWidget);
      expect(find.text('Fushimi Inari Taisha'), findsNothing); // Fushimi is Religious

      // Switch category to Religious while search is 'Tokyo' -> 0 matches
      await tester.tap(find.widgetWithText(CategoryChip, 'Religious'));
      await tester.pumpAndSettle();

      expect(
        find.text('No attractions match your filters yet.'),
        findsOneWidget,
      );

      // Clear search -> Fushimi Inari Taisha appears (Religious in Kyoto)
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Fushimi Inari Taisha'), findsOneWidget);
      expect(find.text('Tokyo Skytree'), findsNothing);
    });

    testWidgets('Search updates Map markers in real time', (tester) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Enter search 'Paris'
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pumpAndSettle();

      // Switch to Map
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      // MarkerLayer should have exactly 2 markers (Eiffel & Louvre)
      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers.length, equals(2));

      // Switch back to List, clear search, and check Map again
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      final fullMarkerLayer = tester.widget<MarkerLayer>(
        find.byType(MarkerLayer),
      );
      expect(fullMarkerLayer.markers.length, equals(5));
    });
  });
}
