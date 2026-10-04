import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/review.dart';

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

  /// Set of in-flight review submissions to prevent duplicate double-posts.
  final Set<String> _inFlightSubmissions = <String>{};

  @visibleForTesting
  static void resetForTest() {
    testReviews = null;
    testStreamReviews = null;
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
    if (attractionId.trim().isEmpty) {
      return Stream.value(const <Review>[]);
    }

    if (testStreamReviews != null) {
      return testStreamReviews!(attractionId);
    }

    if (testReviews != null) {
      final list = List<Review>.from(testReviews![attractionId] ?? const <Review>[]);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(list);
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
        'rating': rating,
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
        }
        return;
      }

      final collection = _reviewsRef(cleanAttractionId);
      if (collection == null) {
        throw const ReviewServiceException('Firebase is not initialized.');
      }

      final docRef = collection.doc(cleanReviewId);
      await docRef.update({
        'rating': rating,
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
}

