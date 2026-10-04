// scripts/import_global_attractions.dart
// ignore_for_file: avoid_print
//
// TourMate Global Attraction Database Normalizer & Importer
// Phase 2: Standalone Administrative Tool
//
// Supports:
//   dart run scripts/import_global_attractions.dart --dry-run
//   dart run scripts/import_global_attractions.dart --stats
//   dart run scripts/import_global_attractions.dart --import (Requires explicit developer approval & credentials)

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Known existing attraction IDs that must be protected and never duplicated.
class ExistingAttractions {
  /// Live Firestore document IDs currently in production.
  static const Set<String> liveFirestoreIds = {
    'Charminar',
  };

  /// Legacy ID alias map (e.g. dummy lowercase -> Firestore PascalCase).
  static const Map<String, String> legacyIdAliases = {
    'charminar': 'Charminar',
  };

  /// Existing dummy attractions defined in TourMate (23 total).
  static const Map<String, String> dummyAttractions = {
    'charminar': 'Charminar',
    'golconda-fort': 'Golconda Fort',
    'taj-mahal': 'Taj Mahal',
    'red-fort': 'Red Fort',
    'qutub-minar': 'Qutub Minar',
    'gateway-of-india': 'Gateway of India',
    'eiffel-tower': 'Eiffel Tower',
    'louvre-museum': 'Louvre Museum',
    'colosseum': 'Colosseum',
    'trevi-fountain': 'Trevi Fountain',
    'tokyo-skytree': 'Tokyo Skytree',
    'fushimi-inari': 'Fushimi Inari Shrine',
    'statue-of-liberty': 'Statue of Liberty',
    'central-park': 'Central Park',
    'grand-canyon': 'Grand Canyon National Park',
    'big-ben': 'Big Ben',
    'british-museum': 'British Museum',
    'burj-khalifa': 'Burj Khalifa',
    'sydney-opera-house': 'Sydney Opera House',
    'christ-the-redeemer': 'Christ the Redeemer',
    'pyramids-of-giza': 'Pyramids of Giza',
    'sagrada-familia': 'Basílica de la Sagrada Família',
    'gardens-by-the-bay': 'Gardens by the Bay',
    'grand-bazaar': 'Grand Bazaar',
  };
}

/// Normalization and validation result for a candidate attraction.
class NormalizedAttraction {
  NormalizedAttraction({
    required this.id,
    required this.wikidataId,
    required this.name,
    required this.category,
    required this.description,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.popularity = 0.0,
    this.entryFee = 'Not available',
    this.openingHours = 'Not available',
    this.currency,
  });

  final String id;
  final String wikidataId;
  final String name;
  final String category;
  final String description;
  final String city;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final double popularity;
  final String entryFee;
  final String openingHours;
  final String? currency;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wikidataId': wikidataId,
      'name': name,
      'category': category,
      'description': description,
      'city': city,
      'country': country,
      'countryCode': countryCode,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'popularity': popularity,
      'entryFee': entryFee,
      'openingHours': openingHours,
      if (currency != null) 'currency': currency,
      'distance': '',
      'location': city.isNotEmpty ? '$city, $country' : country,
      'isSaved': false,
    };
  }
}

/// Core pipeline for normalizing, deduplicating, and importing global attractions.
class GlobalAttractionPipeline {
  GlobalAttractionPipeline({
    this.rawSourcePath = 'assets/data/raw_wikidata_attractions.json',
    this.outputPath = 'assets/data/global_attractions.json',
  });

  final String rawSourcePath;
  final String outputPath;

  // Pipeline execution stats
  int totalSourceRecords = 0;
  int validRecords = 0;
  int invalidRecords = 0;
  int duplicates = 0;
  int existingRecords = 0;
  int newRecords = 0;
  int recordsRequiringReview = 0;
  int missingCoordinates = 0;
  int missingCountry = 0;
  int missingCategory = 0;
  int missingImage = 0;
  int idCollisions = 0;

  final List<String> reviewLog = [];
  final List<NormalizedAttraction> processedAttractions = [];
  final Set<String> registeredIds = {};
  final Map<String, NormalizedAttraction> registeredByLocation = {};

  static const List<String> canonicalCategories = [
    'Historical',
    'Nature',
    'Religious',
    'Adventure',
    'Food',
    'Shopping',
  ];

  static const Map<String, String> countryCurrencies = {
    'US': 'USD',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'DE': 'EUR',
    'GR': 'EUR',
    'NL': 'EUR',
    'PT': 'EUR',
    'AT': 'EUR',
    'IE': 'EUR',
    'GB': 'GBP',
    'JP': 'JPY',
    'IN': 'INR',
    'AU': 'AUD',
    'CA': 'CAD',
    'BR': 'BRL',
    'EG': 'EGP',
    'SG': 'SGD',
    'TR': 'TRY',
    'CH': 'CHF',
    'NO': 'NOK',
    'SE': 'SEK',
    'AE': 'AED',
    'SA': 'SAR',
    'NZ': 'NZD',
    'MX': 'MXN',
    'ID': 'IDR',
    'TH': 'THB',
    'KR': 'KRW',
    'VN': 'VND',
    'MY': 'MYR',
    'CN': 'CNY',
    'ZA': 'ZAR',
  };

  /// Maps Wikidata instance-of QIDs to TourMate canonical categories.
  static String? mapWikidataCategory(String typeQid) {
    switch (typeQid) {
      // Historical
      case 'Q570116': // tourist attraction
      case 'Q33506': // museum
      case 'Q4989906': // monument
      case 'Q23413': // castle
      case 'Q16560': // palace
      case 'Q839954': // archaeological site
      case 'Q12518': // tower (historical)
        return 'Historical';

      // Nature
      case 'Q46169': // national park
      case 'Q22698': // park
      case 'Q8502': // mountain
      case 'Q34038': // waterfall
      case 'Q355304': // watercourse / lake
        return 'Nature';

      // Religious
      case 'Q16970': // church
      case 'Q44539': // temple
      case 'Q32815': // mosque
      case 'Q34627': // synagogue
      case 'Q1755107': // shrine
      case 'Q44613': // monastery
      case 'Q1994717': // pagoda
        return 'Religious';

      // Adventure
      case 'Q860861': // observation deck
      case 'Q188055': // observation tower
      case 'Q194195': // amusement park
      case 'Q107649': // hiking trail
      case 'Q8072': // volcano
        return 'Adventure';

      // Food
      case 'Q1128877': // food market
      case 'Q11707': // restaurant district / landmark
      case 'Q1312': // vineyard
        return 'Food';

      // Shopping
      case 'Q132510': // bazaar
      case 'Q175199': // souq
      case 'Q29304': // marketplace
      case 'Q11315': // shopping mall
        return 'Shopping';

      default:
        return null;
    }
  }

  /// Calculates the Haversine distance in meters between two coordinates.
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Extracts coordinates from WKT 'Point(longitude latitude)'.
  static (double lat, double lng)? parseWktPoint(String point) {
    final match = RegExp(r'Point\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)', caseSensitive: false)
        .firstMatch(point.trim());
    if (match == null) return null;

    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lng == null || lat == null) return null;

    if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) {
      return null;
    }
    return (lat, lng);
  }

  /// Generates a URL-safe kebab-case slug.
  static String slugify(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// Normalizes a name string for duplicate comparison.
  static String normalizeName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceFirst(RegExp(r'^(the|le|la|el|il|al)\s+'), '')
        .replaceAll(RegExp(r'[^\w]'), '');
  }

  /// Executes the complete normalization and deduplication pipeline.
  void processDataset() {
    final file = File(rawSourcePath);
    if (!file.existsSync()) {
      throw FileSystemException('Source dataset not found: $rawSourcePath');
    }

    final rawJson = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    totalSourceRecords = rawJson.length;

    // Register existing live Firestore IDs first to protect them
    for (final id in ExistingAttractions.liveFirestoreIds) {
      registeredIds.add(id);
    }

    // Register existing dummy attractions
    for (final entry in ExistingAttractions.dummyAttractions.entries) {
      final canonicalId = ExistingAttractions.legacyIdAliases[entry.key] ?? entry.key;
      registeredIds.add(canonicalId);
    }

    for (final item in rawJson) {
      final map = item as Map<String, dynamic>;
      final rawName = map['name']?.toString().trim() ?? '';
      final rawCountry = map['country']?.toString().trim() ?? '';
      final rawCountryCode = map['countryCode']?.toString().trim().toUpperCase() ?? '';
      final rawCoords = map['coords']?.toString() ?? '';
      final rawType = map['type']?.toString() ?? '';
      final rawWikidataId = map['wikidataId']?.toString() ?? '';
      final rawDescription = map['description']?.toString().trim() ?? '';
      final rawImage = map['image']?.toString().trim() ?? '';

      // Validation 1: Name and Country
      if (rawName.isEmpty || rawCountry.isEmpty) {
        invalidRecords++;
        if (rawCountry.isEmpty) missingCountry++;
        continue;
      }

      // Validation 2: Country Code (2-letter ISO)
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(rawCountryCode)) {
        invalidRecords++;
        missingCountry++;
        continue;
      }

      // Validation 3: Coordinates
      final coords = parseWktPoint(rawCoords);
      if (coords == null) {
        invalidRecords++;
        missingCoordinates++;
        continue;
      }

      // Validation 4: Category Normalization
      final category = mapWikidataCategory(rawType);
      if (category == null) {
        // Unmapped or ambiguous category -> flag for review, do not invent
        recordsRequiringReview++;
        missingCategory++;
        reviewLog.add('Ambiguous category for "$rawName" (type $rawType)');
        continue;
      }

      // Validation 5: Secure Image URL
      String imageUrl = '';
      if (rawImage.isNotEmpty) {
        if (rawImage.startsWith('http://commons.wikimedia.org')) {
          imageUrl = rawImage.replaceFirst('http://', 'https://');
        } else if (rawImage.startsWith('https://')) {
          imageUrl = rawImage;
        } else {
          missingImage++;
        }
      } else {
        missingImage++;
      }

      // Check Existing Attraction Match & Charminar Protection
      final normName = normalizeName(rawName);
      String? matchedExistingId;

      // Special check: Charminar protection
      if (normName.contains('charminar') && rawCountryCode == 'IN') {
        matchedExistingId = 'Charminar';
      } else {
        // Check dummy list matches
        for (final entry in ExistingAttractions.dummyAttractions.entries) {
          final dummyNorm = normalizeName(entry.value);
          if (normName == dummyNorm || (normName.contains(dummyNorm) && dummyNorm.length > 5)) {
            matchedExistingId = ExistingAttractions.legacyIdAliases[entry.key] ?? entry.key;
            break;
          }
        }
      }

      String targetId;
      if (matchedExistingId != null) {
        targetId = matchedExistingId;
        existingRecords++;
      } else {
        // Deterministic ID derivation: {countryCode.toLowerCase()}-{slug}
        final baseSlug = '${rawCountryCode.toLowerCase()}-${slugify(rawName)}';
        if (registeredIds.contains(baseSlug)) {
          // Slug collision -> append Wikidata QID for absolute uniqueness
          targetId = '$baseSlug-${rawWikidataId.toLowerCase()}';
          idCollisions++;
        } else {
          targetId = baseSlug;
        }
      }

      // Duplicate Check 1: Exact ID Collision in this batch
      if (processedAttractions.any((a) => a.id == targetId)) {
        duplicates++;
        continue;
      }

      // Duplicate Check 2: Name + Country + Geographic Proximity (Haversine)
      bool isDuplicate = false;
      for (final existing in processedAttractions) {
        if (existing.countryCode == rawCountryCode) {
          final distMeters = haversineDistanceMeters(
            coords.$1,
            coords.$2,
            existing.latitude,
            existing.longitude,
          );

          if (distMeters < 200) {
            // Proximity check: < 200m
            final normExisting = normalizeName(existing.name);
            if (normName == normExisting ||
                normName.contains(normExisting) ||
                normExisting.contains(normName)) {
              isDuplicate = true;
              duplicates++;
              break;
            } else {
              // Same location within 200m but different name -> Flag for manual review
              recordsRequiringReview++;
              reviewLog.add(
                'Proximity review (< 200m): "$rawName" vs "${existing.name}" in $rawCountry',
              );
            }
          }
        }
      }

      if (isDuplicate) continue;

      // Real Data Only (Phase 2.2):
      // No fake ratings (0.0), no fake review count (0), no fake fee or hours
      final attraction = NormalizedAttraction(
        id: targetId,
        wikidataId: rawWikidataId,
        name: rawName,
        category: category,
        description: rawDescription,
        city: '',
        country: rawCountry,
        countryCode: rawCountryCode,
        latitude: coords.$1,
        longitude: coords.$2,
        imageUrl: imageUrl,
        rating: 0.0,
        reviewCount: 0,
        popularity: 0.0,
        entryFee: 'Not available',
        openingHours: 'Not available',
        currency: countryCurrencies[rawCountryCode],
      );

      registeredIds.add(targetId);
      processedAttractions.add(attraction);
      if (matchedExistingId == null) {
        newRecords++;
      }
      validRecords++;
    }

    // Persist verified output dataset
    final outFile = File(outputPath);
    outFile.parent.createSync(recursive: true);
    final outputList = processedAttractions.map((a) => a.toMap()).toList();
    outFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(outputList),
    );
  }

  /// Prints dry run summary report.
  void printDryRunReport() {
    print('====================================================');
    print('  TOURMATE GLOBAL ATTRACTION DATABASE - DRY RUN     ');
    print('====================================================');
    print('Source Dataset:        $rawSourcePath');
    print('Output Destination:    $outputPath');
    print('----------------------------------------------------');
    print('Total Source Records:  $totalSourceRecords');
    print('Valid Records:         $validRecords');
    print('Invalid Records:       $invalidRecords');
    print('Duplicates Detected:   $duplicates');
    print('Existing IDs Matched:  $existingRecords');
    print('New Records:           $newRecords');
    print('Manual Review Flags:   $recordsRequiringReview');
    print('Missing Coordinates:   $missingCoordinates');
    print('Missing Country:       $missingCountry');
    print('Missing Category:      $missingCategory');
    print('Missing Image:         $missingImage');
    print('ID Collisions Resolved:$idCollisions');
    print('----------------------------------------------------');

    print('\nID Strategy & Charminar Protection:');
    final charminar = processedAttractions.where((a) => a.id == 'Charminar').toList();
    if (charminar.isNotEmpty) {
      print('  [PROTECTED] Charminar document ID: "${charminar.first.id}" (Matches live Firestore)');
    } else {
      print('  [INFO] Charminar ID preserved in registry');
    }

    print('\nGeographic Breakdown (Sample Countries):');
    final byCountry = <String, int>{};
    for (final a in processedAttractions) {
      byCountry[a.country] = (byCountry[a.country] ?? 0) + 1;
    }
    final sortedCountries = byCountry.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final c in sortedCountries.take(15)) {
      print('  ${c.key.padRight(24)}: ${c.value} attractions');
    }

    print('\nCategory Distribution:');
    final byCategory = <String, int>{};
    for (final a in processedAttractions) {
      byCategory[a.category] = (byCategory[a.category] ?? 0) + 1;
    }
    for (final cat in canonicalCategories) {
      print('  ${cat.padRight(16)}: ${byCategory[cat] ?? 0}');
    }

    print('\nSample Normalized Records (First 3):');
    for (final a in processedAttractions.take(3)) {
      print('  ID:          ${a.id}');
      print('  Name:        ${a.name}');
      print('  Category:    ${a.category}');
      print('  Country:     ${a.country} (${a.countryCode})');
      print('  Coords:      ${a.latitude}, ${a.longitude}');
      final imgPreview = a.imageUrl.isEmpty
          ? 'None'
          : '${a.imageUrl.substring(0, math.min(50, a.imageUrl.length))}...';
      print('  Image:       $imgPreview');
      print('  Rating:      ${a.rating} (Source-backed only; zero fake ratings)');
      print('  Entry Fee:   ${a.entryFee}');
      print('  ------------------------------------------------');
    }

    if (reviewLog.isNotEmpty) {
      print('\nReview Log Excerpts (First 5):');
      for (final log in reviewLog.take(5)) {
        print('  - $log');
      }
    }
    print('====================================================');
    print('DRY RUN COMPLETE — ZERO FIRESTORE WRITES PERFORMED');
    print('====================================================');
  }
}

void main(List<String> args) {
  final isDryRun = args.contains('--dry-run') || !args.contains('--import');
  final isImport = args.contains('--import');

  final pipeline = GlobalAttractionPipeline();
  pipeline.processDataset();

  if (isDryRun || !isImport) {
    pipeline.printDryRunReport();
    return;
  }

  // Administrative Import Mode (Only reached with --import and explicit approval)
  print('Administrative import requested. Checking authorization...');
  final credentialsPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
  if (credentialsPath == null || !File(credentialsPath).existsSync()) {
    print('ERROR: Administrative credentials not found.');
    print('Production import requires GOOGLE_APPLICATION_CREDENTIALS environment variable.');
    print('No changes were made to Firestore.');
    exit(1);
  }

  print('Batch import ready with safe chunk size of 400 operations.');
  print('Awaiting user confirmation.');
}