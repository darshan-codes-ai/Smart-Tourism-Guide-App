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
    this.errors = const <String>[],
  });

  final int totalExamined;
  final int seededCount;
  final int skippedCount;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess =>
      seededCount > 0 || (totalExamined > 0 && skippedCount == totalExamined);

  @override
  String toString() =>
      'SeedReport(examined: $totalExamined, seeded: $seededCount, skipped: $skippedCount, errors: ${errors.length})';
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
    int batchSize = 250,
    void Function(int processed, int total)? onProgress,
  }) async {
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
      final errors = <String>[];
      final seenIds = <String>{};

      for (int i = 0; i < candidates.length; i++) {
        final attraction = candidates[i];
        final id = attraction.id.trim();

        if (id.isEmpty || seenIds.contains(id)) {
          skipped++;
          continue;
        }
        seenIds.add(id);

        if (!overwrite && existingIds.contains(id)) {
          skipped++;
          continue;
        }

        try {
          AttractionService.instance.validateAttraction(attraction);
          testWrittenAttractions!.add(attraction);
          existingIds.add(id);
          seeded++;
        } catch (e) {
          errors.add('Failed to validate "${attraction.name}" ($id): $e');
          skipped++;
        }
        onProgress?.call(i + 1, candidates.length);
      }

      return SeedReport(
        totalExamined: candidates.length,
        seededCount: seeded,
        skippedCount: skipped,
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
    final errors = <String>[];
    final validToSeed = <Attraction>[];
    final seenIds = <String>{};

    for (final attraction in candidates) {
      final id = attraction.id.trim();
      if (id.isEmpty || seenIds.contains(id)) {
        skipped++;
        continue;
      }
      seenIds.add(id);

      if (!overwrite && existingIds.contains(id)) {
        skipped++;
        continue;
      }

      try {
        AttractionService.instance.validateAttraction(attraction);
        validToSeed.add(attraction);
      } catch (e) {
        errors.add('Validation failed for "${attraction.name}" ($id): $e');
        skipped++;
      }
    }

    // 5. Batch writes in chunks complying with Firestore limits (<= 500)
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

    return SeedReport(
      totalExamined: candidates.length,
      seededCount: seeded,
      skippedCount: skipped,
      errors: errors,
    );
  }
}
