import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/attraction.dart';
import '../models/review.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'review_service.dart';
import 'trip_service.dart';

/// Aggregated dataset statistics for the Admin Dashboard.
class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalAttractions,
    required this.averageRating,
    required this.totalReviews,
    this.totalUsers,
    this.totalTrips,
    this.usersRestricted = false,
    this.tripsRestricted = false,
    this.topCategory = 'None',
    this.topCategoryCount = 0,
    this.topCountry = 'None',
    this.topCountryCount = 0,
    this.recentAttractions = const <Attraction>[],
    this.recentReviews = const <Review>[],
  });

  final int totalAttractions;
  final double averageRating;
  final int totalReviews;
  final int? totalUsers;
  final int? totalTrips;
  final bool usersRestricted;
  final bool tripsRestricted;
  final String topCategory;
  final int topCategoryCount;
  final String topCountry;
  final int topCountryCount;
  final List<Attraction> recentAttractions;
  final List<Review> recentReviews;
}

/// Exception thrown when an administrative action is attempted without authorization.
class AdminAuthorizationException implements Exception {
  const AdminAuthorizationException([
    this.message = 'Unauthorized: Administrator privileges required.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Service managing administrator authorization and verification.
///
/// Follows fail-closed security: any missing profile, unauthenticated state,
/// network error, or permission error resolves to non-admin (false).
class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  /// Test override for unit and widget testing.
  /// Never used in production if null.
  @visibleForTesting
  static bool? testIsAdminOverride;

  /// Optional stream controller for testing real-time admin status changes in tests.
  @visibleForTesting
  static StreamController<bool>? testAdminStreamController;

  /// Returns true if the currently authenticated user has an administrator role.
  ///
  /// Checks custom claims first on the Firebase auth token, then verifies against
  /// the user profile document in Firestore (`/users/{uid}`).
  /// Returns `false` if signed out, profile is missing, role is not 'admin', or if an error occurs.
  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    if (testIsAdminOverride != null) {
      return testIsAdminOverride!;
    }

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return false;
    }

    try {
      // 1. Check custom claim on ID token if present
      try {
        final idTokenResult = await currentUser.getIdTokenResult(forceRefresh);
        final tokenRole = idTokenResult.claims?['role']?.toString().toLowerCase().trim();
        if (tokenRole == 'admin') {
          return true;
        }
      } catch (_) {
        // Fall through to Firestore profile check if token claims check fails
      }

      // 2. Check Firestore profile document
      final profile = await FirestoreService.instance.getUserProfile(currentUser.uid);
      if (profile == null) {
        return false;
      }

      return profile.isAdmin;
    } catch (error) {
      debugPrint('AdminService: Authorization check failed safely (fail-closed): $error');
      return false;
    }
  }

  /// Verifies if a specific user by [uid] has an administrator role in Firestore.
  Future<bool> isUserAdmin(String uid) async {
    if (testIsAdminOverride != null) {
      return testIsAdminOverride!;
    }

    try {
      final profile = await FirestoreService.instance.getUserProfile(uid);
      return profile?.isAdmin ?? false;
    } catch (error) {
      debugPrint('AdminService: isUserAdmin check failed safely: $error');
      return false;
    }
  }

  /// Asserts that the current user is an authorized administrator.
  /// Throws [AdminAuthorizationException] if not authorized.
  Future<void> assertAdmin({bool forceRefresh = false}) async {
    final isAdmin = await isCurrentUserAdmin(forceRefresh: forceRefresh);
    if (!isAdmin) {
      throw const AdminAuthorizationException();
    }
  }

  /// Streams the current user's administrator status.
  /// Updates when the user logs in, logs out, or auth state changes.
  Stream<bool> watchIsCurrentUserAdmin() {
    if (testAdminStreamController != null) {
      return testAdminStreamController!.stream;
    }
    if (testIsAdminOverride != null) {
      return Stream.value(testIsAdminOverride!);
    }

    return AuthService.instance.authStateChanges.asyncMap((user) async {
      if (user == null) return false;
      return isCurrentUserAdmin();
    });
  }

  /// Calculates and aggregates reliable dashboard statistics from database sources.
  Future<AdminDashboardStats> getDashboardStats(List<Attraction> attractions) async {
    final totalAttractions = attractions.length;
    final averageRating = totalAttractions == 0
        ? 0.0
        : attractions.map((a) => a.rating).reduce((a, b) => a + b) / totalAttractions;

    final categoryCounts = <String, int>{};
    final countryCounts = <String, int>{};
    for (final a in attractions) {
      final cat = a.category.trim();
      if (cat.isNotEmpty) {
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
      final country = a.country.trim();
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }
    }

    String topCat = 'None';
    int topCatCount = 0;
    categoryCounts.forEach((cat, count) {
      if (count > topCatCount) {
        topCat = cat;
        topCatCount = count;
      }
    });

    String topCountry = 'None';
    int topCountryCount = 0;
    countryCounts.forEach((country, count) {
      if (count > topCountryCount) {
        topCountry = country;
        topCountryCount = count;
      }
    });

    // Total reviews & recent reviews
    final totalReviews = await ReviewService.instance.getTotalReviewsCount();
    final recentReviews = await ReviewService.instance.getRecentReviews(limit: 5);

    // Total users (respecting security boundaries)
    final usersCount = await FirestoreService.instance.getTotalUsersCount();
    final usersRestricted = usersCount == null;

    // Total trips (respecting security boundaries)
    final tripsCount = await TripService.instance.getTotalTripsCount();
    final tripsRestricted = tripsCount == null;

    return AdminDashboardStats(
      totalAttractions: totalAttractions,
      averageRating: double.parse(averageRating.toStringAsFixed(2)),
      totalReviews: totalReviews,
      totalUsers: usersCount,
      totalTrips: tripsCount,
      usersRestricted: usersRestricted,
      tripsRestricted: tripsRestricted,
      topCategory: topCat,
      topCategoryCount: topCatCount,
      topCountry: topCountry,
      topCountryCount: topCountryCount,
      recentAttractions: attractions.take(5).toList(),
      recentReviews: recentReviews,
    );
  }
}

