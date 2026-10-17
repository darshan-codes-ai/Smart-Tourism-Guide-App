import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/review.dart';
import 'admin_service.dart';

class ReviewServiceException implements Exception {
  const ReviewServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  /// In-memory test store for unit testing without live Firebase.
  @visibleForTesting
  static Map<String, List<Review>>? testReviews;

  /// Test stream override for testing real-time review updates.
  @visibleForTesting
  static Stream<List<Review>> Function(String attractionId)? testStreamReviews;

  /// Test stream controllers per attraction for testing real-time review updates.
  @visibleForTesting
  static Map<String, StreamController<List<Review>>>? testControllers;

  /// Set of in-flight review submissions to prevent duplicate double-posts.
  final Set<String> _inFlightSubmissions = <String>{};

  @visibleForTesting
  static void resetForTest() {
    testReviews = null;
    testStreamReviews = null;
    if (testControllers != null) {
      for (final controller in testControllers!.values) {
        if (!controller.isClosed) {
          controller.close();
        }
      }
      testControllers = null;
    }
  }

  void _notifyTestStream(String attractionId) {
    final cleanId = attractionId.trim();
    if (testControllers != null && testControllers!.containsKey(cleanId)) {
      final controller = testControllers![cleanId];
      if (controller != null && !controller.isClosed) {
        final list = List<Review>.from(testReviews?[cleanId] ?? const <Review>[]);
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(list);
      }
    }
  }

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>>? _reviewsRef(String attractionId) {
    final firestore = _firestore;
    if (firestore == null) return null;
    return firestore
        .collection('attractions')
        .doc(attractionId)
        .collection('reviews');
  }

  /// Streams real-time reviews for [attractionId] sorted by most recent first.
  Stream<List<Review>> streamReviews(String attractionId) {
    final cleanAttractionId = attractionId.trim();
    if (cleanAttractionId.isEmpty) {
      return Stream.value(const <Review>[]);
    }

    if (testStreamReviews != null) {
      return testStreamReviews!(cleanAttractionId);
    }

    if (testReviews != null) {
      testControllers ??= <String, StreamController<List<Review>>>{};
      var controller = testControllers![cleanAttractionId];
      if (controller == null || controller.isClosed) {
        controller = StreamController<List<Review>>.broadcast();
        testControllers![cleanAttractionId] = controller;
      }

      final initialList = List<Review>.from(testReviews?[cleanAttractionId] ?? const <Review>[]);
      initialList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      Stream<List<Review>> generator() async* {
        yield initialList;
        yield* controller!.stream;
      }

      return generator();
    }

    final collection = _reviewsRef(attractionId);
    if (collection == null) {
      return const Stream<List<Review>>.empty();
    }

    return collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromFirestore(
          doc.id,
          doc.data(),
          attractionId: attractionId,
        );
      }).toList();
    });
  }

  /// Streams the calculated average rating and total count for [attractionId].
  Stream<({double averageRating, int totalReviews})> streamRatingSummary(
    String attractionId,
  ) {
    return streamReviews(attractionId).map((reviews) {
      if (reviews.isEmpty) {
        return (averageRating: 0.0, totalReviews: 0);
      }
      final total = reviews.length;
      final sum = reviews.fold<double>(
        0.0,
        (acc, review) => acc + review.rating,
      );
      final average = double.parse((sum / total).toStringAsFixed(1));
      return (averageRating: average, totalReviews: total);
    });
  }

  /// Calculates or retrieves aggregate rating information for [attractionId].
  Future<({double averageRating, int totalReviews})> getRatingSummary(
    String attractionId,
  ) async {
    final cleanAttractionId = attractionId.trim();
    if (cleanAttractionId.isEmpty) {
      return (averageRating: 0.0, totalReviews: 0);
    }

    if (testReviews != null) {
      final list = testReviews![cleanAttractionId] ?? const <Review>[];
      if (list.isEmpty) return (averageRating: 0.0, totalReviews: 0);
      final sum = list.fold<double>(0.0, (acc, r) => acc + r.rating);
      final avg = double.parse((sum / list.length).toStringAsFixed(1));
      return (averageRating: avg, totalReviews: list.length);
    }

    final collection = _reviewsRef(cleanAttractionId);
    if (collection == null) {
      return (averageRating: 0.0, totalReviews: 0);
    }

    try {
      final snapshot = await collection.get();
      if (snapshot.docs.isEmpty) {
        return (averageRating: 0.0, totalReviews: 0);
      }
      final reviews = snapshot.docs
          .map((doc) => Review.fromFirestore(
                doc.id,
                doc.data(),
                attractionId: cleanAttractionId,
              ))
          .toList();
      final sum = reviews.fold<double>(0.0, (acc, r) => acc + r.rating);
      final avg = double.parse((sum / reviews.length).toStringAsFixed(1));
      return (averageRating: avg, totalReviews: reviews.length);
    } catch (_) {
      return (averageRating: 0.0, totalReviews: 0);
    }
  }

  /// Retrieves the review submitted by [userId] for [attractionId], or null if none exists.
  Future<Review?> getUserReview({
    required String attractionId,
    required String userId,
  }) async {
    final cleanAttractionId = attractionId.trim();
    final cleanUserId = userId.trim();
    if (cleanAttractionId.isEmpty || cleanUserId.isEmpty) return null;

    if (testReviews != null) {
      final list = testReviews![cleanAttractionId] ?? <Review>[];
      try {
        return list.firstWhere((r) => r.userId == cleanUserId);
      } catch (_) {
        return null;
      }
    }

    final collection = _reviewsRef(cleanAttractionId);
    if (collection == null) return null;

    try {
      final query = await collection
          .where('userId', isEqualTo: cleanUserId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      final doc = query.docs.first;
      return Review.fromFirestore(
        doc.id,
        doc.data(),
        attractionId: cleanAttractionId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Submits a new review for [attractionId].
  Future<Review> createReview({
    required String attractionId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    final cleanAttractionId = attractionId.trim();
    final cleanUserId = userId.trim();
    final cleanUserName = userName.trim().isEmpty ? 'Traveler' : userName.trim();
    final cleanComment = comment.trim();

    // Validation
    if (cleanAttractionId.isEmpty) {
      throw const ReviewServiceException('Attraction ID is required.');
    }
    if (cleanUserId.isEmpty) {
      throw const ReviewServiceException('Please sign in to write a review.');
    }
    if (rating < 1.0 || rating > 5.0) {
      throw const ReviewServiceException('Rating must be between 1 and 5 stars.');
    }
    if (cleanComment.isEmpty) {
      throw const ReviewServiceException('Comment cannot be empty.');
    }
    if (cleanComment.length > 2000) {
      throw const ReviewServiceException(
        'Comment is too long (maximum 2000 characters).',
      );
    }

    // Prevent duplicate reviews from the same user for the same attraction
    final existingUserReview = await getUserReview(
      attractionId: cleanAttractionId,
      userId: cleanUserId,
    );
    if (existingUserReview != null) {
      throw const ReviewServiceException(
        'You have already reviewed this attraction. You can edit your existing review instead.',
      );
    }

    // Prevent duplicate in-flight submissions
    final submissionKey = '$cleanAttractionId:$cleanUserId';
    if (_inFlightSubmissions.contains(submissionKey)) {
      throw const ReviewServiceException(
        'A review submission is already in progress.',
      );
    }
    _inFlightSubmissions.add(submissionKey);

    try {
      final now = DateTime.now();

      if (testReviews != null) {
        final newId = 'test-review-${now.millisecondsSinceEpoch}';
        final review = Review(
          id: newId,
          attractionId: cleanAttractionId,
          userId: cleanUserId,
          userName: cleanUserName,
          rating: rating,
          comment: cleanComment,
          createdAt: now,
          updatedAt: now,
        );
        testReviews!.putIfAbsent(cleanAttractionId, () => <Review>[]).add(review);
        _notifyTestStream(cleanAttractionId);
        return review;
      }

      final collection = _reviewsRef(cleanAttractionId);
      if (collection == null) {
        throw const ReviewServiceException('Firebase is not initialized.');
      }

      final docRef = collection.doc();
      final data = {
        'userId': cleanUserId,
        'userName': cleanUserName,
        'rating': rating.round(),
        'comment': cleanComment,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      return Review(
        id: docRef.id,
        attractionId: cleanAttractionId,
        userId: cleanUserId,
        userName: cleanUserName,
        rating: rating,
        comment: cleanComment,
        createdAt: now,
        updatedAt: now,
      );
    } on FirebaseException catch (e) {
      throw ReviewServiceException(
        e.message ?? 'Failed to submit review. Please try again.',
      );
    } catch (e) {
      if (e is ReviewServiceException) rethrow;
      throw const ReviewServiceException(
        'Failed to submit review. Please try again.',
      );
    } finally {
      _inFlightSubmissions.remove(submissionKey);
    }
  }

  /// Updates an existing review owned by [userId].
  Future<void> updateReview({
    required String attractionId,
    required String reviewId,
    required String userId,
    required double rating,
    required String comment,
  }) async {
    final cleanAttractionId = attractionId.trim();
    final cleanReviewId = reviewId.trim();
    final cleanUserId = userId.trim();
    final cleanComment = comment.trim();

    // Validation
    if (cleanAttractionId.isEmpty || cleanReviewId.isEmpty) {
      throw const ReviewServiceException('Invalid review reference.');
    }
    if (cleanUserId.isEmpty) {
      throw const ReviewServiceException('Please sign in to update your review.');
    }
    if (rating < 1.0 || rating > 5.0) {
      throw const ReviewServiceException('Rating must be between 1 and 5 stars.');
    }
    if (cleanComment.isEmpty) {
      throw const ReviewServiceException('Comment cannot be empty.');
    }
    if (cleanComment.length > 2000) {
      throw const ReviewServiceException(
        'Comment is too long (maximum 2000 characters).',
      );
    }

    try {
      if (testReviews != null) {
        final list = testReviews![cleanAttractionId] ?? <Review>[];
        final index = list.indexWhere((r) => r.id == cleanReviewId);
        if (index >= 0) {
          final existing = list[index];
          if (existing.userId != cleanUserId) {
            throw const ReviewServiceException(
              'You do not have permission to edit this review.',
            );
          }
          list[index] = existing.copyWith(
            rating: rating,
            comment: cleanComment,
            updatedAt: DateTime.now(),
          );
          _notifyTestStream(cleanAttractionId);
        }
        return;
      }

      final collection = _reviewsRef(cleanAttractionId);
      if (collection == null) {
        throw const ReviewServiceException('Firebase is not initialized.');
      }

      final docRef = collection.doc(cleanReviewId);
      await docRef.update({
        'rating': rating.round(),
        'comment': cleanComment,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ReviewServiceException(
        e.message ?? 'Failed to update review. Please try again.',
      );
    } catch (e) {
      if (e is ReviewServiceException) rethrow;
      throw const ReviewServiceException(
        'Failed to update review. Please try again.',
      );
    }
  }

  /// Deletes a review owned by [userId].
  Future<void> deleteReview({
    required String attractionId,
    required String reviewId,
    required String userId,
  }) async {
    final cleanAttractionId = attractionId.trim();
    final cleanReviewId = reviewId.trim();
    final cleanUserId = userId.trim();

    if (cleanAttractionId.isEmpty || cleanReviewId.isEmpty) {
      throw const ReviewServiceException('Invalid review reference.');
    }
    if (cleanUserId.isEmpty) {
      throw const ReviewServiceException('Please sign in to delete your review.');
    }

    try {
      if (testReviews != null) {
        final list = testReviews![cleanAttractionId] ?? <Review>[];
        final index = list.indexWhere((r) => r.id == cleanReviewId);
        if (index >= 0) {
          final existing = list[index];
          if (existing.userId != cleanUserId) {
            throw const ReviewServiceException(
              'You do not have permission to delete this review.',
            );
          }
          list.removeAt(index);
          _notifyTestStream(cleanAttractionId);
        }
        return;
      }

      final collection = _reviewsRef(cleanAttractionId);
      if (collection == null) {
        throw const ReviewServiceException('Firebase is not initialized.');
      }

      await collection.doc(cleanReviewId).delete();
    } on FirebaseException catch (e) {
      throw ReviewServiceException(
        e.message ?? 'Failed to delete review. Please try again.',
      );
    } catch (e) {
      if (e is ReviewServiceException) rethrow;
      throw const ReviewServiceException(
        'Failed to delete review. Please try again.',
      );
    }
  }

  /// Returns total reviews count across all attractions.
  Future<int> getTotalReviewsCount() async {
    if (testReviews != null) {
      return testReviews!.values.fold<int>(0, (acc, list) => acc + list.length);
    }
    final firestore = _firestore;
    if (firestore == null) return 0;
    try {
      final snapshot = await firestore.collectionGroup('reviews').count().get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Retrieves recent reviews across all attractions for administrative moderation.
  Future<List<Review>> getRecentReviews({int limit = 50}) async {
    if (testReviews != null) {
      final allReviews = <Review>[];
      for (final list in testReviews!.values) {
        allReviews.addAll(list);
      }
      allReviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allReviews.take(limit).toList();
    }

    final firestore = _firestore;
    if (firestore == null) return const <Review>[];

    try {
      final query = await firestore
          .collectionGroup('reviews')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        final attractionId = doc.reference.parent.parent?.id ?? '';
        return Review.fromFirestore(
          doc.id,
          doc.data(),
          attractionId: attractionId,
        );
      }).toList();
    } catch (_) {
      return const <Review>[];
    }
  }

  /// Moderates and deletes a review as an authorized administrator.
  /// Throws [AdminAuthorizationException] if the current user is not an administrator.
  Future<void> moderateDeleteReview({
    required String attractionId,
    required String reviewId,
  }) async {
    final cleanAttractionId = attractionId.trim();
    final cleanReviewId = reviewId.trim();

    if (cleanAttractionId.isEmpty || cleanReviewId.isEmpty) {
      throw const ReviewServiceException('Invalid review reference.');
    }

    // Asserts administrative privileges (fail-closed)
    await AdminService.instance.assertAdmin();

    try {
      if (testReviews != null) {
        final list = testReviews![cleanAttractionId] ?? <Review>[];
        final index = list.indexWhere((r) => r.id == cleanReviewId);
        if (index >= 0) {
          list.removeAt(index);
          _notifyTestStream(cleanAttractionId);
        }
        return;
      }

      final collection = _reviewsRef(cleanAttractionId);
      if (collection == null) {
        throw const ReviewServiceException('Firebase is not initialized.');
      }

      await collection.doc(cleanReviewId).delete();
    } on FirebaseException catch (e) {
      throw ReviewServiceException(
        e.message ?? 'Failed to moderate review. Please check Firestore security rules.',
      );
    } catch (e) {
      if (e is ReviewServiceException) rethrow;
      if (e is AdminAuthorizationException) {
        throw ReviewServiceException(e.message);
      }
      throw const ReviewServiceException('Failed to moderate review. Please try again.');
    }
  }
}

