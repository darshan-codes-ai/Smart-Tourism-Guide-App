import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/screens/main/explore_screen.dart';
import 'package:tourmate/screens/main/home_screen.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/widgets/category_chip.dart';

void main() {
  const sampleAttractions = [
    Attraction(
      id: 'h1',
      name: 'Charminar',
      category: 'Historical',
      description: 'Iconic mosque',
      imageUrl: '',
      rating: 4.6,
      distance: '1.2 km',
      location: 'Old City, Hyderabad',
      openingHours: '9:30 AM - 5:30 PM',
      entryFee: '₹25',
    ),
    Attraction(
      id: 'h2',
      name: 'Golconda Fort',
      category: 'Historical',
      description: 'Hilltop fort',
      imageUrl: '',
      rating: 4.8,
      distance: '8.2 km',
      location: 'Hyderabad',
      openingHours: '9:00 AM - 5:30 PM',
      entryFee: '₹25',
    ),
    Attraction(
      id: 'h3',
      name: 'Hussain Sagar',
      category: 'Nature',
      description: 'Heart-shaped lake',
      imageUrl: '',
      rating: 4.3,
      distance: '15.0 km',
      location: 'Hyderabad',
      openingHours: 'Open all day',
      entryFee: 'Free',
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

  group('HomeScreen Firestore integration tests', () {
    testWidgets('shows loading state while waiting for Firestore', (
      tester,
    ) async {
      final controller = StreamController<List<Attraction>>();
      AttractionService.testStream = controller.stream;

      await tester.pumpWidget(buildTestableWidget(const HomeScreen()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Where do you want to explore?'), findsOneWidget);

      await controller.close();
    });

    testWidgets('shows empty state when Firestore has no attractions', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(const <Attraction>[]);

      await tester.pumpWidget(buildTestableWidget(const HomeScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text('No attractions available yet in Firestore.'),
        findsOneWidget,
      );
      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets(
      'shows error state and retry button when Firestore stream fails',
      (tester) async {
        AttractionService.testStream = Stream.error(
          Exception('Firestore network error'),
        );

        await tester.pumpWidget(buildTestableWidget(const HomeScreen()));
        await tester.pumpAndSettle();

        expect(
          find.text('Could not load attractions from Firestore.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets('shows attractions when Firestore returns data', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(sampleAttractions);

      await tester.pumpWidget(buildTestableWidget(const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Charminar'), findsWidgets);
      expect(find.text('Golconda Fort'), findsWidgets);
    });
  });

  group('ExploreScreen Firestore integration tests', () {
    testWidgets('shows loading state while waiting for Firestore', (
      tester,
    ) async {
      final controller = StreamController<List<Attraction>>();
      AttractionService.testStream = controller.stream;

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);

      await controller.close();
    });

    testWidgets('shows empty state when Firestore has no attractions', (
      tester,
    ) async {
      AttractionService.testStream = Stream.value(const <Attraction>[]);

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No attractions available yet'), findsOneWidget);
      expect(
        find.text('No attraction documents found in Firestore.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Refresh'), findsOneWidget);
    });

    testWidgets('shows error state when Firestore fails', (tester) async {
      AttractionService.testStream = Stream.error(
        Exception('Firestore failure'),
      );

      await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load attractions'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });

    testWidgets(
      'renders Firestore attractions and performs search & category filter',
      (tester) async {
        AttractionService.testStream = Stream.value(sampleAttractions);

        await tester.pumpWidget(buildTestableWidget(const ExploreScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Charminar'), findsOneWidget);
        expect(find.text('Golconda Fort'), findsOneWidget);
        expect(find.text('Hussain Sagar'), findsOneWidget);

        // Filter by category "Nature" using CategoryChip
        await tester.tap(find.widgetWithText(CategoryChip, 'Nature'));
        await tester.pumpAndSettle();

        expect(find.text('Hussain Sagar'), findsOneWidget);
        expect(find.text('Charminar'), findsNothing);
        expect(find.text('Golconda Fort'), findsNothing);

        // Search for "Hussain"
        await tester.enterText(find.byType(TextField), 'Hussain');
        await tester.pumpAndSettle();

        expect(find.text('Hussain Sagar'), findsOneWidget);

        // Search non-existent
        await tester.enterText(find.byType(TextField), 'xyz123');
        await tester.pumpAndSettle();

        expect(
          find.text('No attractions match your filters yet.'),
          findsOneWidget,
        );
      },
    );
  });
}
