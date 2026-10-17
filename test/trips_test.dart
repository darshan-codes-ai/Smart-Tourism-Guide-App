import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/models/travel_preference.dart';
import 'package:tourmate/models/trip.dart';
import 'package:tourmate/screens/main/trip_details_screen.dart';
import 'package:tourmate/screens/main/trips_screen.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/itinerary_service.dart';
import 'package:tourmate/services/trip_service.dart';
import 'package:tourmate/widgets/add_to_trip_sheet.dart';
import 'package:tourmate/widgets/trip_form_sheet.dart';

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

  final sampleAttraction2 = Attraction(
    id: 'louvre_museum',
    name: 'Louvre Museum',
    category: 'Museum',
    city: 'Paris',
    country: 'France',
    location: 'Rue de Rivoli',
    description: 'World largest art museum and historic monument in Paris.',
    imageUrl: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a',
    rating: 4.7,
    reviewCount: 9800,
    openingHours: '09:00 - 18:00',
    distance: '3.1 km',
    entryFee: '€17.0',
  );

  final sampleAttraction3 = Attraction(
    id: 'notre_dame',
    name: 'Notre-Dame Cathedral',
    category: 'Church',
    city: 'Paris',
    country: 'France',
    location: 'Île de la Cité',
    description: 'Medieval Catholic cathedral on the Île de la Cité.',
    imageUrl: 'https://images.unsplash.com/photo-1543349689-9a4d426bee8e',
    rating: 4.6,
    reviewCount: 8200,
    openingHours: '08:00 - 18:45',
    distance: '4.0 km',
    entryFee: 'Free',
  );

  final sampleAttraction4 = Attraction(
    id: 'arc_de_triomphe',
    name: 'Arc de Triomphe',
    category: 'Monument',
    city: 'Paris',
    country: 'France',
    location: 'Place Charles de Gaulle',
    description: 'Iconic triumphal arch honoring French military victories.',
    imageUrl: 'https://images.unsplash.com/photo-1509356843151-3e7d96241e11',
    rating: 4.6,
    reviewCount: 7100,
    openingHours: '10:00 - 22:30',
    distance: '3.8 km',
    entryFee: '€13.0',
  );

  final sampleAttraction5 = Attraction(
    id: 'tokyo_tower',
    name: 'Tokyo Tower',
    category: 'Tower',
    city: 'Tokyo',
    country: 'Japan',
    location: 'Minato City, Tokyo',
    description: 'Communications and observation tower in the Shiba-koen district.',
    imageUrl: 'https://images.unsplash.com/photo-1536098561742-ca998e48cbcc',
    rating: 4.5,
    reviewCount: 6500,
    openingHours: '09:00 - 23:00',
    distance: '5.2 km',
    entryFee: '¥1200',
  );

  final allTestAttractions = <String, Attraction>{
    'eiffel_tower': sampleAttraction,
    'louvre_museum': sampleAttraction2,
    'notre_dame': sampleAttraction3,
    'arc_de_triomphe': sampleAttraction4,
    'tokyo_tower': sampleAttraction5,
  };

  setUp(() {
    TripService.resetForTest();
    TripService.testTrips = <String, List<Trip>>{
      'user_darsh_1': <Trip>[sampleTrip],
    };
    TripService.testCurrentUserId = 'user_darsh_1';
    AttractionService.testAttractions = Map<String, Attraction>.from(allTestAttractions);
    AttractionService.testGetAttraction = (id) async => allTestAttractions[id];
  });

  tearDown(() {
    TripService.resetForTest();
    AttractionService.testGetAttraction = null;
    AttractionService.testAttractions = null;
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

  group('Smart Trip Model & Validation Tests', () {
    test('24. Trip serialization with budget, travelerCount, and dayItinerary (toMap and toRawMap)', () {
      final trip = sampleTrip.copyWith(
        budget: 1500.0,
        travelerCount: 3,
        dayItinerary: const {
          1: ['eiffel_tower'],
          2: ['louvre_museum'],
        },
      );

      expect(trip.budget, 1500.0);
      expect(trip.travelerCount, 3);
      expect(trip.dayItinerary[1], ['eiffel_tower']);
      expect(trip.dayItinerary[2], ['louvre_museum']);
      expect(trip.formattedBudget, '\$1500');
      expect(trip.formattedTravelers, '3 travellers');

      final map = trip.toMap();
      expect(map['budget'], 1500.0);
      expect(map['travelerCount'], 3);
      expect(map['dayItinerary'], isA<Map<String, dynamic>>());
      final dayItinMap = map['dayItinerary'] as Map<String, dynamic>;
      expect(dayItinMap['1'], ['eiffel_tower']);
      expect(dayItinMap['2'], ['louvre_museum']);

      final rawMap = trip.toRawMap();
      expect(rawMap['budget'], 1500.0);
      expect(rawMap['travelerCount'], 3);
      expect(rawMap['dayItinerary'], isA<Map<String, dynamic>>());
      final rawDayItinMap = rawMap['dayItinerary'] as Map<String, dynamic>;
      expect(rawDayItinMap['1'], ['eiffel_tower']);
      expect(rawDayItinMap['2'], ['louvre_museum']);

      // Round-trip from Firestore
      final firestoreData = <String, dynamic>{
        'userId': 'user_darsh_1',
        'name': 'Paris Adventure',
        'destination': 'Paris, France',
        'startDate': Timestamp.fromDate(testDateStart),
        'endDate': Timestamp.fromDate(testDateEnd),
        'attractionIds': ['eiffel_tower', 'louvre_museum'],
        'budget': 1500.0,
        'travelerCount': 3,
        'dayItinerary': {'1': ['eiffel_tower'], '2': ['louvre_museum']},
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
      };
      final restored = Trip.fromFirestore('trip_101', firestoreData);
      expect(restored.budget, 1500.0);
      expect(restored.travelerCount, 3);
      expect(restored.dayItinerary[1], ['eiffel_tower']);
      expect(restored.dayItinerary[2], ['louvre_museum']);

      // copyWith clears budget if requested
      final cleared = restored.copyWith(clearBudget: true, travelerCount: 1);
      expect(cleared.budget, isNull);
      expect(cleared.formattedBudget, '');
      expect(cleared.travelerCount, 1);
      expect(cleared.formattedTravelers, '1 traveller');
    });

    test('25. Trip resolvedDayItinerary auto-partitions attractions when dayItinerary is empty', () {
      final trip = Trip(
        id: 'trip_multi',
        userId: 'user_darsh_1',
        name: 'Euro Tour',
        destination: 'Europe',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12), // 3 days
        attractionIds: const ['a1', 'a2', 'a3', 'a4', 'a5'],
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final resolved = trip.resolvedDayItinerary;
      expect(resolved.keys.length, 3);
      expect(resolved[1], ['a1', 'a4']);
      expect(resolved[2], ['a2', 'a5']);
      expect(resolved[3], ['a3']);

      // If dayItinerary is explicitly populated, resolvedDayItinerary returns it as is
      final explicitTrip = trip.copyWith(
        dayItinerary: const {
          1: ['a5'],
          2: ['a1', 'a2'],
          3: ['a3', 'a4'],
        },
      );
      expect(explicitTrip.resolvedDayItinerary[1], ['a5']);
    });

    test('26. Trip validation rejects negative budget and traveler count less than 1', () async {
      // Negative budget on create
      expect(
        () => TripService.instance.createTrip(
          name: 'Budget Test',
          destination: 'Paris, France',
          startDate: testDateStart,
          endDate: testDateEnd,
          budget: -100,
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('Budget cannot be negative'),
        )),
      );

      // Traveler count < 1 on create
      expect(
        () => TripService.instance.createTrip(
          name: 'Traveler Test',
          destination: 'Paris, France',
          startDate: testDateStart,
          endDate: testDateEnd,
          travelerCount: 0,
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('Traveler count must be at least 1'),
        )),
      );

      // Negative budget on update
      expect(
        () => TripService.instance.updateTrip(
          tripId: sampleTrip.id,
          budget: -50,
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('Budget cannot be negative'),
        )),
      );

      // Traveler count < 1 on update
      expect(
        () => TripService.instance.updateTrip(
          tripId: sampleTrip.id,
          travelerCount: 0,
        ),
        throwsA(isA<TripServiceException>().having(
          (e) => e.message,
          'message',
          contains('Traveler count must be at least 1'),
        )),
      );
    });
  });

  group('Deterministic Itinerary Generation Engine Tests', () {
    test('27. ItineraryService generates deterministic day-by-day itinerary matching duration and pacing', () {
      final pool = [
        sampleAttraction,
        sampleAttraction2,
        sampleAttraction3,
        sampleAttraction4,
      ];

      final itinerary = ItineraryService.instance.generateItinerary(
        destination: 'Paris, France',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 11), // 2 days
        availableAttractions: pool,
        attractionsPerDay: 2,
      );

      expect(itinerary.durationInDays, 2);
      expect(itinerary.daySchedule.keys, containsAll([1, 2]));
      expect(itinerary.daySchedule[1]?.length, lessThanOrEqualTo(2));
      expect(itinerary.daySchedule[2]?.length, lessThanOrEqualTo(2));
      expect(itinerary.allAttractions.length, greaterThan(0));

      // Determinism: same call produces exact same result
      final itinerary2 = ItineraryService.instance.generateItinerary(
        destination: 'Paris, France',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 11),
        availableAttractions: pool,
        attractionsPerDay: 2,
      );
      expect(itinerary.dayItineraryIds, equals(itinerary2.dayItineraryIds));
    });

    test('28. ItineraryService distributes attractions evenly and prevents duplicates', () {
      final pool = [
        sampleAttraction,
        sampleAttraction2,
        sampleAttraction3,
        sampleAttraction4,
      ];

      final itinerary = ItineraryService.instance.generateItinerary(
        destination: 'Paris',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12), // 3 days
        availableAttractions: pool,
        attractionsPerDay: 2,
      );

      final seenIds = <String>{};
      for (final dayAttractions in itinerary.daySchedule.values) {
        for (final attr in dayAttractions) {
          expect(seenIds.contains(attr.id), isFalse, reason: 'Duplicate attraction in itinerary');
          seenIds.add(attr.id);
        }
      }
      expect(itinerary.allAttractionIds.length, seenIds.length);
    });

    test('29. ItineraryService filters by destination and prioritizes travel interests', () {
      final pool = [
        sampleAttraction, // Paris - Monument
        sampleAttraction2, // Paris - Museum
        sampleAttraction5, // Tokyo - Tower
      ];

      // Destination filter for Tokyo
      final tokyoItinerary = ItineraryService.instance.generateItinerary(
        destination: 'Tokyo, Japan',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 2),
        availableAttractions: pool,
      );
      expect(tokyoItinerary.allAttractionIds, contains('tokyo_tower'));
      expect(tokyoItinerary.allAttractionIds, isNot(contains('eiffel_tower')));

      // Interest prioritization: History & Culture
      final parisItinerary = ItineraryService.instance.generateItinerary(
        destination: 'Paris',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 10), // 1 day, 1 attraction
        availableAttractions: pool,
        interests: const {TravelInterest.historyAndCulture},
        attractionsPerDay: 1,
      );
      expect(parisItinerary.allAttractionIds.length, 1);
      expect(['eiffel_tower', 'louvre_museum'], contains(parisItinerary.allAttractionIds.first));
    });

    test('30. ItineraryService handles missing coordinates and incomplete attraction data safely', () {
      final incompleteAttraction = Attraction(
        id: 'incomplete_1',
        name: 'Mystery Landmark',
        category: 'Landmark',
        city: 'Paris',
        country: 'France',
        location: '',
        description: '',
        imageUrl: '',
        rating: 4.0,
        reviewCount: 10,
        openingHours: '',
        distance: '',
        entryFee: '',
        latitude: null,
        longitude: null,
      );

      final itinerary = ItineraryService.instance.generateItinerary(
        destination: 'Paris',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 11),
        availableAttractions: [incompleteAttraction],
      );

      expect(itinerary.allAttractionIds, contains('incomplete_1'));
      expect(itinerary.summary, isNotEmpty);

      // Empty pool returns empty schedule safely
      final emptyItinerary = ItineraryService.instance.generateItinerary(
        destination: 'Atlantis',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 11),
        availableAttractions: const [],
      );
      expect(emptyItinerary.allAttractionIds, isEmpty);
      expect(emptyItinerary.durationInDays, 2);
      expect(emptyItinerary.daySchedule.length, 2);
    });
  });

  group('TripService Day-by-Day CRUD Operations Tests', () {
    test('31. TripService updateDayItinerary synchronizes attractionIds and persists to store', () async {
      await TripService.instance.updateDayItinerary(
        tripId: sampleTrip.id,
        dayItinerary: const {
          1: ['eiffel_tower'],
          2: ['notre_dame', 'arc_de_triomphe'],
        },
      );

      final updated = await TripService.instance.getTrip(sampleTrip.id);
      expect(updated, isNotNull);
      expect(updated!.dayItinerary[1], ['eiffel_tower']);
      expect(updated.dayItinerary[2], ['notre_dame', 'arc_de_triomphe']);
      expect(updated.attractionIds, containsAll(['eiffel_tower', 'notre_dame', 'arc_de_triomphe']));
      expect(updated.attractionCount, 3);
    });

    test('32. TripService moveAttractionToDay, addAttractionToDay, and removeAttractionFromDay operate correctly', () async {
      // Set initial day itinerary
      await TripService.instance.updateDayItinerary(
        tripId: sampleTrip.id,
        dayItinerary: const {
          1: ['eiffel_tower', 'louvre_museum'],
          2: <String>[],
        },
      );

      // Move louvre_museum from Day 1 to Day 2
      await TripService.instance.moveAttractionToDay(
        tripId: sampleTrip.id,
        attractionId: 'louvre_museum',
        targetDay: 2,
      );

      var trip = await TripService.instance.getTrip(sampleTrip.id);
      expect(trip!.dayItinerary[1], ['eiffel_tower']);
      expect(trip.dayItinerary[2], ['louvre_museum']);

      // Add attraction to Day 2
      await TripService.instance.addAttractionToDay(
        tripId: sampleTrip.id,
        attractionId: 'arc_de_triomphe',
        day: 2,
      );
      trip = await TripService.instance.getTrip(sampleTrip.id);
      expect(trip!.dayItinerary[2], ['louvre_museum', 'arc_de_triomphe']);
      expect(trip.attractionIds, contains('arc_de_triomphe'));

      // Remove attraction from Day 2
      await TripService.instance.removeAttractionFromDay(
        tripId: sampleTrip.id,
        attractionId: 'louvre_museum',
        day: 2,
      );
      trip = await TripService.instance.getTrip(sampleTrip.id);
      expect(trip!.dayItinerary[2], ['arc_de_triomphe']);
      expect(trip.attractionIds, isNot(contains('louvre_museum')));
    });
  });

  group('Smart Trip UI Widget Tests', () {
    testWidgets('33. Trip details UI displays traveler count and budget badges', (tester) async {
      final tripWithBudget = sampleTrip.copyWith(
        budget: 1500.0,
        travelerCount: 3,
      );
      TripService.testTrips = <String, List<Trip>>{
        'user_darsh_1': <Trip>[tripWithBudget],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TripDetailsScreen(
            tripId: tripWithBudget.id,
            initialTrip: tripWithBudget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 travellers'), findsOneWidget);
      expect(find.text('💰 \$1500'), findsOneWidget);
      expect(find.text('5 days'), findsOneWidget);
    });

    testWidgets('34. Trip details UI Day-by-Day filter chips filter displayed attractions', (tester) async {
      final multiDayTrip = sampleTrip.copyWith(
        dayItinerary: const {
          1: ['eiffel_tower'],
          2: ['louvre_museum'],
        },
      );
      TripService.testTrips = <String, List<Trip>>{
        'user_darsh_1': <Trip>[multiDayTrip],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TripDetailsScreen(
            tripId: multiDayTrip.id,
            initialTrip: multiDayTrip,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check day filter chips exist
      expect(find.text('All Days'), findsOneWidget);
      expect(find.text('Day 1 (1)'), findsOneWidget);
      expect(find.text('Day 2 (1)'), findsOneWidget);

      // Both attractions visible initially under 'All Days'
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsOneWidget);

      // Tap 'Day 1 (1)' chip
      await tester.tap(find.text('Day 1 (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsNothing);

      // Tap 'Day 2 (1)' chip
      await tester.tap(find.text('Day 2 (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Louvre Museum'), findsOneWidget);
      expect(find.text('Eiffel Tower'), findsNothing);

      // Tap back to 'All Days'
      await tester.tap(find.text('All Days'));
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Louvre Museum'), findsOneWidget);
    });

    testWidgets('35. Trip details UI opens Smart Itinerary modal and applies generated schedule', (tester) async {
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

      // Open Smart Itinerary modal from AppBar
      final smartButton = find.byKey(const Key('trip_details_generate_itinerary_appbar_button'));
      expect(smartButton, findsOneWidget);
      await tester.tap(smartButton);
      await tester.pumpAndSettle();

      expect(find.text('Smart Itinerary Generator'), findsOneWidget);
      expect(find.text('Relaxed (2)'), findsOneWidget);
      expect(find.text('Standard (3)'), findsOneWidget);

      // Apply generated itinerary
      final applyButton = find.byKey(const Key('confirm_generate_itinerary_button'));
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Modal closed and snackbar or updated state shown
      expect(find.text('Smart Itinerary Generator'), findsNothing);
    });

    testWidgets('36. TripFormSheet supports budget, traveler count, and Smart Itinerary toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: TripFormSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create New Trip'), findsOneWidget);
      expect(find.text('Budget (optional)'), findsOneWidget);
      expect(find.text('Traveller'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Tap increment traveler
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Travellers'), findsOneWidget);

      // Check Smart Itinerary Switch
      final itinerarySwitch = find.byKey(const Key('trip_form_auto_itinerary_switch'));
      expect(itinerarySwitch, findsOneWidget);
      await tester.tap(itinerarySwitch);
      await tester.pumpAndSettle();

      // Fill in fields and create
      await tester.enterText(find.widgetWithText(TextFormField, 'Trip Name *'), 'Rome Getaway');
      await tester.enterText(find.widgetWithText(TextFormField, 'Destination *'), 'Rome, Italy');
      await tester.enterText(find.widgetWithText(TextFormField, 'Budget (optional)'), '2000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Trip'));
      await tester.pumpAndSettle();

      // Check that created trip has budget and travelerCount
      final trips = TripService.testTrips!['user_darsh_1'] ?? [];
      final created = trips.firstWhere((t) => t.name == 'Rome Getaway');
      expect(created.destination, 'Rome, Italy');
      expect(created.budget, 2000.0);
      expect(created.travelerCount, 2);
    });
  });
}
