import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/models/trip.dart';
import 'package:tourmate/screens/main/trip_details_screen.dart';
import 'package:tourmate/screens/main/trips_screen.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/trip_service.dart';
import 'package:tourmate/widgets/add_to_trip_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final testDateStart = DateTime(2026, 10, 10);
  final testDateEnd = DateTime(2026, 10, 14);

  final sampleTrip = Trip(
    id: 'trip_101',
    userId: 'user_darsh_1',
    name: 'Paris Adventure',
    destination: 'Paris, France',
    startDate: testDateStart,
    endDate: testDateEnd,
    attractionIds: const ['eiffel_tower', 'louvre_museum'],
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  final sampleAttraction = Attraction(
    id: 'eiffel_tower',
    name: 'Eiffel Tower',
    category: 'Monument',
    city: 'Paris',
    country: 'France',
    location: 'Champ de Mars, 5 Av. Anatole France',
    description: 'Iconic iron lattice tower on the Champ de Mars.',
    imageUrl: 'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f',
    rating: 4.8,
    reviewCount: 12500,
    openingHours: '09:00 - 23:45',
    distance: '2.5 km',
    entryFee: '€26.0',
  );

  setUp(() {
    TripService.resetForTest();
    TripService.testTrips = <String, List<Trip>>{
      'user_darsh_1': <Trip>[sampleTrip],
    };
    TripService.testCurrentUserId = 'user_darsh_1';
    AttractionService.testGetAttraction = (id) async {
      if (id == 'eiffel_tower') return sampleAttraction;
      return null;
    };
  });

  tearDown(() {
    TripService.resetForTest();
    AttractionService.testGetAttraction = null;
  });

  group('Trip Model Tests', () {
    test('1. Trip serialization (toMap and toRawMap)', () {
      final map = sampleTrip.toMap();
      expect(map['userId'], 'user_darsh_1');
      expect(map['name'], 'Paris Adventure');
      expect(map['destination'], 'Paris, France');
      expect(map['startDate'], isA<Timestamp>());
      expect(map['endDate'], isA<Timestamp>());
      expect(map['attractionIds'], ['eiffel_tower', 'louvre_museum']);

      final rawMap = sampleTrip.toRawMap();
      expect(rawMap['id'], 'trip_101');
      expect(rawMap['userId'], 'user_darsh_1');
      expect(rawMap['startDate'], testDateStart.toIso8601String());
      expect(rawMap['endDate'], testDateEnd.toIso8601String());
    });

    test('2. Trip parsing from Firestore and Map', () {
      final firestoreData = <String, dynamic>{
        'userId': 'user_darsh_1',
        'name': 'Tokyo Explorer',
        'destination': 'Tokyo, Japan',
        'startDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'endDate': Timestamp.fromDate(DateTime(2026, 11, 7)),
        'attractionIds': ['shibuya_crossing', 'senso_ji'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
      };

      final trip = Trip.fromFirestore('trip_tokyo', firestoreData);
      expect(trip.id, 'trip_tokyo');
      expect(trip.userId, 'user_darsh_1');
      expect(trip.name, 'Tokyo Explorer');
      expect(trip.destination, 'Tokyo, Japan');
      expect(trip.attractionCount, 2);
      expect(trip.attractionIds, ['shibuya_crossing', 'senso_ji']);
      expect(trip.startDate.year, 2026);
      expect(trip.startDate.month, 11);
    });

    test('3. Duration calculation (durationInDays)', () {
      expect(sampleTrip.durationInDays, 5); // 10, 11, 12, 13, 14 = 5 days

      final singleDayTrip = sampleTrip.copyWith(
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 10),
      );
      expect(singleDayTrip.durationInDays, 1);
    });

    test('4. Date range formatting (formattedDateRange)', () {
      expect(sampleTrip.formattedDateRange, '10 – 14 Oct 2026');

      final crossMonthTrip = sampleTrip.copyWith(
        startDate: DateTime(2026, 10, 28),
        endDate: DateTime(2026, 11, 3),
      );
      expect(crossMonthTrip.formattedDateRange, '28 Oct – 3 Nov 2026');

      final singleDayTrip = sampleTrip.copyWith(
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 10),
      );
      expect(singleDayTrip.formattedDateRange, '10 Oct 2026');
    });
  });

  group('Trip Validation Tests', () {
    test('5. Empty trip name rejection', () async {
      expect(
        () => TripService.instance.createTrip(
          name: '   ',
          destination: 'Rome, Italy',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 5),
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('name cannot be empty'),
        )),
      );
    });

    test('6. Empty destination rejection', () async {
      expect(
        () => TripService.instance.createTrip(
          name: 'Rome Holiday',
          destination: '',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 5),
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('Destination cannot be empty'),
        )),
      );
    });

    test('7. Name >100 characters rejection', () async {
      final longName = 'A' * 101;
      expect(
        () => TripService.instance.createTrip(
          name: longName,
          destination: 'Rome, Italy',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 5),
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('cannot exceed 100 characters'),
        )),
      );
    });

    test('8. Destination >100 characters rejection', () async {
      final longDest = 'B' * 101;
      expect(
        () => TripService.instance.createTrip(
          name: 'Rome Trip',
          destination: longDest,
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 5),
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('cannot exceed 100 characters'),
        )),
      );
    });

    test('9. End date before start date rejection', () async {
      expect(
        () => TripService.instance.createTrip(
          name: 'Rome Trip',
          destination: 'Rome, Italy',
          startDate: DateTime(2026, 12, 10),
          endDate: DateTime(2026, 12, 5),
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('End date cannot be before start date'),
        )),
      );
    });
  });

  group('Trip CRUD Tests', () {
    test('10. Create trip persists trip with unique ID', () async {
      final newTrip = await TripService.instance.createTrip(
        name: 'Rome Holiday',
        destination: 'Rome, Italy',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
      );

      expect(newTrip.name, 'Rome Holiday');
      expect(newTrip.destination, 'Rome, Italy');
      expect(newTrip.userId, 'user_darsh_1');
      expect(newTrip.attractionCount, 0);

      final fetched = await TripService.instance.getTrip(newTrip.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Rome Holiday');
    });

    test('11. Get trip retrieves existing trip and null for unknown ID', () async {
      final fetched = await TripService.instance.getTrip('trip_101');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Paris Adventure');

      final notFound = await TripService.instance.getTrip('non_existent_id');
      expect(notFound, isNull);
    });

    test('12. Update trip modifies details and timestamps', () async {
      await TripService.instance.updateTrip(
        tripId: 'trip_101',
        name: 'Grand Paris Tour',
        destination: 'Paris & Versailles, France',
        startDate: DateTime(2026, 10, 12),
        endDate: DateTime(2026, 10, 18),
      );

      final trip = await TripService.instance.getTrip('trip_101');
      expect(trip!.name, 'Grand Paris Tour');
      expect(trip.destination, 'Paris & Versailles, France');
      expect(trip.startDate.day, 12);
      expect(trip.endDate.day, 18);
    });

    test('13. Delete trip removes document from user trips', () async {
      await TripService.instance.deleteTrip('trip_101');
      final trip = await TripService.instance.getTrip('trip_101');
      expect(trip, isNull);
    });
  });

  group('Itinerary Management Tests', () {
    test('14. Add attraction to trip appends attraction ID', () async {
      await TripService.instance.addAttractionToTrip(
        tripId: 'trip_101',
        attractionId: 'arc_de_triomphe',
      );

      final trip = await TripService.instance.getTrip('trip_101');
      expect(trip!.attractionIds, [
        'eiffel_tower',
        'louvre_museum',
        'arc_de_triomphe',
      ]);
      expect(trip.attractionCount, 3);
    });

    test('15. Prevent duplicate attraction in same trip', () async {
      expect(
        () => TripService.instance.addAttractionToTrip(
          tripId: 'trip_101',
          attractionId: 'eiffel_tower',
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          'Already added to this trip.',
        )),
      );
    });

    test('16. Remove attraction removes specified ID while keeping others', () async {
      await TripService.instance.removeAttractionFromTrip(
        tripId: 'trip_101',
        attractionId: 'louvre_museum',
      );

      final trip = await TripService.instance.getTrip('trip_101');
      expect(trip!.attractionIds, ['eiffel_tower']);
      expect(trip.attractionCount, 1);
    });

    test('17. Reorder attractions updates attraction order', () async {
      await TripService.instance.reorderAttractions(
        tripId: 'trip_101',
        newOrder: ['louvre_museum', 'eiffel_tower'],
      );

      final trip = await TripService.instance.getTrip('trip_101');
      expect(trip!.attractionIds, ['louvre_museum', 'eiffel_tower']);
    });
  });

  group('Authentication & User Scoping Tests', () {
    test('18. Unauthenticated trip access throws TripServiceException', () async {
      TripService.testCurrentUserId = null;

      expect(
        () => TripService.instance.createTrip(
          name: 'Unauthorized Trip',
          destination: 'Anywhere',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 2)),
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('must be signed in'),
        )),
      );
    });

    test('19. Trip ownership and user isolation', () async {
      TripService.testTrips!['user_other_2'] = [
        sampleTrip.copyWith(id: 'trip_other', userId: 'user_other_2', name: 'Other User Trip'),
      ];

      // Current user is user_darsh_1
      final darshTrips = await TripService.instance.streamTrips().first;
      expect(darshTrips.length, 1);
      expect(darshTrips.first.name, 'Paris Adventure');

      // Switch to user_other_2
      TripService.testCurrentUserId = 'user_other_2';
      final otherTrips = await TripService.instance.streamTrips().first;
      expect(otherTrips.length, 1);
      expect(otherTrips.first.name, 'Other User Trip');
    });
  });

  group('Trips UI Widget Tests', () {
    testWidgets('20. Trips empty state shows placeholder and create button', (
      tester,
    ) async {
      TripService.testTrips!['user_darsh_1'] = <Trip>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TripsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Trips'), findsOneWidget);
      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Create Your First Trip'), findsOneWidget);
    });

    testWidgets('21. Trip creation UI / Trips list renders trip cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TripsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Trips'), findsOneWidget);
      expect(find.text('Paris Adventure'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);
      expect(find.text('2 attractions'), findsOneWidget);
      expect(find.text('New Trip'), findsOneWidget);
    });

    testWidgets('22. Trip details / itinerary UI displays attractions and actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TripDetailsScreen(
            tripId: sampleTrip.id,
            initialTrip: sampleTrip,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paris Adventure'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);
      expect(find.text('Your Attractions'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsWidgets);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);
    });

    testWidgets('23. AddToTripSheet displays user trips and already added status', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AddToTripSheet(attraction: sampleAttraction),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add to Trip'), findsOneWidget);
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Paris Adventure'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
    });
  });
}
