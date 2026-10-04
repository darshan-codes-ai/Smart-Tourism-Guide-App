import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/models/review.dart';
import 'package:tourmate/services/review_service.dart';
import 'package:tourmate/widgets/reviews_section.dart';

void main() {
  group('1. Review Model Creation & Parsing Tests', () {
    test('parses Review from Firestore Map with Timestamp', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final data = {
        'userId': 'user-123',
        'userName': 'Alice',
        'rating': 4.5,
        'comment': 'Stunning architecture and great atmosphere!',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final review = Review.fromFirestore('rev-1', data, attractionId: 'eiffel-tower');

      expect(review.id, 'rev-1');
      expect(review.attractionId, 'eiffel-tower');
      expect(review.userId, 'user-123');
      expect(review.userName, 'Alice');
      expect(review.rating, 4.5);
      expect(review.comment, 'Stunning architecture and great atmosphere!');
      expect(review.createdAt, now);
      expect(review.updatedAt, now);
    });

    test('serializes Review to Map correctly', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final review = Review(
        id: 'rev-2',
        attractionId: 'colosseum',
        userId: 'user-456',
        userName: 'Bob',
        rating: 5.0,
        comment: 'Must visit in Rome!',
        createdAt: now,
        updatedAt: now,
      );

      final map = review.toMap();
      expect(map['userId'], 'user-456');
      expect(map['userName'], 'Bob');
      expect(map['rating'], 5.0);
      expect(map['comment'], 'Must visit in Rome!');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('copyWith updates specified fields only', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final review = Review(
        id: 'rev-3',
        attractionId: 'taj-mahal',
        userId: 'user-789',
        userName: 'Charlie',
        rating: 4.0,
        comment: 'Very crowded but beautiful.',
        createdAt: now,
        updatedAt: now,
      );

      final updated = review.copyWith(
        rating: 5.0,
        comment: 'Updated: Absolutely breathtaking at sunrise!',
      );

      expect(updated.id, 'rev-3');
      expect(updated.userId, 'user-789');
      expect(updated.rating, 5.0);
      expect(updated.comment, 'Updated: Absolutely breathtaking at sunrise!');
    });
  });

  group('2. Rating & Comment Validation Tests', () {
    setUp(() {
      ReviewService.testReviews = {};
    });

    tearDown(() {
      ReviewService.resetForTest();
    });

    test('rejects rating below 1.0', () async {
      expect(
        () => ReviewService.instance.createReview(
          attractionId: 'eiffel-tower',
          userId: 'user-1',
          userName: 'Dave',
          rating: 0.5,
          comment: 'Too low',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('Rating must be between 1 and 5'),
        )),
      );
    });

    test('rejects rating above 5.0', () async {
      expect(
        () => ReviewService.instance.createReview(
          attractionId: 'eiffel-tower',
          userId: 'user-1',
          userName: 'Dave',
          rating: 6.0,
          comment: 'Too high',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('Rating must be between 1 and 5'),
        )),
      );
    });

    test('rejects empty comment', () async {
      expect(
        () => ReviewService.instance.createReview(
          attractionId: 'eiffel-tower',
          userId: 'user-1',
          userName: 'Dave',
          rating: 4.0,
          comment: '',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('Comment cannot be empty'),
        )),
      );
    });

    test('rejects whitespace-only comment', () async {
      expect(
        () => ReviewService.instance.createReview(
          attractionId: 'eiffel-tower',
          userId: 'user-1',
          userName: 'Dave',
          rating: 4.0,
          comment: '    \n\t   ',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('Comment cannot be empty'),
        )),
      );
    });

    test('trims comment leading and trailing whitespace', () async {
      final review = await ReviewService.instance.createReview(
        attractionId: 'eiffel-tower',
        userId: 'user-1',
        userName: 'Dave',
        rating: 5.0,
        comment: '   Awesome experience!   ',
      );

      expect(review.comment, 'Awesome experience!');
    });
  });

  group('3. Review CRUD & Ownership Tests', () {
    setUp(() {
      ReviewService.testReviews = {};
    });

    tearDown(() {
      ReviewService.resetForTest();
    });

    test('creates review and streams it back', () async {
      final review = await ReviewService.instance.createReview(
        attractionId: 'colosseum',
        userId: 'user-10',
        userName: 'Elena',
        rating: 4.5,
        comment: 'Ancient marvel.',
      );

      expect(review.id, isNotEmpty);
      expect(review.userId, 'user-10');
      expect(review.rating, 4.5);

      final stream = ReviewService.instance.streamReviews('colosseum');
      final list = await stream.first;
      expect(list.length, 1);
      expect(list.first.comment, 'Ancient marvel.');
    });

    test('owner can update their review', () async {
      final review = await ReviewService.instance.createReview(
        attractionId: 'taj-mahal',
        userId: 'user-11',
        userName: 'Frank',
        rating: 4.0,
        comment: 'Initial comment.',
      );

      await ReviewService.instance.updateReview(
        attractionId: 'taj-mahal',
        reviewId: review.id,
        userId: 'user-11',
        rating: 5.0,
        comment: 'Updated comment: spectacular!',
      );

      final list = await ReviewService.instance.streamReviews('taj-mahal').first;
      expect(list.first.rating, 5.0);
      expect(list.first.comment, 'Updated comment: spectacular!');
    });

    test('non-owner cannot update someone else review', () async {
      final review = await ReviewService.instance.createReview(
        attractionId: 'taj-mahal',
        userId: 'user-11',
        userName: 'Frank',
        rating: 4.0,
        comment: 'Initial comment.',
      );

      expect(
        () => ReviewService.instance.updateReview(
          attractionId: 'taj-mahal',
          reviewId: review.id,
          userId: 'attacker-user',
          rating: 1.0,
          comment: 'Malicious edit.',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('permission'),
        )),
      );
    });

    test('owner can delete review', () async {
      final review = await ReviewService.instance.createReview(
        attractionId: 'burj-khalifa',
        userId: 'user-12',
        userName: 'Grace',
        rating: 5.0,
        comment: 'Very high view!',
      );

      var list = await ReviewService.instance.streamReviews('burj-khalifa').first;
      expect(list.length, 1);

      await ReviewService.instance.deleteReview(
        attractionId: 'burj-khalifa',
        reviewId: review.id,
        userId: 'user-12',
      );

      list = await ReviewService.instance.streamReviews('burj-khalifa').first;
      expect(list.length, 0);
    });

    test('non-owner cannot delete someone else review', () async {
      final review = await ReviewService.instance.createReview(
        attractionId: 'burj-khalifa',
        userId: 'user-12',
        userName: 'Grace',
        rating: 5.0,
        comment: 'Very high view!',
      );

      expect(
        () => ReviewService.instance.deleteReview(
          attractionId: 'burj-khalifa',
          reviewId: review.id,
          userId: 'attacker-user',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('permission'),
        )),
      );
    });
  });

  group('4. Average Rating Calculation Tests', () {
    setUp(() {
      ReviewService.testReviews = {};
    });

    tearDown(() {
      ReviewService.resetForTest();
    });

    test('returns 0.0 rating and 0 count when no reviews exist', () async {
      final summary = await ReviewService.instance
          .streamRatingSummary('empty-attraction')
          .first;

      expect(summary.averageRating, 0.0);
      expect(summary.totalReviews, 0);
    });

    test('calculates accurate average rating for multiple reviews', () async {
      await ReviewService.instance.createReview(
        attractionId: 'statue-of-liberty',
        userId: 'user-1',
        userName: 'User 1',
        rating: 5.0,
        comment: 'Great!',
      );
      await ReviewService.instance.createReview(
        attractionId: 'statue-of-liberty',
        userId: 'user-2',
        userName: 'User 2',
        rating: 4.0,
        comment: 'Good!',
      );
      await ReviewService.instance.createReview(
        attractionId: 'statue-of-liberty',
        userId: 'user-3',
        userName: 'User 3',
        rating: 4.0,
        comment: 'Nice place.',
      );

      final summary = await ReviewService.instance
          .streamRatingSummary('statue-of-liberty')
          .first;

      // (5 + 4 + 4) / 3 = 4.333 -> 4.3
      expect(summary.averageRating, 4.3);
      expect(summary.totalReviews, 3);
    });
  });

  group('5. Review UI Widget States Tests', () {
    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      );
    }

    tearDown(() {
      ReviewService.resetForTest();
    });

    testWidgets('displays empty state when no reviews exist', (tester) async {
      ReviewService.testStreamReviews = (_) => Stream.value(const <Review>[]);

      await tester.pumpWidget(buildTestableWidget(
        const ReviewsSection(attractionId: 'test-attr'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(
        find.text('Be the first to review this attraction.'),
        findsOneWidget,
      );
      expect(find.text('Write a Review'), findsOneWidget);
    });

    testWidgets('displays review list when reviews exist', (tester) async {
      final reviews = [
        Review(
          id: 'rev-1',
          attractionId: 'test-attr',
          userId: 'user-1',
          userName: 'Sarah Connor',
          rating: 5.0,
          comment: 'Exceptional landmark and scenic view.',
          createdAt: DateTime(2026, 10, 4),
          updatedAt: DateTime(2026, 10, 4),
        ),
      ];

      ReviewService.testStreamReviews = (_) => Stream.value(reviews);

      await tester.pumpWidget(buildTestableWidget(
        const ReviewsSection(attractionId: 'test-attr'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('Exceptional landmark and scenic view.'), findsOneWidget);
      expect(find.text('1 review'), findsOneWidget);
      expect(find.text('5.0'), findsOneWidget);
    });

    testWidgets('unauthenticated user tapping write review shows sign in dialog', (
      tester,
    ) async {
      ReviewService.testStreamReviews = (_) => Stream.value(const <Review>[]);

      await tester.pumpWidget(buildTestableWidget(
        const ReviewsSection(attractionId: 'test-attr'),
      ));
      await tester.pumpAndSettle();

      // Tap "Write a Review" button when unauthenticated
      await tester.tap(find.text('Write a Review'));
      await tester.pumpAndSettle();

      // Verify "Sign in Required" dialog appears
      expect(find.text('Sign in Required'), findsOneWidget);
      expect(
        find.text('Please sign in to write a review and share your travel experience.'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('displays error state when review stream fails', (tester) async {
      ReviewService.testStreamReviews =
          (_) => Stream.error('Firestore connection timeout');

      await tester.pumpWidget(buildTestableWidget(
        const ReviewsSection(attractionId: 'test-attr'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load reviews'), findsOneWidget);
    });
  });
}
