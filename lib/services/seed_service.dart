import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/dummy_data.dart';
import '../models/attraction.dart';
import 'admin_service.dart';
import 'attraction_service.dart';

/// Detailed report summarizing the outcome of a database seeding operation.
class SeedReport {
  const SeedReport({
    required this.totalExamined,
    required this.seededCount,
    required this.skippedCount,
    this.validCount = 0,
    this.invalidCount = 0,
    this.existingCount = 0,
    this.newCount = 0,
    this.duplicateCount = 0,
    this.durationMs = 0,
    this.isDryRun = false,
    this.errors = const <String>[],
  });

  final int totalExamined;
  final int seededCount;
  final int skippedCount;
  final int validCount;
  final int invalidCount;
  final int existingCount;
  final int newCount;
  final int duplicateCount;
  final int durationMs;
  final bool isDryRun;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess =>
      seededCount > 0 ||
      (totalExamined > 0 && skippedCount == totalExamined) ||
      isDryRun;

  @override
  String toString() =>
      'SeedReport(examined: $totalExamined, seeded: $seededCount, skipped: $skippedCount, existing: $existingCount, duplicates: $duplicateCount, duration: ${durationMs}ms, dryRun: $isDryRun, errors: ${errors.length})';
}

/// Service to safely seed global attraction data into Firestore.
///
/// NOTE: This is NEVER executed automatically on app startup.
/// It provides an explicit, safe, idempotent mechanism for administrative seeding.
class SeedService {
  SeedService._();

  static final SeedService instance = SeedService._();

  /// Optional test report override for unit and widget testing.
  @visibleForTesting
  static SeedReport? testSeedReportOverride;

  /// In-memory existing IDs set for offline testing.
  @visibleForTesting
  static Set<String>? testExistingIds;

  /// In-memory sink recording written attractions for offline testing.
  @visibleForTesting
  static List<Attraction>? testWrittenAttractions;

  @visibleForTesting
  static void resetForTest() {
    testSeedReportOverride = null;
    testExistingIds = null;
    testWrittenAttractions = null;
  }

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  /// Checks if the Firestore `attractions` collection currently contains any documents.
  Future<bool> hasAttractions() async {
    if (testExistingIds != null) {
      return testExistingIds!.isNotEmpty;
    }
    final firestore = _firestore;
    if (firestore == null) return false;

    final snapshot = await firestore.collection('attractions').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Loads and parses attractions from the bundled asset catalog (`assets/data/global_attractions.json`).
  Future<List<Attraction>> loadAttractionsFromAsset({
    String assetPath = 'assets/data/global_attractions.json',
    AssetBundle? bundle,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    final jsonString = await assetBundle.loadString(assetPath);
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Expected JSON array of attractions.');
    }
    return decoded.map<Attraction>((item) {
      if (item is! Map<String, dynamic>) {
        item = Map<String, dynamic>.from(item as Map);
      }
      final id = (item['id'] ?? '').toString().trim();
      return Attraction.fromFirestore(id, item);
    }).toList();
  }

  /// Safely seeds global attractions into Firestore `/attractions`.
  ///
  /// Enforces:
  /// 1. Verified administrator authorization check (`assertAdmin`).
  /// 2. Reads existing attraction IDs and avoids overwriting existing documents (idempotent).
  /// 3. Validates each candidate attraction against constraints before writing.
  /// 4. Deduplicates records.
  /// 5. Chunks writes into batches of max [batchSize] (default 250) to respect Firestore's 500-op limit.
  /// 6. Returns a structured [SeedReport] with counts, skipped records, and any errors.
  /// 7. Never executes automatically on app startup; retries are safe.
  Future<SeedReport> seedGlobalAttractions({
    List<Attraction>? customAttractions,
    bool overwrite = false,
    bool dryRun = false,
    int batchSize = 250,
    void Function(int processed, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Enforce verified administrator authorization
    await AdminService.instance.assertAdmin();

    if (testSeedReportOverride != null) {
      return testSeedReportOverride!;
    }

    // 2. Load candidate attractions
    List<Attraction> candidates;
    if (customAttractions != null && customAttractions.isNotEmpty) {
      candidates = customAttractions;
    } else {
      try {
        candidates = await loadAttractionsFromAsset();
      } catch (e) {
        debugPrint(
          'SeedService: Could not load from asset catalog ($e), using DummyData.',
        );
        candidates = DummyData.attractions;
      }
    }

    if (candidates.isEmpty) {
      return const SeedReport(
        totalExamined: 0,
        seededCount: 0,
        skippedCount: 0,
      );
    }

    // 3. Test mode handling without live Firebase
    if (testWrittenAttractions != null) {
      final existingIds = testExistingIds ?? <String>{};
      int seeded = 0;
      int skipped = 0;
      int duplicates = 0;
      int existingCount = 0;
      int validCount = 0;
      int invalidCount = 0;
      final errors = <String>[];
      final seenIds = <String>{};

      for (int i = 0; i < candidates.length; i++) {
        final attraction = candidates[i];
        final id = attraction.id.trim();

        if (id.isEmpty || seenIds.contains(id)) {
          skipped++;
          duplicates++;
          continue;
        }
        seenIds.add(id);

        // Core protection for live Charminar document
        if (id.toLowerCase() == 'charminar' && existingIds.contains(id)) {
          skipped++;
          existingCount++;
          continue;
        }

        if (!overwrite && existingIds.contains(id)) {
          skipped++;
          existingCount++;
          continue;
        }

        try {
          AttractionService.instance.validateAttraction(attraction);
          validCount++;
          if (!dryRun) {
            testWrittenAttractions!.add(attraction);
            existingIds.add(id);
          }
          seeded++;
        } catch (e) {
          invalidCount++;
          errors.add('Failed to validate "${attraction.name}" ($id): $e');
          skipped++;
        }
        onProgress?.call(i + 1, candidates.length);
      }

      stopwatch.stop();
      return SeedReport(
        totalExamined: candidates.length,
        seededCount: dryRun ? 0 : seeded,
        skippedCount: skipped,
        validCount: validCount,
        invalidCount: invalidCount,
        existingCount: existingCount,
        newCount: validCount,
        duplicateCount: duplicates,
        durationMs: stopwatch.elapsedMilliseconds,
        isDryRun: dryRun,
        errors: errors,
      );
    }

    final firestore = _firestore;
    if (firestore == null) {
      throw StateError(
        'Firebase is not initialized. Cannot seed global attractions to Firestore.',
      );
    }

    final collection = firestore.collection('attractions');

    // 4. Query existing documents in Firestore to detect existing IDs and prevent overwriting
    final Set<String> existingIds = {};
    if (!overwrite) {
      try {
        final existingSnapshot = await collection.get();
        for (final doc in existingSnapshot.docs) {
          existingIds.add(doc.id);
        }
      } catch (e) {
        debugPrint('SeedService: Error retrieving existing document IDs: $e');
      }
    }

    int seeded = 0;
    int skipped = 0;
    int duplicates = 0;
    int existingCount = 0;
    int validCount = 0;
    int invalidCount = 0;
    final errors = <String>[];
    final validToSeed = <Attraction>[];
    final seenIds = <String>{};

    for (final attraction in candidates) {
      final id = attraction.id.trim();
      if (id.isEmpty || seenIds.contains(id)) {
        skipped++;
        duplicates++;
        continue;
      }
      seenIds.add(id);

      // Core protection for live Charminar document
      if (id.toLowerCase() == 'charminar' && existingIds.contains(id)) {
        skipped++;
        existingCount++;
        continue;
      }

      if (!overwrite && existingIds.contains(id)) {
        skipped++;
        existingCount++;
        continue;
      }

      try {
        AttractionService.instance.validateAttraction(attraction);
        validCount++;
        validToSeed.add(attraction);
      } catch (e) {
        invalidCount++;
        errors.add('Validation failed for "${attraction.name}" ($id): $e');
        skipped++;
      }
    }

    // 5. Batch writes in chunks complying with Firestore limits (<= 500)
    if (!dryRun) {
      final effectiveBatchSize = batchSize.clamp(1, 450);
      for (int i = 0; i < validToSeed.length; i += effectiveBatchSize) {
        final end = (i + effectiveBatchSize < validToSeed.length)
            ? i + effectiveBatchSize
            : validToSeed.length;
        final chunk = validToSeed.sublist(i, end);

        final batch = firestore.batch();
        for (final a in chunk) {
          final docRef = collection.doc(a.id);
          batch.set(docRef, a.toFirestore(), SetOptions(merge: !overwrite));
        }

        try {
          await batch.commit();
          seeded += chunk.length;
        } catch (e) {
          errors.add('Batch commit failed for chunk ($i to $end): $e');
        }

        onProgress?.call(seeded + skipped, candidates.length);
      }
    }

    stopwatch.stop();
    return SeedReport(
      totalExamined: candidates.length,
      seededCount: dryRun ? 0 : seeded,
      skippedCount: skipped,
      validCount: validCount,
      invalidCount: invalidCount,
      existingCount: existingCount,
      newCount: validToSeed.length,
      duplicateCount: duplicates,
      durationMs: stopwatch.elapsedMilliseconds,
      isDryRun: dryRun,
      errors: errors,
    );
  }
}
