import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'firestore_service.dart';

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
}

