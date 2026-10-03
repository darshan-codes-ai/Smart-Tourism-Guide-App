import 'dart:async';

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
      id: '1',
      name: 'Charminar',
      category: 'Historical',
      description: 'Grand mosque',
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
      id: '2',
      name: 'Golconda Fort',
      category: 'Historical',
      description: 'Hilltop fort',
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
      id: '3',
      name: 'Hussain Sagar',
      category: 'Nature',
      description: 'Heart-shaped lake',
      imageUrl: '',
      rating: 4.5,
      distance: '5.4 km',
      location: 'Hyderabad',
      openingHours: 'Open all day',
      entryFee: 'Free',
      latitude: 17.4239,
      longitude: 78.4738,
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

  group('ExploreScreen "All" category filter requirements', () {
    testWidgets('1 & 2: "All" is the FIRST chip and list has all expected categories in order', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      final chipWidgets = tester
          .widgetList<CategoryChip>(find.byType(CategoryChip))
          .toList();

      expect(chipWidgets.isNotEmpty, isTrue);
      expect(chipWidgets.first.label, equals('All'));

      // Expected category sequence: All | Historical | Nature | Religious | Adventure | Food | Shopping
      final labels = chipWidgets.map((c) => c.label).toList();
      expect(
        labels,
        equals([
          'All',
          'Historical',
          'Nature',
          'Religious',
          'Adventure',
          'Food',
          'Shopping',
        ]),
      );
    });

    testWidgets('3 & 4: On opening Explore, "All" is selected by default and all attractions are shown', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      final allChipFinder = find.widgetWithText(CategoryChip, 'All');
      final allChip = tester.widget<CategoryChip>(allChipFinder);
      expect(allChip.selected, isTrue);

      // All 3 sample attractions are shown
      expect(find.byType(AttractionCard), findsNWidgets(3));
      expect(find.text('Charminar'), findsOneWidget);
      expect(find.text('Golconda Fort'), findsOneWidget);
      expect(find.text('Hussain Sagar'), findsOneWidget);

      // Switch to Map: MapScreen receives all 3 attractions with coordinates
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers.length, equals(3));
    });

    testWidgets('5, 6, 7 & 8: Category selection filters attractions, tapping All resets, and unselecting resets to All', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // Select 'Historical'
      await tester.tap(find.widgetWithText(CategoryChip, 'Historical'));
      await tester.pumpAndSettle();

      // 'Historical' is selected, 'All' is unselected
      expect(
        tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'Historical')).selected,
        isTrue,
      );
      expect(
        tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'All')).selected,
        isFalse,
      );

      // Only Historical attractions shown
      expect(find.text('Charminar'), findsOneWidget);
      expect(find.text('Golconda Fort'), findsOneWidget);
      expect(find.text('Hussain Sagar'), findsNothing);

      // Tap 'All' chip
      await tester.tap(find.widgetWithText(CategoryChip, 'All'));
      await tester.pumpAndSettle();

      // 'All' is selected again and all attractions return
      expect(
        tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'All')).selected,
        isTrue,
      );
      expect(find.text('Hussain Sagar'), findsOneWidget);

      // Tap 'Nature'
      await tester.tap(find.widgetWithText(CategoryChip, 'Nature'));
      await tester.pumpAndSettle();
      expect(find.text('Hussain Sagar'), findsOneWidget);
      expect(find.text('Charminar'), findsNothing);

      // Tap 'Nature' again (toggle off) -> reverts to 'All'
      await tester.tap(find.widgetWithText(CategoryChip, 'Nature'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'All')).selected,
        isTrue,
      );
      expect(find.text('Charminar'), findsOneWidget);
      expect(find.text('Hussain Sagar'), findsOneWidget);
    });

    testWidgets('9: Search filtering works together with the category filter', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      // All + search "charminar" -> only Charminar
      await tester.enterText(find.byType(TextField), 'charminar');
      await tester.pumpAndSettle();

      expect(find.text('Charminar'), findsOneWidget);
      expect(find.text('Golconda Fort'), findsNothing);
      expect(find.text('Hussain Sagar'), findsNothing);

      // Switch to Nature with search "charminar" -> 0 matches
      await tester.tap(find.widgetWithText(CategoryChip, 'Nature'));
      await tester.pumpAndSettle();

      expect(find.text('No attractions match your filters yet.'), findsOneWidget);

      // Clear search -> Hussain Sagar appears
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Hussain Sagar'), findsOneWidget);
      expect(find.text('Charminar'), findsNothing);
    });
  });
}
