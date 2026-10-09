import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/dummy_data.dart';
import '../models/attraction.dart';

/// Exception thrown when attraction data fails validation constraints.
class AttractionValidationException implements Exception {
  const AttractionValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AttractionService {
  AttractionService._();

  static final AttractionService instance = AttractionService._();

  /// Controlled development fallback flag.
  /// When false (default), Firestore is the primary data source.
  /// Dummy data is never substituted automatically for empty or error states.
  static bool devFallbackEnabled = false;

  /// Optional test stream override for widget testing without live Firebase.
  static Stream<List<Attraction>>? testStream;

  /// Optional mock resolver for testing getAttraction.
  static Future<Attraction?> Function(String id)? testGetAttraction;

  /// In-memory attraction map for testing CRUD operations without live Firebase.
  @visibleForTesting
  static Map<String, Attraction>? testAttractions;

  /// Stream controller for testing real-time attraction updates.
  @visibleForTesting
  static StreamController<List<Attraction>>? testAttractionsStreamController;

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
  Stream<List<Attraction>> watchAttractions({
    String? category,
    String? country,
    int? limit,
  }) {
    if (testStream != null) {
      return testStream!;
    }
    if (testAttractionsStreamController != null) {
      return testAttractionsStreamController!.stream;
    }
    if (testAttractions != null) {
      var list = testAttractions!.values.toList();
      if (category != null && category.isNotEmpty) {
        list = list.where((a) => a.category == category).toList();
      }
      if (country != null && country.isNotEmpty) {
        list = list.where((a) => a.country == country).toList();
      }
      list.sort((a, b) => b.rating.compareTo(a.rating));
      if (limit != null && limit > 0) {
        list = list.take(limit).toList();
      }
      return Stream.value(list);
    }
    final collection = _attractionsRef;
    if (collection == null) {
      if (devFallbackEnabled) {
        var list = DummyData.attractions;
        if (category != null && category.isNotEmpty) {
          list = list.where((a) => a.category == category).toList();
        }
        if (country != null && country.isNotEmpty) {
          list = list.where((a) => a.country == country).toList();
        }
        if (limit != null && limit > 0) {
          list = list.take(limit).toList();
        }
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
    if (country != null && country.isNotEmpty) {
      query = query.where('country', isEqualTo: country);
    }
    query = query.orderBy('rating', descending: true);
    if (limit != null && limit > 0) {
      query = query.limit(limit);
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
  Future<List<Attraction>> getAttractions({
    String? category,
    String? country,
    int? limit,
  }) async {
    if (testAttractions != null) {
      var list = testAttractions!.values.toList();
      if (category != null && category.isNotEmpty) {
        list = list.where((a) => a.category == category).toList();
      }
      if (country != null && country.isNotEmpty) {
        list = list.where((a) => a.country == country).toList();
      }
      list.sort((a, b) => b.rating.compareTo(a.rating));
      if (limit != null && limit > 0) {
        list = list.take(limit).toList();
      }
      return list;
    }

    final collection = _attractionsRef;
    if (collection == null) {
      if (devFallbackEnabled) {
        var list = DummyData.attractions;
        if (category != null && category.isNotEmpty) {
          list = list.where((a) => a.category == category).toList();
        }
        if (country != null && country.isNotEmpty) {
          list = list.where((a) => a.country == country).toList();
        }
        if (limit != null && limit > 0) {
          list = list.take(limit).toList();
        }
        return list;
      }
      throw StateError(
        'Firebase is not initialized. Cannot fetch attractions.',
      );
    }

    Query<Map<String, dynamic>> query = collection;
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (country != null && country.isNotEmpty) {
      query = query.where('country', isEqualTo: country);
    }
    query = query.orderBy('rating', descending: true);
    if (limit != null && limit > 0) {
      query = query.limit(limit);
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
    if (testGetAttraction != null) {
      return testGetAttraction!(id);
    }
    if (testAttractions != null) {
      return testAttractions![id];
    }
    final collection = _attractionsRef;
    if (collection == null) {
      if (devFallbackEnabled) {
        try {
          return DummyData.attractions.firstWhere(
            (a) =>
                a.id == id ||
                (id.toLowerCase() == 'charminar' &&
                    a.id.toLowerCase() == 'charminar'),
          );
        } catch (_) {
          return null;
        }
      }
      throw StateError(
        'Firebase is not initialized. Cannot fetch attraction with ID $id.',
      );
    }

    var snapshot = await collection.doc(id).get();
    var data = snapshot.data();
    if ((!snapshot.exists || data == null) && id.toLowerCase() == 'charminar') {
      snapshot = await collection.doc('Charminar').get();
      data = snapshot.data();
    }
    if (!snapshot.exists || data == null) {
      return null;
    }
    return Attraction.fromFirestore(snapshot.id, data);
  }

  /// Validates that an attraction conforms to required schema and constraints.
  void validateAttraction(Attraction attraction) {
    if (attraction.name.trim().isEmpty) {
      throw const AttractionValidationException('Attraction name cannot be empty.');
    }
    if (attraction.category.trim().isEmpty) {
      throw const AttractionValidationException('Category cannot be empty.');
    }
    if (attraction.description.trim().isEmpty) {
      throw const AttractionValidationException('Description cannot be empty.');
    }
    if (attraction.rating < 0.0 || attraction.rating > 5.0) {
      throw const AttractionValidationException('Rating must be between 0.0 and 5.0.');
    }
    if (attraction.latitude != null &&
        (attraction.latitude! < -90.0 || attraction.latitude! > 90.0)) {
      throw const AttractionValidationException('Latitude must be between -90.0 and 90.0.');
    }
    if (attraction.longitude != null &&
        (attraction.longitude! < -180.0 || attraction.longitude! > 180.0)) {
      throw const AttractionValidationException('Longitude must be between -180.0 and 180.0.');
    }
    if (attraction.imageUrl.trim().isEmpty) {
      throw const AttractionValidationException('Image URL cannot be empty.');
    }
    final uri = Uri.tryParse(attraction.imageUrl.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const AttractionValidationException('Image URL must be a valid HTTP or HTTPS URL.');
    }
  }

  /// Generates a clean deterministic ID from an attraction name.
  static String generateId(String name) {
    final cleaned = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    return cleaned.isNotEmpty ? cleaned : 'attraction-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Creates a new attraction document in `/attractions/{id}`.
  /// Validates all fields and prevents overwriting existing IDs.
  Future<Attraction> createAttraction(Attraction attraction) async {
    validateAttraction(attraction);

    final id = attraction.id.trim().isNotEmpty
        ? attraction.id.trim()
        : generateId(attraction.name);

    final toCreate = attraction.id == id ? attraction : attraction.copyWith(id: id);

    if (testAttractions != null) {
      if (testAttractions!.containsKey(id)) {
        throw AttractionValidationException('An attraction with ID "$id" already exists.');
      }
      testAttractions![id] = toCreate;
      if (testAttractionsStreamController != null && !testAttractionsStreamController!.isClosed) {
        testAttractionsStreamController!.add(testAttractions!.values.toList());
      }
      return toCreate;
    }

    final collection = _attractionsRef;
    if (collection == null) {
      throw StateError('Firebase is not initialized. Cannot create attraction.');
    }

    final existingDoc = await collection.doc(id).get();
    if (existingDoc.exists) {
      throw AttractionValidationException('An attraction with ID "$id" already exists.');
    }

    await collection.doc(id).set(toCreate.toFirestore());
    return toCreate;
  }

  /// Updates an existing attraction document in `/attractions/{id}`.
  /// Throws [AttractionValidationException] if the attraction doesn't exist or is invalid.
  Future<Attraction> updateAttraction(Attraction attraction) async {
    final id = attraction.id.trim();
    if (id.isEmpty) {
      throw const AttractionValidationException('Cannot update attraction without an ID.');
    }
    validateAttraction(attraction);

    if (testAttractions != null) {
      if (!testAttractions!.containsKey(id)) {
        throw AttractionValidationException('Attraction with ID "$id" not found.');
      }
      testAttractions![id] = attraction;
      if (testAttractionsStreamController != null && !testAttractionsStreamController!.isClosed) {
        testAttractionsStreamController!.add(testAttractions!.values.toList());
      }
      return attraction;
    }

    final collection = _attractionsRef;
    if (collection == null) {
      throw StateError('Firebase is not initialized. Cannot update attraction.');
    }

    final existingDoc = await collection.doc(id).get();
    if (!existingDoc.exists) {
      throw AttractionValidationException('Attraction with ID "$id" not found.');
    }

    await collection.doc(id).update(attraction.toFirestore());
    return attraction;
  }

  /// Deletes an attraction document by [id] from `/attractions/{id}`.
  /// Throws [AttractionValidationException] if the attraction does not exist.
  Future<void> deleteAttraction(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      throw const AttractionValidationException('Attraction ID cannot be empty.');
    }

    if (testAttractions != null) {
      if (!testAttractions!.containsKey(trimmedId)) {
        throw AttractionValidationException('Attraction with ID "$trimmedId" not found.');
      }
      testAttractions!.remove(trimmedId);
      if (testAttractionsStreamController != null && !testAttractionsStreamController!.isClosed) {
        testAttractionsStreamController!.add(testAttractions!.values.toList());
      }
      return;
    }

    final collection = _attractionsRef;
    if (collection == null) {
      throw StateError('Firebase is not initialized. Cannot delete attraction.');
    }

    final existingDoc = await collection.doc(trimmedId).get();
    if (!existingDoc.exists) {
      throw AttractionValidationException('Attraction with ID "$trimmedId" not found.');
    }

    await collection.doc(trimmedId).delete();
  }

  /// Fetches a paginated page of attractions with optional filters.
  Future<List<Attraction>> getAttractionsPage({
    String? category,
    String? country,
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
  }) async {
    final collection = _attractionsRef;
    if (collection == null) {
      if (devFallbackEnabled) {
        var list = DummyData.attractions;
        if (category != null && category.isNotEmpty) {
          list = list.where((a) => a.category == category).toList();
        }
        if (country != null && country.isNotEmpty) {
          list = list.where((a) => a.country == country).toList();
        }
        if (limit > 0) {
          list = list.take(limit).toList();
        }
        return list;
      }
      throw StateError(
        'Firebase is not initialized. Cannot fetch attractions page.',
      );
    }

    Query<Map<String, dynamic>> query = collection;
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (country != null && country.isNotEmpty) {
      query = query.where('country', isEqualTo: country);
    }
    query = query.orderBy('rating', descending: true);
    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }
    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Attraction.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
