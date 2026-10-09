import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/trip.dart';
import 'auth_service.dart';

class TripServiceException implements Exception {
  const TripServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Service handling user trip and itinerary lifecycle.
class TripService {
  TripService._();

  static final TripService instance = TripService._();

  /// In-memory test store for unit testing without live Firebase.
  /// Maps `userId` -> List of [Trip]s.
  @visibleForTesting
  static Map<String, List<Trip>>? testTrips;

  /// Test stream override for testing real-time trip streams.
  @visibleForTesting
  static Stream<List<Trip>> Function(String userId)? testStreamTrips;

  /// Test user ID override when testing unauthenticated/authenticated states.
  @visibleForTesting
  static String? testCurrentUserId;

  @visibleForTesting
  static void resetForTest() {
    testTrips = null;
    testStreamTrips = null;
    testCurrentUserId = null;
  }

  /// Returns a synchronous trip snapshot when one is available.
  ///
  /// The in-memory store is used by tests; production Firestore data is
  /// asynchronous and therefore returns null here.
  List<Trip>? get synchronousTripsSnapshot {
    final store = testTrips;
    if (store == null) return null;
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return const <Trip>[];
    final trips = List<Trip>.from(store[uid] ?? const <Trip>[]);
    trips.sort((a, b) => a.startDate.compareTo(b.startDate));
    return trips;
  }

  /// Returns the current authenticated user's ID or test override.
  String? get currentUserId {
    if (testCurrentUserId != null) return testCurrentUserId;
    return AuthService.instance.currentUser?.uid;
  }

  /// Returns whether a user session is active (or test user active).
  bool get isAuthenticated => currentUserId != null && currentUserId!.isNotEmpty;

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>>? _tripsRef(String uid) {
    final firestore = _firestore;
    if (firestore == null) return null;
    return firestore.collection('users').doc(uid).collection('trips');
  }

  /// Streams the authenticated user's trips in real time.
  Stream<List<Trip>> streamTrips() {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      return Stream.value(const <Trip>[]);
    }

    if (testStreamTrips != null) {
      return testStreamTrips!(uid);
    }

    if (testTrips != null) {
      final list = List<Trip>.from(testTrips![uid] ?? const <Trip>[]);
      list.sort((a, b) => a.startDate.compareTo(b.startDate));
      return Stream.value(list);
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      return const Stream<List<Trip>>.empty();
    }

    return collection
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Trip.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  /// Fetches a single trip by [tripId] for the current user.
  Future<Trip?> getTrip(String tripId) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw const TripServiceException('You must be signed in to view trips.');
    }

    if (testTrips != null) {
      final userTrips = testTrips![uid] ?? <Trip>[];
      final index = userTrips.indexWhere((t) => t.id == tripId);
      return index >= 0 ? userTrips[index] : null;
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      throw const TripServiceException('Firebase is not initialized.');
    }

    try {
      final doc = await collection.doc(tripId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Trip.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      if (e is TripServiceException) rethrow;
      throw TripServiceException('Failed to fetch trip: $e');
    }
  }

  /// Creates a new trip for the current user.
  Future<Trip> createTrip({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? attractionIds,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw const TripServiceException('You must be signed in to create a trip.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const TripServiceException('Trip name cannot be empty.');
    }
    if (trimmedName.length > 100) {
      throw const TripServiceException('Trip name cannot exceed 100 characters.');
    }

    final trimmedDestination = destination.trim();
    if (trimmedDestination.isEmpty) {
      throw const TripServiceException('Destination cannot be empty.');
    }
    if (trimmedDestination.length > 100) {
      throw const TripServiceException('Destination cannot exceed 100 characters.');
    }

    if (endDate.isBefore(startDate)) {
      throw const TripServiceException('End date cannot be before start date.');
    }

    final initialAttractions = attractionIds ?? const <String>[];
    final now = DateTime.now();

    if (testTrips != null) {
      final newId = 'trip_${DateTime.now().millisecondsSinceEpoch}_${(testTrips![uid]?.length ?? 0) + 1}';
      final newTrip = Trip(
        id: newId,
        userId: uid,
        name: trimmedName,
        destination: trimmedDestination,
        startDate: startDate,
        endDate: endDate,
        attractionIds: initialAttractions,
        createdAt: now,
        updatedAt: now,
      );
      testTrips!.putIfAbsent(uid, () => <Trip>[]).add(newTrip);
      return newTrip;
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      throw const TripServiceException('Firebase is not initialized.');
    }

    try {
      final docRef = collection.doc();
      final trip = Trip(
        id: docRef.id,
        userId: uid,
        name: trimmedName,
        destination: trimmedDestination,
        startDate: startDate,
        endDate: endDate,
        attractionIds: initialAttractions,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(trip.toMap());
      return trip;
    } catch (e) {
      if (e is TripServiceException) rethrow;
      throw TripServiceException('Failed to create trip: $e');
    }
  }

  /// Updates an existing trip's details.
  Future<void> updateTrip({
    required String tripId,
    String? name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? attractionIds,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw const TripServiceException('You must be signed in to update a trip.');
    }

    if (name != null) {
      if (name.trim().isEmpty) {
        throw const TripServiceException('Trip name cannot be empty.');
      }
      if (name.trim().length > 100) {
        throw const TripServiceException('Trip name cannot exceed 100 characters.');
      }
    }

    if (destination != null) {
      if (destination.trim().isEmpty) {
        throw const TripServiceException('Destination cannot be empty.');
      }
      if (destination.trim().length > 100) {
        throw const TripServiceException('Destination cannot exceed 100 characters.');
      }
    }

    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw const TripServiceException('End date cannot be before start date.');
    }

    if (testTrips != null) {
      final userTrips = testTrips![uid] ?? <Trip>[];
      final index = userTrips.indexWhere((t) => t.id == tripId);
      if (index < 0) {
        throw const TripServiceException('Trip not found.');
      }
      final existing = userTrips[index];
      final newStart = startDate ?? existing.startDate;
      final newEnd = endDate ?? existing.endDate;
      if (newEnd.isBefore(newStart)) {
        throw const TripServiceException('End date cannot be before start date.');
      }

      userTrips[index] = existing.copyWith(
        name: name?.trim(),
        destination: destination?.trim(),
        startDate: newStart,
        endDate: newEnd,
        attractionIds: attractionIds,
        updatedAt: DateTime.now(),
      );
      return;
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      throw const TripServiceException('Firebase is not initialized.');
    }

    try {
      final docRef = collection.doc(tripId);
      final snapshot = await docRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        throw const TripServiceException('Trip not found.');
      }

      final existingData = snapshot.data()!;
      final existingTrip = Trip.fromFirestore(tripId, existingData);
      final newStart = startDate ?? existingTrip.startDate;
      final newEnd = endDate ?? existingTrip.endDate;
      if (newEnd.isBefore(newStart)) {
        throw const TripServiceException('End date cannot be before start date.');
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) updates['name'] = name.trim();
      if (destination != null) updates['destination'] = destination.trim();
      if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
      if (attractionIds != null) updates['attractionIds'] = attractionIds;

      await docRef.update(updates);
    } catch (e) {
      if (e is TripServiceException) rethrow;
      throw TripServiceException('Failed to update trip: $e');
    }
  }

  /// Deletes a trip.
  Future<void> deleteTrip(String tripId) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw const TripServiceException('You must be signed in to delete trips.');
    }

    if (testTrips != null) {
      final userTrips = testTrips![uid] ?? <Trip>[];
      final index = userTrips.indexWhere((t) => t.id == tripId);
      if (index >= 0) {
        userTrips.removeAt(index);
      }
      return;
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      throw const TripServiceException('Firebase is not initialized.');
    }

    try {
      await collection.doc(tripId).delete();
    } catch (e) {
      if (e is TripServiceException) rethrow;
      throw TripServiceException('Failed to delete trip: $e');
    }
  }

  /// Adds an attraction to the trip, preventing duplicate additions.
  Future<void> addAttractionToTrip({
    required String tripId,
    required String attractionId,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw const TripServiceException('You must be signed in to modify a trip.');
    }

    final cleanAttractionId = attractionId.trim();
    if (cleanAttractionId.isEmpty) {
      throw const TripServiceException('Invalid attraction ID.');
    }

    if (testTrips != null) {
      final userTrips = testTrips![uid] ?? <Trip>[];
      final index = userTrips.indexWhere((t) => t.id == tripId);
      if (index < 0) {
        throw const TripServiceException('Trip not found.');
      }
      final trip = userTrips[index];
      if (trip.attractionIds.contains(cleanAttractionId)) {
        throw const TripServiceException('Already added to this trip.');
      }
      final updatedList = List<String>.from(trip.attractionIds)..add(cleanAttractionId);
      userTrips[index] = trip.copyWith(
        attractionIds: updatedList,
        updatedAt: DateTime.now(),
      );
      return;
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      throw const TripServiceException('Firebase is not initialized.');
    }

    try {
      final docRef = collection.doc(tripId);
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) {
        throw const TripServiceException('Trip not found.');
      }

      final trip = Trip.fromFirestore(tripId, doc.data());
      if (trip.attractionIds.contains(cleanAttractionId)) {
        throw const TripServiceException('Already added to this trip.');
      }

      await docRef.update({
        'attractionIds': FieldValue.arrayUnion([cleanAttractionId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e is TripServiceException) rethrow;
      throw TripServiceException('Failed to add attraction to trip: $e');
    }
  }

  /// Removes an attraction from the trip.
  Future<void> removeAttractionFromTrip({
    required String tripId,
    required String attractionId,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw const TripServiceException('You must be signed in to modify a trip.');
    }

    final cleanAttractionId = attractionId.trim();

    if (testTrips != null) {
      final userTrips = testTrips![uid] ?? <Trip>[];
      final index = userTrips.indexWhere((t) => t.id == tripId);
      if (index < 0) {
        throw const TripServiceException('Trip not found.');
      }
      final trip = userTrips[index];
      final updatedList = List<String>.from(trip.attractionIds)..remove(cleanAttractionId);
      userTrips[index] = trip.copyWith(
        attractionIds: updatedList,
        updatedAt: DateTime.now(),
      );
      return;
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      throw const TripServiceException('Firebase is not initialized.');
    }

    try {
      final docRef = collection.doc(tripId);
      await docRef.update({
        'attractionIds': FieldValue.arrayRemove([cleanAttractionId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e is TripServiceException) rethrow;
      throw TripServiceException('Failed to remove attraction from trip: $e');
    }
  }

  /// Persists a new attraction order for the trip itinerary.
  Future<void> reorderAttractions({
    required String tripId,
    required List<String> newOrder,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw const TripServiceException('You must be signed in to modify a trip.');
    }

    if (testTrips != null) {
      final userTrips = testTrips![uid] ?? <Trip>[];
      final index = userTrips.indexWhere((t) => t.id == tripId);
      if (index < 0) {
        throw const TripServiceException('Trip not found.');
      }
      final trip = userTrips[index];
      userTrips[index] = trip.copyWith(
        attractionIds: List<String>.from(newOrder),
        updatedAt: DateTime.now(),
      );
      return;
    }

    final collection = _tripsRef(uid);
    if (collection == null) {
      throw const TripServiceException('Firebase is not initialized.');
    }

    try {
      final docRef = collection.doc(tripId);
      await docRef.update({
        'attractionIds': newOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e is TripServiceException) rethrow;
      throw TripServiceException('Failed to reorder attractions: $e');
    }
  }
}
