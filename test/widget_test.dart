import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/main.dart';
import 'package:tourmate/models/trip.dart';
import 'package:tourmate/screens/main/main_shell.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    AttractionService.devFallbackEnabled = true;

    // Keep the MainShell navigation test deterministic and completely offline.
    // The Trips tab should render its empty state without depending on Firebase
    // initialization or a previously authenticated app session.
    TripService.resetForTest();
    TripService.testCurrentUserId = 'widget-test-user';
    TripService.testTrips = <String, List<Trip>>{
      'widget-test-user': <Trip>[],
    };
  });

  tearDown(() {
    AttractionService.devFallbackEnabled = false;
    AttractionService.testStream = null;
    TripService.resetForTest();
    SavedPlacesStore.instance.resetForTest();
  });

  testWidgets('navigates Splash → Onboarding → Login screen', (
    tester,
  ) async {
    await tester.pumpWidget(const TourMateApp());
    expect(find.text('TourMate'), findsOneWidget);
    expect(find.text('Discover. Explore. Experience.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Explore Amazing Places'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Navigate With Ease'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Travel Your Way'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
  });

  testWidgets('navigates MainShell tabs (Home, Explore, Trips, Saved, Profile)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MainShell(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Where do you want to explore?'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsWidgets);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('No trips yet'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('My Saved Places'), findsOneWidget);

    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('TourMate'), findsWidgets);
  });
}
