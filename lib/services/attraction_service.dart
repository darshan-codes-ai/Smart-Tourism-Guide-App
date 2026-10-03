import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../data/dummy_data.dart';
import '../models/attraction.dart';

class AttractionService {
  AttractionService._();

  static final AttractionService instance = AttractionService._();

  /// Controlled development fallback flag.
  /// When false (default), Firestore is the primary data source.
  /// Dummy data is never substituted automatically for empty or error states.
  static bool devFallbackEnabled = false;

  /// Optional test stream override for widget testing without live Firebase.
  static Stream<List<Attraction>>? testStream;

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>>? get _attractionsRef {
    final firestore = _firestore;
    if (firestore == null) return null;
    return firestore.collection('attractions');
  }

  /// Streams real-time attraction documents from `/attractions`.
  /// Converts each document using [Attraction.fromFirestore].
  /// Sorts by rating descending by default.
  Stream<List<Attraction>> watchAttractions({String? category}) {
    if (testStream != null) {
      return testStream!;
    }
    final collection = _attractionsRef;
    if (collection == null) {
      if (devFallbackEnabled) {
        final list = category == null
            ? DummyData.attractions
            : DummyData.attractions
                  .where((a) => a.category == category)
                  .toList();
        return Stream.value(list);
      }
      return Stream.error(
        StateError('Firebase is not initialized. Cannot watch attractions.'),
      );
    }

    Query<Map<String, dynamic>> query = collection;
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      final attractions = snapshot.docs
          .map((doc) => Attraction.fromFirestore(doc.id, doc.data()))
          .toList();
      attractions.sort((a, b) => b.rating.compareTo(a.rating));
      return attractions;
    });
  }

  /// Fetches a one-time list of attractions from `/attractions`.
  /// Returns an empty list when Firestore has no documents.
  Future<List<Attraction>> getAttractions({String? category}) async {
    final collection = _attractionsRef;
    if (collection == null) {
      if (devFallbackEnabled) {
        return category == null
            ? DummyData.attractions
            : DummyData.attractions
                  .where((a) => a.category == category)
                  .toList();
      }
      throw StateError(
        'Firebase is not initialized. Cannot fetch attractions.',
      );
    }

    Query<Map<String, dynamic>> query = collection;
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.get();
    final attractions = snapshot.docs
        .map((doc) => Attraction.fromFirestore(doc.id, doc.data()))
        .toList();
    attractions.sort((a, b) => b.rating.compareTo(a.rating));
    return attractions;
  }

  /// Fetches a single attraction document by [id] from `/attractions/{id}`.
  /// Returns null if the document does not exist.
  Future<Attraction?> getAttraction(String id) async {
    final collection = _attractionsRef;
    if (collection == null) {
      if (devFallbackEnabled) {
        try {
          return DummyData.attractions.firstWhere((a) => a.id == id);
        } catch (_) {
          return null;
        }
      }
      throw StateError(
        'Firebase is not initialized. Cannot fetch attraction with ID $id.',
      );
    }

    final snapshot = await collection.doc(id).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return Attraction.fromFirestore(snapshot.id, data);
  }
}
