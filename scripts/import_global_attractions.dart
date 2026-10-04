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

/// Minimal Firestore Admin REST client.
///
/// Uses the service-account key supplied through GOOGLE_APPLICATION_CREDENTIALS.
/// The key itself must never be committed to the repository.
class FirestoreAdminClient {
  FirestoreAdminClient(this.serviceAccount);

  final Map<String, dynamic> serviceAccount;
  String? _accessToken;

  String get projectId =>
      serviceAccount['project_id']?.toString() ?? 'tourmate-70d03';

  Future<String> _getAccessToken() async {
    if (_accessToken != null) return _accessToken!;

    final clientEmail = serviceAccount['client_email']?.toString();
    final privateKey = serviceAccount['private_key']?.toString();

    if (clientEmail == null || clientEmail.isEmpty) {
      throw Exception('Service account is missing client_email.');
    }
    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('Service account is missing private_key.');
    }

    final openssl = await _findOpenSsl();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    String b64(List<int> bytes) =>
        base64Url.encode(bytes).replaceAll('=', '');

    final header = b64(utf8.encode(jsonEncode({
      'alg': 'RS256',
      'typ': 'JWT',
    })));

    final payload = b64(utf8.encode(jsonEncode({
      'iss': clientEmail,
      'scope': 'https://www.googleapis.com/auth/datastore',
      'aud': 'https://oauth2.googleapis.com/token',
      'iat': now,
      'exp': now + 3600,
    })));

    final unsignedJwt = '${header}.${payload}';

    final tempKey = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'tourmate-service-account-${pid}.pem',
    );

    await tempKey.writeAsString(privateKey);

    try {
      final signed = await Process.run(
        openssl,
        ['dgst', '-sha256', '-sign', tempKey.path],
        stdoutEncoding: null,
        stderrEncoding: utf8,
      );

      if (signed.exitCode != 0) {
        throw Exception(
          'OpenSSL RSA signing failed: ${signed.stderr}',
        );
      }

      final signature = b64(signed.stdout as List<int>);
      final assertion = '${unsignedJwt}.${signature}';

      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse('https://oauth2.googleapis.com/token'),
        );

        request.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded');

        request.write(
          'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer'
          '&assertion=${Uri.encodeComponent(assertion)}',
        );

        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Google OAuth token request failed '
            '(${response.statusCode}): ${body}',
          );
        }

        final data = jsonDecode(body) as Map<String, dynamic>;
        final token = data['access_token']?.toString();

        if (token == null || token.isEmpty) {
          throw Exception(
            'Google OAuth response did not contain access_token.',
          );
        }

        _accessToken = token;
        return token;
      } finally {
        client.close(force: true);
      }
    } finally {
      if (await tempKey.exists()) {
        await tempKey.delete();
      }
    }
  }

  Future<String> _findOpenSsl() async {
    final candidates = <String>[
      'openssl',
      r'C:\Program Files\Git\usr\bin\openssl.exe',
      r'C:\Program Files\OpenSSL-Win64\bin\openssl.exe',
      r'C:\Program Files\OpenSSL\bin\openssl.exe',
    ];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(
          candidate,
          ['version'],
          runInShell: candidate == 'openssl',
        );
        if (result.exitCode == 0) return candidate;
      } catch (_) {}
    }

    throw Exception(
      'OpenSSL was not found. Install OpenSSL or Git for Windows, '
      'then ensure openssl.exe is available.',
    );
  }

  Map<String, dynamic> _firestoreValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is num) return {'doubleValue': value.toDouble()};
    if (value is String) return {'stringValue': value};

    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_firestoreValue).toList(),
        },
      };
    }

    if (value is Map) {
      return {
        'mapValue': {
          'fields': value.map(
            (key, item) => MapEntry(
              key.toString(),
              _firestoreValue(item),
            ),
          ),
        },
      };
    }

    return {'stringValue': value.toString()};
  }

  Future<void> writeBatch(List<Map<String, dynamic>> attractions) async {
    if (attractions.isEmpty) return;
    if (attractions.length > 400) {
      throw ArgumentError('Firestore batches may not exceed 400 operations.');
    }

    final accessToken = await _getAccessToken();

    final writes = attractions.map((attraction) {
      final id = attraction['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Attraction is missing a deterministic document ID.');
      }

      final fields = <String, dynamic>{};
      for (final entry in attraction.entries) {
        if (entry.key == 'id') continue;
        fields[entry.key] = _firestoreValue(entry.value);
      }

      return {
        'update': {
          'name':
              'projects/${projectId}/databases/(default)/documents/attractions/${id}',
          'fields': fields,
        },
      };
    }).toList();

    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse(
          'https://firestore.googleapis.com/v1/projects/'
          '${projectId}/databases/(default)/documents:commit',
        ),
      );

      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${accessToken}');

      request.write(jsonEncode({'writes': writes}));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Firestore commit failed (${response.statusCode}): ${body}',
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}

Future<void> main(List<String> args) async {
  final isDryRun =
      args.contains('--dry-run') || !args.contains('--import');
  final isImport = args.contains('--import');

  final pipeline = GlobalAttractionPipeline();
  pipeline.processDataset();

  if (isDryRun || !isImport) {
    pipeline.printDryRunReport();
    return;
  }

  final credentialsPath =
      Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];

  if (credentialsPath == null ||
      credentialsPath.trim().isEmpty ||
      !File(credentialsPath).existsSync()) {
    print('ERROR: Administrative credentials not found.');
    print(
      'Production import requires GOOGLE_APPLICATION_CREDENTIALS '
      'pointing to a valid service-account JSON.',
    );
    print('No changes were made to Firestore.');
    exit(1);
  }

  final importRecords = pipeline.processedAttractions
      .where(
        (a) =>
            a.id.toLowerCase() != 'charminar' &&
            !a.name.toLowerCase().contains('charminar'),
      )
      .map((a) => a.toMap())
      .toList();

  if (importRecords.length != 829) {
    print(
      'ERROR: Safety check failed. Expected exactly 829 import records, '
      'found ${importRecords.length}.',
    );
    print('No changes were made to Firestore.');
    exit(1);
  }

  print('');
  print('====================================================');
  print(' TOURMATE PRODUCTION FIRESTORE IMPORT CONFIRMATION ');
  print('====================================================');
  print('');
  print('Firebase project:                tourmate-70d03');
  print('Collection:                      attractions');
  print('New documents:                   829');
  print('Existing Charminar:              preserved');
  print('Expected final attraction count: 830');
  print('Users/favorites:                 untouched');
  print('Deletes:                         none');
  print('Batch size:                      <=400 operations');
  print('');
  print('====================================================');
  print('');
  stdout.write('Type "yes" to proceed with production import: ');

  final confirmation = stdin.readLineSync();

  if (confirmation != 'yes') {
    print('');
    print('Import cancelled.');
    print('ZERO FIRESTORE WRITES PERFORMED.');
    return;
  }

  try {
    final serviceAccount =
        jsonDecode(await File(credentialsPath).readAsString())
            as Map<String, dynamic>;

    final projectId =
        serviceAccount['project_id']?.toString() ?? 'tourmate-70d03';

    if (projectId != 'tourmate-70d03') {
      throw Exception(
        'Safety check failed: service-account project_id is "${projectId}", '
        'expected "tourmate-70d03".',
      );
    }

    print('');
    print('Authenticating with Google Cloud / Firebase Admin...');
    final firestore = FirestoreAdminClient(serviceAccount);
    await firestore._getAccessToken();
    print('Authentication successful.');
    print('');

    const batchSize = 400;
    final totalBatches = (importRecords.length / batchSize).ceil();
    var totalWritten = 0;
    var completedBatches = 0;

    for (var start = 0; start < importRecords.length; start += batchSize) {
      final end = math.min(start + batchSize, importRecords.length);
      final batch = importRecords.sublist(start, end);
      final batchNumber = completedBatches + 1;

      print(
        'Writing batch ${batchNumber} of ${totalBatches} '
        '(${batch.length} operations)...',
      );

      await firestore.writeBatch(batch);

      totalWritten += batch.length;
      completedBatches++;

      print(
        'SUCCESS (Batch ${batchNumber}: ${batch.length} documents written)',
      );
    }

    print('');
    print('====================================================');
    print(' PRODUCTION IMPORT COMPLETE');
    print('====================================================');
    print('');
    print('Records attempted:            ${importRecords.length}');
    print('Records successfully written: ${totalWritten}');
    print('Batches completed:             ${completedBatches}');
    print('Charminar preserved:           YES');
    print('Deletes performed:             0');
    print('Users/favorites modified:      0');
    print('Expected final count:          830');
    print('');
    print('====================================================');
  } catch (e, stackTrace) {
    print('');
    print('====================================================');
    print(' PRODUCTION IMPORT FAILED');
    print('====================================================');
    print('');
    print('Error: ${e}');
    print('');
    print(stackTrace);
    print('');
    print('No further batches will be attempted.');
    exit(1);
  }
}
