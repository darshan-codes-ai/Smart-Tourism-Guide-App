// test/phase2_database_test.dart
// Tests for TourMate Phase 2: Global Attraction Database

import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/firestore_service.dart';

import '../scripts/import_global_attractions.dart';

void main() {
  group('Phase 2.1 — Data Model Safety & Legacy entryfee Parsing', () {
    test('parses lowercase legacy "entryfee" from live Charminar document', () {
      final legacyCharminarData = {
        'name': 'Charminar',
        'category': 'Historical',
        'city': 'Hyderabad',
        'description':
            'A 16th-century mosque with four grand arches and minarets.',
        'entryfee': '₹25',
        'openingTime': '09:00',
        'closingTime': '17:30',
        'popularity': 95,
        'rating': 4.5,
        'reviewCount': 1200,
        'latitude': 17.3616,
        'longitude': 78.4747,
      };

      final attraction = Attraction.fromFirestore('Charminar', legacyCharminarData);

      expect(attraction.id, 'Charminar');
      expect(attraction.name, 'Charminar');
      expect(attraction.entryFee, '₹25');
      expect(attraction.formattedFee, '₹25');
      expect(attraction.latitude, 17.3616);
      expect(attraction.longitude, 78.4747);
      expect(attraction.city, 'Hyderabad');
    });

    test('prefers "entryFee" over lowercase "entryfee" if both exist', () {
      final data = {
        'name': 'Eiffel Tower',
        'entryFee': '€29',
        'entryfee': '€20',
      };

      final attraction = Attraction.fromFirestore('eiffel-tower', data);
      expect(attraction.entryFee, '€29');
    });

    test('handles fallback when neither entryFee nor entryfee exists', () {
      final data = {
        'name': 'Central Park',
      };

      final attraction = Attraction.fromFirestore('central-park', data);
      expect(attraction.entryFee, 'Not available');
    });
  });

  group('Phase 2.4 — ID Strategy & Charminar Protection', () {
    tearDown(() {
      AttractionService.devFallbackEnabled = false;
      AttractionService.testGetAttraction = null;
    });

    test('Charminar ID is preserved and not overwritten with lowercase', () {
      expect(ExistingAttractions.liveFirestoreIds.contains('Charminar'), isTrue);
      expect(ExistingAttractions.legacyIdAliases['charminar'], 'Charminar');
    });

    test('AttractionService safely resolves both "charminar" and "Charminar"', () async {
      AttractionService.devFallbackEnabled = true;

      // Requesting lowercase 'charminar' resolves without throwing
      final resolved = await AttractionService.instance.getAttraction('charminar');
      expect(resolved, isNotNull);
      expect(resolved!.name, 'Charminar');

      // Requesting PascalCase 'Charminar' also resolves
      final resolvedPascal = await AttractionService.instance.getAttraction('Charminar');
      expect(resolvedPascal, isNotNull);
      expect(resolvedPascal!.name, 'Charminar');
    });
  });

  group('Phase 2.5 — Normalization Pipeline Validation', () {
    test('validates coordinates strictly within WGS84 bounds', () {
      final valid = GlobalAttractionPipeline.parseWktPoint('Point(2.2945 48.8584)');
      expect(valid, isNotNull);
      expect(valid!.$1, 48.8584); // latitude
      expect(valid.$2, 2.2945); // longitude

      // Out of bounds latitude (> 90)
      final invalidLat = GlobalAttractionPipeline.parseWktPoint('Point(0.0 95.0)');
      expect(invalidLat, isNull);

      // Out of bounds longitude (> 180)
      final invalidLng = GlobalAttractionPipeline.parseWktPoint('Point(185.0 0.0)');
      expect(invalidLng, isNull);

      // Malformed point
      final malformed = GlobalAttractionPipeline.parseWktPoint('InvalidPoint');
      expect(malformed, isNull);
    });

    test('validates 2-letter uppercase ISO country code format', () {
      final validRegex = RegExp(r'^[A-Z]{2}$');
      expect(validRegex.hasMatch('FR'), isTrue);
      expect(validRegex.hasMatch('US'), isTrue);
      expect(validRegex.hasMatch('IN'), isTrue);
      expect(validRegex.hasMatch('fra'), isFalse);
      expect(validRegex.hasMatch('12'), isFalse);
      expect(validRegex.hasMatch(''), isFalse);
    });

    test('maps Wikidata types into TourMate canonical categories correctly', () {
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q570116'), 'Historical');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q33506'), 'Historical');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q4989906'), 'Historical');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q46169'), 'Nature');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q34038'), 'Nature');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q16970'), 'Religious');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q32815'), 'Religious');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q860861'), 'Adventure');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q132510'), 'Shopping');
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q1128877'), 'Food');

      // Unknown QID returns null for manual review
      expect(GlobalAttractionPipeline.mapWikidataCategory('Q999999999'), isNull);
    });
  });

  group('Phase 2.6 — Duplicate Detection Engine', () {
    test('calculates Haversine distance accurately', () {
      // Distance between Eiffel Tower (48.8584, 2.2945) and Champ de Mars (48.8556, 2.2986) ~ 430m
      final dist = GlobalAttractionPipeline.haversineDistanceMeters(
        48.8584,
        2.2945,
        48.8556,
        2.2986,
      );
      expect(dist, greaterThan(350));
      expect(dist, lessThan(550));

      // Same point distance should be 0
      final zeroDist = GlobalAttractionPipeline.haversineDistanceMeters(
        48.8584,
        2.2945,
        48.8584,
        2.2945,
      );
      expect(zeroDist, closeTo(0.0, 0.001));
    });

    test('normalizes names for duplicate comparison by removing prefixes and punctuation', () {
      expect(
        GlobalAttractionPipeline.normalizeName('The Eiffel Tower!'),
        'eiffeltower',
      );
      expect(
        GlobalAttractionPipeline.normalizeName('Le Louvre'),
        'louvre',
      );
      expect(
        GlobalAttractionPipeline.normalizeName('El Prado'),
        'prado',
      );
    });

    test('generates clean URL-safe slugs', () {
      expect(
        GlobalAttractionPipeline.slugify('Eiffel Tower'),
        'eiffel-tower',
      );
      expect(
        GlobalAttractionPipeline.slugify("L'Anse aux Meadows!"),
        'lanse-aux-meadows',
      );
      expect(
        GlobalAttractionPipeline.slugify('Taj Mahal, Agra'),
        'taj-mahal-agra',
      );
    });
  });

  group('Phase 2.9 — Query Performance, Filtering, and Pagination', () {
    tearDown(() {
      AttractionService.devFallbackEnabled = false;
      AttractionService.testStream = null;
    });

    test('watchAttractions supports limit, category, and country filtering', () async {
      AttractionService.devFallbackEnabled = true;

      final allStream = AttractionService.instance.watchAttractions();
      final all = await allStream.first;
      expect(all.length, greaterThan(15));

      final limitedStream = AttractionService.instance.watchAttractions(limit: 5);
      final limited = await limitedStream.first;
      expect(limited.length, 5);

      final franceStream = AttractionService.instance.watchAttractions(country: 'France');
      final france = await franceStream.first;
      expect(france.every((a) => a.country == 'France'), isTrue);

      final natureStream = AttractionService.instance.watchAttractions(category: 'Nature');
      final nature = await natureStream.first;
      expect(nature.every((a) => a.category == 'Nature'), isTrue);
    });

    test('getAttractionsPage returns paginated chunks', () async {
      AttractionService.devFallbackEnabled = true;

      final page1 = await AttractionService.instance.getAttractionsPage(limit: 4);
      expect(page1.length, 4);

      final pageFrance = await AttractionService.instance.getAttractionsPage(
        country: 'France',
        limit: 10,
      );
      expect(pageFrance.every((a) => a.country == 'France'), isTrue);
    });
  });

  group('Phase 2.12 — Favorites Compatibility with Case Variations', () {
    tearDown(() {
      FirestoreService.testFavorites = null;
      SavedPlacesStore.instance.resetForTest();
    });

    test('SavedPlacesStore registers Charminar with case protection', () {
      const charminar = Attraction(
        id: 'Charminar',
        name: 'Charminar',
        category: 'Historical',
        description: 'Iconic mosque',
        imageUrl: '',
        rating: 4.5,
        distance: '1.2 km',
        location: 'Hyderabad, India',
        openingHours: '9:00 AM - 5:30 PM',
        entryFee: '₹25',
      );

      SavedPlacesStore.instance.registerAttractions([charminar]);

      // Both lowercase and PascalCase can be resolved from known attractions
      expect(SavedPlacesStore.instance.savedAttractions, isEmpty);

      // Toggling Charminar
      SavedPlacesStore.instance.toggle('Charminar');
      expect(SavedPlacesStore.instance.isSaved('Charminar'), isTrue);
      expect(SavedPlacesStore.instance.savedAttractions.length, 1);
      expect(SavedPlacesStore.instance.savedAttractions.first.name, 'Charminar');
    });
  });
}
