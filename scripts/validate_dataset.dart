// scripts/validate_dataset.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Validates the TourMate global attractions dataset against strict schema requirements.
///
/// Exit codes:
///   0: Validation passed successfully.
///   1: Validation failed due to critical schema violations.
void main(List<String> args) {
  final path = args.isNotEmpty
      ? args.first
      : 'assets/data/global_attractions.json';

  final file = File(path);
  if (!file.existsSync()) {
    print('ERROR: Dataset file not found at $path');
    exit(1);
  }

  print('Validating TourMate global dataset at $path...');
  final dynamic json;
  try {
    json = jsonDecode(file.readAsStringSync());
  } catch (e) {
    print('ERROR: Failed to parse JSON: $e');
    exit(1);
  }

  if (json is! List) {
    print('ERROR: Expected top-level JSON array of attractions.');
    exit(1);
  }

  final records = json;
  final seenIds = <String>{};
  final canonicalCategories = {
    'Historical',
    'Nature',
    'Religious',
    'Adventure',
    'Food',
    'Shopping',
  };

  int invalidCoordinates = 0;
  int missingFields = 0;
  int duplicateIds = 0;
  int missingImages = 0;
  int missingCities = 0;
  final byCountry = <String, int>{};
  final byCategory = <String, int>{};

  for (var i = 0; i < records.length; i++) {
    final item = records[i];
    if (item is! Map<String, dynamic>) {
      print('ERROR: Record $i is not a JSON object.');
      exit(1);
    }

    final id = item['id']?.toString().trim() ?? '';
    final name = item['name']?.toString().trim() ?? '';
    final category = item['category']?.toString().trim() ?? '';
    final country = item['country']?.toString().trim() ?? '';
    final countryCode = item['countryCode']?.toString().trim() ?? '';
    final city = item['city']?.toString().trim() ?? '';
    final imageUrl = item['imageUrl']?.toString().trim() ?? '';
    final lat = (item['latitude'] as num?)?.toDouble();
    final lng = (item['longitude'] as num?)?.toDouble();
    final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;

    // 1. Required core identifiers
    if (id.isEmpty || name.isEmpty || country.isEmpty || countryCode.isEmpty) {
      missingFields++;
      print(
        'ERROR: Record $i has missing required fields: id="$id", name="$name"',
      );
    }

    // 2. ID uniqueness
    if (seenIds.contains(id)) {
      duplicateIds++;
      print('ERROR: Duplicate attraction ID detected: "$id" at index $i');
    }
    seenIds.add(id);

    // 3. Category validation
    if (!canonicalCategories.contains(category)) {
      print('WARNING: Record "$id" has unrecognized category: "$category"');
    }
    byCategory[category] = (byCategory[category] ?? 0) + 1;
    byCountry[country] = (byCountry[country] ?? 0) + 1;

    // 4. Coordinates
    if (lat == null ||
        lng == null ||
        lat < -90.0 ||
        lat > 90.0 ||
        lng < -180.0 ||
        lng > 180.0) {
      invalidCoordinates++;
      print('ERROR: Record "$id" has invalid coordinates ($lat, $lng)');
    }

    // 5. Rating bounds
    if (rating < 0.0 || rating > 5.0) {
      print(
        'ERROR: Record "$id" has invalid rating: $rating (must be 0.0 - 5.0)',
      );
    }

    if (imageUrl.isEmpty) {
      missingImages++;
    }

    if (city.isEmpty) {
      missingCities++;
    }
  }

  print('====================================================');
  print('  DATASET VALIDATION SUMMARY                        ');
  print('====================================================');
  print('Total Records:         ${records.length}');
  print('Unique IDs:            ${seenIds.length}');
  print('Duplicate IDs:         $duplicateIds');
  print('Missing Core Fields:   $missingFields');
  print('Invalid Coordinates:   $invalidCoordinates');
  print('Distinct Countries:    ${byCountry.length}');
  print('Distinct Categories:   ${byCategory.length}');
  print('Missing Cities:        $missingCities');
  print('Missing Images:        $missingImages');
  print('----------------------------------------------------');

  if (duplicateIds > 0 || missingFields > 0 || invalidCoordinates > 0) {
    print('CRITICAL VALIDATION FAILED: Dataset contains schema violations.');
    exit(1);
  }

  print(
    'VALIDATION PASSED: All ${records.length} records meet schema specifications.',
  );
  exit(0);
}
