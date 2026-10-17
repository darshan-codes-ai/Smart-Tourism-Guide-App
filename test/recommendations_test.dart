import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/models/travel_preference.dart';
import 'package:tourmate/screens/recommendations/recommendations_screen.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final sampleAttraction1 = Attraction(
    id: 'eiffel-tower',
    name: 'Eiffel Tower',
    category: 'Historical',
    city: 'Paris',
    country: 'France',
    location: 'Champ de Mars, 5 Av. Anatole France',
    description: 'Iconic wrought iron lattice tower and museum monument.',
    imageUrl: 'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f',
    rating: 4.8,
    reviewCount: 12500,
    openingHours: '09:00 - 23:45',
    distance: '2.5 km',
    entryFee: '€26.0',
    latitude: 48.8584,
    longitude: 2.2945,
  );

  final sampleAttraction2 = Attraction(
    id: 'colosseum-rome',
    name: 'Colosseum',
    category: 'Historical',
    city: 'Rome',
    country: 'Italy',
    location: 'Piazza del Colosseo, 1',
    description: 'Ancient Roman amphitheatre and historic architecture.',
    imageUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5',
    rating: 4.7,
    reviewCount: 8900,
    openingHours: '08:30 - 19:00',
    distance: '1.2 km',
    entryFee: '€16.0',
    latitude: 41.8902,
    longitude: 12.4922,
  );

  final sampleAttraction3 = Attraction(
    id: 'banff-nature',
    name: 'Banff National Park',
    category: 'Nature',
    city: 'Banff',
    country: 'Canada',
    location: 'Alberta, Canada',
    description: 'Stunning rocky mountains, glacial lakes, wildlife and hiking trails.',
    imageUrl: 'https://images.unsplash.com/photo-banff',
    rating: 4.9,
    reviewCount: 6500,
    openingHours: 'Open 24 hours',
    distance: '50 km',
    entryFee: 'Free',
    latitude: 51.4968,
    longitude: -115.9281,
  );

  final sampleAttraction4 = Attraction(
    id: 'expensive-safari',
    name: 'Luxury Serengeti Safari',
    category: 'Nature',
    city: 'Serengeti',
    country: 'Tanzania',
    location: 'Serengeti Park',
    description: 'Exclusive guided safari tour and wildlife adventure lodge.',
    imageUrl: 'https://images.unsplash.com/photo-safari',
    rating: 4.9,
    reviewCount: 200,
    openingHours: '06:00 - 18:00',
    distance: '100 km',
    entryFee: '€250.0',
    latitude: -2.3333,
    longitude: 34.8333,
  );

  final sampleAttraction5 = Attraction(
    id: 'sagrada-familia',
    name: 'Sagrada Familia',
    category: 'Historical',
    city: 'Barcelona',
    country: 'Spain',
    location: 'Carrer de Mallorca, 401',
    description: 'Magnificent unfinished Roman Catholic basilica with extraordinary architecture.',
    imageUrl: 'https://images.unsplash.com/photo-sagrada',
    rating: 4.8,
    reviewCount: 15000,
    openingHours: '09:00 - 18:00',
    distance: '3.0 km',
    entryFee: '€26.0',
    latitude: 41.4036,
    longitude: 2.1744,
  );

  final allTestAttractions = [
    sampleAttraction1,
    sampleAttraction2,
    sampleAttraction3,
    sampleAttraction4,
    sampleAttraction5,
  ];

  setUp(() {
    AttractionService.testAttractions = null;
    AttractionService.testStream = null;
    AttractionService.testAttractionsStreamController = null;
    RecommendationService.instance.resetPreferences();
    SavedPlacesStore.instance.handleUserUidChanged(null);
  });

  tearDown(() {
    AttractionService.testAttractions = null;
    AttractionService.testStream = null;
    AttractionService.testAttractionsStreamController?.close();
    AttractionService.testAttractionsStreamController = null;
    RecommendationService.instance.resetPreferences();
    SavedPlacesStore.instance.handleUserUidChanged(null);
  });

  group('1. TravelPreference & RecommendedAttraction Model Tests', () {
    test('TravelInterest enum provides label, icon, categories, and keywords', () {
      for (final interest in TravelInterest.values) {
        expect(interest.label, isNotEmpty);
        expect(interest.keywords, isNotEmpty);
        expect(interest.icon, isNotNull);
        expect(interest.categories, isNotEmpty);
        expect(interest.id, isNotEmpty);
      }
      expect(TravelInterest.historyAndCulture.label, 'History & Culture');
      expect(TravelInterest.natureAndWildlife.label, 'Nature & Wildlife');
      expect(TravelInterest.beaches.label, 'Beaches & Coast');
      expect(TravelInterest.adventure.label, 'Adventure');
      expect(TravelInterest.architecture.label, 'Architecture');
      expect(TravelInterest.religiousAndHeritage.label, 'Religious & Heritage');
    });

    test('BudgetPreference enum provides proper labels', () {
      expect(BudgetPreference.any.label, 'Any Budget');
      expect(BudgetPreference.freeOnly.label, 'Free Only');
      expect(BudgetPreference.budgetFriendly.label, 'Budget (≤ €30 / \$30)');
    });

    test('TravelPreference default constructor and hasActiveFilters flag', () {
      const defaultPref = TravelPreference();
      expect(defaultPref.selectedInterests, isEmpty);
      expect(defaultPref.selectedDestination, 'All Destinations');
      expect(defaultPref.budget, BudgetPreference.any);
      expect(defaultPref.minRating, 0.0);
      expect(defaultPref.hasActiveFilters, isFalse);

      final withInterest = defaultPref.copyWith(
        selectedInterests: {TravelInterest.historyAndCulture},
      );
      expect(withInterest.hasActiveFilters, isTrue);

      final withDest = defaultPref.copyWith(selectedDestination: 'France');
      expect(withDest.hasActiveFilters, isTrue);

      final withBudget = defaultPref.copyWith(budget: BudgetPreference.freeOnly);
      expect(withBudget.hasActiveFilters, isTrue);

      final withRating = defaultPref.copyWith(minRating: 4.5);
      expect(withRating.hasActiveFilters, isTrue);
    });

    test('TravelPreference copyWith updates fields selectively', () {
      const initial = TravelPreference();
      final updated = initial.copyWith(
        selectedInterests: {TravelInterest.adventure, TravelInterest.beaches},
        selectedDestination: 'Italy',
        budget: BudgetPreference.budgetFriendly,
        minRating: 4.0,
      );

      expect(updated.selectedInterests, contains(TravelInterest.adventure));
      expect(updated.selectedInterests, contains(TravelInterest.beaches));
      expect(updated.selectedDestination, 'Italy');
      expect(updated.budget, BudgetPreference.budgetFriendly);
      expect(updated.minRating, 4.0);
    });

    test('TravelPreference toMap and fromMap serialization round-trip', () {
      final pref = TravelPreference(
        selectedInterests: {TravelInterest.historyAndCulture, TravelInterest.architecture},
        selectedDestination: 'France',
        budget: BudgetPreference.budgetFriendly,
        minRating: 4.5,
      );

      final map = pref.toMap();
      final restored = TravelPreference.fromMap(map);

      expect(restored.selectedInterests.length, 2);
      expect(restored.selectedInterests, contains(TravelInterest.historyAndCulture));
      expect(restored.selectedInterests, contains(TravelInterest.architecture));
      expect(restored.selectedDestination, 'France');
      expect(restored.budget, BudgetPreference.budgetFriendly);
      expect(restored.minRating, 4.5);
    });

    test('RecommendedAttraction holds scoring properties and details', () {
      final rec = RecommendedAttraction(
        attraction: sampleAttraction1,
        matchScore: 92.5,
        matchReason: 'Top historical match in Paris',
        matchedTags: ['History & Culture', '4.8★ Rated'],
      );

      expect(rec.attraction.id, 'eiffel-tower');
      expect(rec.matchScore, 92.5);
      expect(rec.matchReason, 'Top historical match in Paris');
      expect(rec.matchedTags, ['History & Culture', '4.8★ Rated']);
    });
  });

  group('2. RecommendationService Algorithm & Business Logic Tests', () {
    test('empty attraction list produces empty recommendations', () {
      final recs = RecommendationService.instance.rankAttractions(
        attractions: [],
        preference: const TravelPreference(),
      );
      expect(recs, isEmpty);
    });

    test('recommendation ranking is deterministic and stable', () {
      const pref = TravelPreference(
        selectedInterests: {TravelInterest.historyAndCulture},
        selectedDestination: 'All Destinations',
      );

      final run1 = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: pref,
      );
      final run2 = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: pref,
      );

      expect(run1.length, run2.length);
      for (int i = 0; i < run1.length; i++) {
        expect(run1[i].attraction.id, run2[i].attraction.id);
        expect(run1[i].matchScore, run2[i].matchScore);
        expect(run1[i].matchReason, run2[i].matchReason);
      }
    });

    test('interest matching boosts relevant attractions', () {
      final historyRecs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(
          selectedInterests: {TravelInterest.historyAndCulture},
        ),
      );

      // Historical attractions should score highest
      final topHistory = historyRecs.first;
      expect(
        topHistory.attraction.category == 'Historical' ||
            topHistory.matchedTags.contains('History & Culture'),
        isTrue,
      );

      final natureRecs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(
          selectedInterests: {TravelInterest.natureAndWildlife},
        ),
      );

      // Nature attractions should score highest
      final topNature = natureRecs.first;
      expect(
        topNature.attraction.category == 'Nature' ||
            topNature.matchedTags.contains('Nature & Wildlife'),
        isTrue,
      );
      expect(topNature.attraction.name, 'Banff National Park');
    });

    test('destination filtering hard filters attractions by country/location', () {
      final franceRecs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(selectedDestination: 'France'),
      );

      expect(franceRecs.isNotEmpty, isTrue);
      for (final rec in franceRecs) {
        final matches = rec.attraction.country.toLowerCase().contains('france') ||
            rec.attraction.location.toLowerCase().contains('france');
        expect(matches, isTrue);
      }
      expect(franceRecs.map((r) => r.attraction.id), contains('eiffel-tower'));
      expect(franceRecs.map((r) => r.attraction.id), isNot(contains('colosseum-rome')));
    });

    test('non-matching destination returns empty list gracefully', () {
      final recs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(selectedDestination: 'Antarctica'),
      );
      expect(recs, isEmpty);
    });

    test('budget filter Free Only returns only free attractions', () {
      final freeRecs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(budget: BudgetPreference.freeOnly),
      );

      expect(freeRecs.isNotEmpty, isTrue);
      for (final rec in freeRecs) {
        final fee = rec.attraction.entryFee.toLowerCase();
        final isFree = fee.contains('free') || fee == '0' || fee == '€0';
        expect(isFree, isTrue);
      }
      expect(freeRecs.any((r) => r.attraction.id == 'banff-nature'), isTrue);
      expect(freeRecs.any((r) => r.attraction.id == 'eiffel-tower'), isFalse);
    });

    test('budget filter Budget Friendly filters out high-cost attractions', () {
      final budgetRecs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(budget: BudgetPreference.budgetFriendly),
      );

      expect(budgetRecs.isNotEmpty, isTrue);
      // €250 Safari should be excluded
      expect(budgetRecs.any((r) => r.attraction.id == 'expensive-safari'), isFalse);
      // €26 Eiffel Tower and Free Banff should be included
      expect(budgetRecs.any((r) => r.attraction.id == 'eiffel-tower'), isTrue);
      expect(budgetRecs.any((r) => r.attraction.id == 'banff-nature'), isTrue);
    });

    test('saved attraction affinity awards bonus score points', () {
      final initialRecs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(),
        savedAttractionIds: {},
      );
      final initialColosseum = initialRecs.firstWhere((r) => r.attraction.id == 'colosseum-rome');

      // Now pass colosseum as a saved attraction id
      final boostedRecs = RecommendationService.instance.rankAttractions(
        attractions: allTestAttractions,
        preference: const TravelPreference(),
        savedAttractionIds: {'colosseum-rome'},
      );
      final boostedColosseum = boostedRecs.firstWhere((r) => r.attraction.id == 'colosseum-rome');

      expect(boostedColosseum.matchScore, greaterThan(initialColosseum.matchScore));
      expect(boostedColosseum.matchedTags, contains('Saved Place'));
    });

    test('rating and popularity score contributions', () {
      const lowerRatedAttraction = Attraction(
        id: 'lower-rated',
        name: 'Lower Rated Place',
        category: 'Historical',
        city: 'Rome',
        country: 'Italy',
        location: 'Rome, Italy',
        description: 'Historic ancient architecture in Rome.',
        imageUrl: '',
        rating: 3.5,
        reviewCount: 50,
        openingHours: '9:00 - 17:00',
        distance: '1.0 km',
        entryFee: '€16.0',
      );

      final recs = RecommendationService.instance.rankAttractions(
        attractions: [sampleAttraction2, lowerRatedAttraction],
        preference: const TravelPreference(),
      );

      // Colosseum has 4.7 rating and 8900 reviews vs 3.5 rating and 50 reviews
      expect(recs.first.attraction.id, 'colosseum-rome');
      expect(recs.first.matchScore, greaterThan(recs.last.matchScore));
    });

    test('matchReason generates informative natural language explanation', () {
      final recs = RecommendationService.instance.rankAttractions(
        attractions: [sampleAttraction1],
        preference: const TravelPreference(
          selectedInterests: {TravelInterest.historyAndCulture},
          selectedDestination: 'France',
        ),
      );

      expect(recs, isNotEmpty);
      final reason = recs.first.matchReason;
      expect(reason, contains('History & Culture'));
      expect(reason, contains('France'));
      expect(reason, contains('4.8★'));
    });

    test('RecommendationService state mutation and notification', () {
      final service = RecommendationService.instance;
      int notifications = 0;
      void listener() => notifications++;

      service.addListener(listener);

      service.toggleInterest(TravelInterest.adventure);
      expect(service.currentPreference.selectedInterests, contains(TravelInterest.adventure));
      expect(notifications, 1);

      service.setDestination('Italy');
      expect(service.currentPreference.selectedDestination, 'Italy');
      expect(notifications, 2);

      service.setBudget(BudgetPreference.freeOnly);
      expect(service.currentPreference.budget, BudgetPreference.freeOnly);
      expect(notifications, 3);

      service.resetPreferences();
      expect(service.currentPreference.selectedInterests, isEmpty);
      expect(service.currentPreference.selectedDestination, 'All Destinations');
      expect(service.currentPreference.budget, BudgetPreference.any);
      expect(notifications, 4);

      service.removeListener(listener);
    });

    test('resilient against missing/null optional fields without crashing', () {
      const incompleteAttraction = Attraction(
        id: 'incomplete-1',
        name: 'Incomplete Landmark',
        category: '',
        city: '',
        country: '',
        location: '',
        description: '',
        imageUrl: '',
        rating: 0.0,
        openingHours: 'Not specified',
        distance: '',
        entryFee: '',
        latitude: null,
        longitude: null,
      );

      expect(
        () => RecommendationService.instance.rankAttractions(
          attractions: [incompleteAttraction],
          preference: const TravelPreference(
            selectedInterests: {TravelInterest.historyAndCulture},
            budget: BudgetPreference.budgetFriendly,
          ),
        ),
        returnsNormally,
      );
    });
  });

  group('3. RecommendationsScreen Widget Tests', () {
    Widget buildTestScreen() {
      return MaterialApp(
        theme: AppTheme.light(),
        home: const RecommendationsScreen(),
      );
    }

    testWidgets('shows loading indicator when waiting for attractions', (tester) async {
      final controller = StreamController<List<Attraction>>();
      AttractionService.testStream = controller.stream;

      await tester.pumpWidget(buildTestScreen());
      await tester.pump();

      expect(find.byKey(const Key('recommendations_loading_indicator')), findsOneWidget);
      expect(find.text('AI Travel Recommendations'), findsOneWidget);

      await controller.close();
    });

    testWidgets('shows error state and retry button on stream error', (tester) async {
      AttractionService.testStream = Stream.error('Failed to load Firestore data');

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load attractions'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows empty state when no attractions match filters', (tester) async {
      AttractionService.testStream = Stream.value(allTestAttractions);
      RecommendationService.instance.setDestination('Antarctica');

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('No matching attractions found'), findsOneWidget);
      expect(find.byKey(const Key('recommendations_empty_reset_button')), findsOneWidget);
    });

    testWidgets('renders all 6 interest filter chips and controls', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AttractionService.testStream = Stream.value(allTestAttractions);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('History & Culture'), findsOneWidget);
      expect(find.text('Nature & Wildlife'), findsOneWidget);
      expect(find.text('Beaches & Coast'), findsOneWidget);
      expect(find.text('Adventure'), findsOneWidget);
      expect(find.text('Architecture'), findsOneWidget);
      expect(find.text('Religious & Heritage'), findsOneWidget);
      expect(find.text('Any Budget'), findsOneWidget);
    });

    testWidgets('tapping interest chip updates recommendations', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AttractionService.testStream = Stream.value(allTestAttractions);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Tap Nature & Wildlife chip
      final natureChip = find.byKey(const Key('preference_interest_nature_wildlife'));
      expect(natureChip, findsOneWidget);
      await tester.tap(natureChip);
      await tester.pumpAndSettle();

      expect(
        RecommendationService.instance.currentPreference.selectedInterests,
        contains(TravelInterest.natureAndWildlife),
      );

      // Verify Banff National Park appears prominently
      expect(find.text('Banff National Park'), findsWidgets);
    });

    testWidgets('recommendation card displays match score badge, reason, and actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AttractionService.testStream = Stream.value([sampleAttraction1]);
      RecommendationService.instance.toggleInterest(TravelInterest.historyAndCulture);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.textContaining('% Match'), findsOneWidget);
      expect(find.text('Add to Trip'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('favorite button toggles save state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AttractionService.testStream = Stream.value([sampleAttraction1]);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(SavedPlacesStore.instance.isSaved('eiffel-tower'), isFalse);

      final favButton = find.byKey(const Key('recommended_favorite_button_eiffel-tower'));
      expect(favButton, findsOneWidget);
      await tester.tap(favButton);
      await tester.pumpAndSettle();

      expect(SavedPlacesStore.instance.isSaved('eiffel-tower'), isTrue);
    });

    testWidgets('reset button restores default filters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AttractionService.testStream = Stream.value(allTestAttractions);
      RecommendationService.instance.toggleInterest(TravelInterest.architecture);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final resetBtn = find.byKey(const Key('recommendations_appbar_reset_button'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(RecommendationService.instance.currentPreference.hasActiveFilters, isFalse);
    });

    testWidgets('details button opens attraction details bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AttractionService.testStream = Stream.value([sampleAttraction1]);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final detailsBtn = find.byKey(const Key('recommended_view_details_button_eiffel-tower'));
      expect(detailsBtn, findsOneWidget);
      await tester.tap(detailsBtn);
      await tester.pumpAndSettle();

      // Details bottom sheet shows description
      expect(find.text(sampleAttraction1.description), findsOneWidget);
    });
  });
}

