import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  /// Optional in-memory test favorites store for unit testing without live Firebase.
  @visibleForTesting
  static Map<String, Set<String>>? testFavorites;

  /// Optional in-memory test users store for unit testing without live Firebase.
  @visibleForTesting
  static Map<String, AppUser>? testUsers;

  /// Optional stream controller for testing real-time favorite updates.
  @visibleForTesting
  static StreamController<Set<String>>? testFavoritesController;

  /// Optional stream generator override for testing watchFavoriteIds.
  @visibleForTesting
  static Stream<Set<String>> Function(String uid)? testWatchFavoriteIds;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? get _users {
    if (Firebase.apps.isEmpty) return null;
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>>? _favoritesRef(String uid) {
    final users = _users;
    if (users == null) return null;
    return users.doc(uid).collection('favorites');
  }

  Future<void> createUserProfile(AppUser user) async {
    if (testUsers != null) {
      final existing = testUsers![user.uid];
      if (existing != null) {
        testUsers![user.uid] = user.copyWith(role: existing.role);
      } else {
        testUsers![user.uid] = user;
      }
      return;
    }
    final users = _users;
    if (users == null) return;
    final userRef = users.doc(user.uid);
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      final existingData = snapshot.data();
      final existingRole = existingData?['role'] as String?;
      final mergedUser = (existingRole != null && existingRole.isNotEmpty)
          ? user.copyWith(role: existingRole)
          : user;
      await _updateUserProfileDocument(userRef, mergedUser);
      return;
    }

    await userRef.set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureUserProfile(AppUser user) async {
    if (testUsers != null) {
      final existing = testUsers![user.uid];
      if (existing != null) {
        testUsers![user.uid] = user.copyWith(role: existing.role);
      } else {
        testUsers![user.uid] = user;
      }
      return;
    }
    final users = _users;
    if (users == null) return;
    final userRef = users.doc(user.uid);
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      final existingData = snapshot.data();
      final existingRole = existingData?['role'] as String?;
      final mergedUser = (existingRole != null && existingRole.isNotEmpty)
          ? user.copyWith(role: existingRole)
          : user;
      await _updateUserProfileDocument(userRef, mergedUser);
      return;
    }

    await createUserProfile(user);
  }

  Future<AppUser?> getUserProfile(String uid) async {
    if (testUsers != null) {
      return testUsers![uid];
    }
    final users = _users;
    if (users == null) return null;
    final snapshot = await users.doc(uid).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return AppUser.fromMap(data);
  }

  Stream<AppUser?> watchUserProfile(String uid) {
    if (testUsers != null) {
      return Stream.value(testUsers![uid]);
    }
    final users = _users;
    if (users == null) return const Stream<AppUser?>.empty();
    return users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return AppUser.fromMap(data);
    });
  }

  Future<void> updateUserProfile(AppUser user) async {
    if (testUsers != null) {
      testUsers![user.uid] = user;
      return;
    }
    final users = _users;
    if (users == null) return;
    await _updateUserProfileDocument(users.doc(user.uid), user);
  }

  Future<void> _updateUserProfileDocument(
    DocumentReference<Map<String, dynamic>> userRef,
    AppUser user,
  ) {
    return userRef.set({
      ...user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Streams the set of attraction IDs saved by the user with [uid].
  Stream<Set<String>> watchFavoriteIds(String uid) {
    if (testWatchFavoriteIds != null) {
      return testWatchFavoriteIds!(uid);
    }
    if (testFavoritesController != null) {
      return testFavoritesController!.stream;
    }
    if (testFavorites != null) {
      return Stream.value(
        Set<String>.from(testFavorites![uid] ?? const <String>{}),
      );
    }

    final favorites = _favoritesRef(uid);
    if (favorites == null) {
      return const Stream<Set<String>>.empty();
    }

    return favorites.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  /// Adds an attraction to the user's favorites subcollection.
  Future<void> addFavorite(String uid, String attractionId) async {
    if (testFavorites != null) {
      testFavorites!.putIfAbsent(uid, () => <String>{}).add(attractionId);
      return;
    }

    final favorites = _favoritesRef(uid);
    if (favorites == null) return;

    await favorites.doc(attractionId).set({
      'attractionId': attractionId,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes an attraction from the user's favorites subcollection.
  Future<void> removeFavorite(String uid, String attractionId) async {
    if (testFavorites != null) {
      testFavorites![uid]?.remove(attractionId);
      return;
    }

    final favorites = _favoritesRef(uid);
    if (favorites == null) return;

    await favorites.doc(attractionId).delete();
  }

  /// Checks if an attraction is favorited by the user with [uid].
  Future<bool> isFavorite(String uid, String attractionId) async {
    if (testFavorites != null) {
      return testFavorites![uid]?.contains(attractionId) ?? false;
    }

    final favorites = _favoritesRef(uid);
    if (favorites == null) return false;

    final doc = await favorites.doc(attractionId).get();
    return doc.exists;
  }
}
