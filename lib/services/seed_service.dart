import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/dummy_data.dart';
import '../models/attraction.dart';

/// Service to safely seed global attraction data into Firestore.
///
/// NOTE: This is NEVER executed automatically on app startup.
/// It provides an explicit, safe mechanism for administrative or developer seeding.
class SeedService {
  SeedService._();

  static final SeedService instance = SeedService._();

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  /// Checks if the Firestore `attractions` collection currently contains any documents.
  Future<bool> hasAttractions() async {
    final firestore = _firestore;
    if (firestore == null) return false;

    final snapshot = await firestore.collection('attractions').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Seeds global attractions from [DummyData.attractions] into Firestore `/attractions`.
  ///
  /// Uses a Firestore batch operation for atomic, safe insertion.
  /// If [overwrite] is false, existing documents will be merged rather than replaced.
  /// Returns the number of seeded attraction documents.
  Future<int> seedGlobalAttractions({
    List<Attraction>? customAttractions,
    bool overwrite = true,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError(
        'Firebase is not initialized. Cannot seed global attractions to Firestore.',
      );
    }

    final attractionsToSeed = customAttractions ?? DummyData.attractions;
    if (attractionsToSeed.isEmpty) return 0;

    final collection = firestore.collection('attractions');
    final batch = firestore.batch();

    for (final attraction in attractionsToSeed) {
      final docRef = collection.doc(attraction.id);
      batch.set(
        docRef,
        attraction.toFirestore(),
        SetOptions(merge: !overwrite),
      );
    }

    await batch.commit();
    debugPrint(
      'Successfully seeded ${attractionsToSeed.length} global attractions to Firestore.',
    );
    return attractionsToSeed.length;
  }
}

