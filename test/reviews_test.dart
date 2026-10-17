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

    test('round-trip JSON serialization with toRawMap and fromMap', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final review = Review(
        id: 'rev-json',
        attractionId: 'pyramids-giza',
        userId: 'user-json',
        userName: 'Zoe',
        rating: 5.0,
        comment: 'One of the wonders of the ancient world.',
        createdAt: now,
        updatedAt: now,
      );

      final rawMap = review.toRawMap();
      expect(rawMap['id'], 'rev-json');
      expect(rawMap['attractionId'], 'pyramids-giza');
      expect(rawMap['userId'], 'user-json');
      expect(rawMap['userName'], 'Zoe');
      expect(rawMap['rating'], 5.0);
      expect(rawMap['comment'], 'One of the wonders of the ancient world.');

      final restored = Review.fromMap('rev-json', rawMap, attractionId: 'pyramids-giza');
      expect(restored.id, 'rev-json');
      expect(restored.userId, 'user-json');
      expect(restored.userName, 'Zoe');
      expect(restored.rating, 5.0);
      expect(restored.comment, 'One of the wonders of the ancient world.');
    });

    test('parses legacy or missing userName safely with default Traveler', () {
      final data = {
        'userId': 'user-unknown',
        'rating': 4,
        'comment': 'Good place.',
        'createdAt': Timestamp.now(),
      };

      final review = Review.fromFirestore('rev-legacy', data);
      expect(review.userName, 'Traveler');
      expect(review.rating, 4.0);
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

    test('rejects comment longer than 2000 characters', () async {
      final longComment = 'a' * 2001;
      expect(
        () => ReviewService.instance.createReview(
          attractionId: 'eiffel-tower',
          userId: 'user-1',
          userName: 'Dave',
          rating: 4.0,
          comment: longComment,
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('Comment is too long'),
        )),
      );
    });

    test('rejects empty attractionId or empty userId', () async {
      expect(
        () => ReviewService.instance.createReview(
          attractionId: '',
          userId: 'user-1',
          userName: 'Dave',
          rating: 4.0,
          comment: 'Valid comment',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('Attraction ID is required'),
        )),
      );

      expect(
        () => ReviewService.instance.createReview(
          attractionId: 'eiffel-tower',
          userId: '',
          userName: 'Dave',
          rating: 4.0,
          comment: 'Valid comment',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('sign in'),
        )),
      );
    });

    test('accepts boundary ratings 1.0 and 5.0', () async {
      final minReview = await ReviewService.instance.createReview(
        attractionId: 'attr-min',
        userId: 'user-min',
        userName: 'MinUser',
        rating: 1.0,
        comment: 'Minimum rating.',
      );
      expect(minReview.rating, 1.0);

      final maxReview = await ReviewService.instance.createReview(
        attractionId: 'attr-max',
        userId: 'user-max',
        userName: 'MaxUser',
        rating: 5.0,
        comment: 'Maximum rating.',
      );
      expect(maxReview.rating, 5.0);
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

    test('prevents duplicate review from same user for same attraction', () async {
      await ReviewService.instance.createReview(
        attractionId: 'eiffel-tower',
        userId: 'user-dup',
        userName: 'Dave',
        rating: 5.0,
        comment: 'First review.',
      );

      expect(
        () => ReviewService.instance.createReview(
          attractionId: 'eiffel-tower',
          userId: 'user-dup',
          userName: 'Dave',
          rating: 4.0,
          comment: 'Second accidental review.',
        ),
        throwsA(isA<ReviewServiceException>().having(
          (e) => e.message,
          'message',
          contains('already reviewed this attraction'),
        )),
      );
    });

    test('getUserReview retrieves author review and returns null for others', () async {
      await ReviewService.instance.createReview(
        attractionId: 'louvre',
        userId: 'user-author',
        userName: 'ArtFan',
        rating: 5.0,
        comment: 'Mona Lisa is smaller than expected but incredible!',
      );

      final authorReview = await ReviewService.instance.getUserReview(
        attractionId: 'louvre',
        userId: 'user-author',
      );
      expect(authorReview, isNotNull);
      expect(authorReview!.comment, contains('Mona Lisa'));

      final nonAuthorReview = await ReviewService.instance.getUserReview(
        attractionId: 'louvre',
        userId: 'user-other',
      );
      expect(nonAuthorReview, isNull);
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

    test('getRatingSummary computes accurate average rating and count asynchronously', () async {
      await ReviewService.instance.createReview(
        attractionId: 'sagrada-familia',
        userId: 'user-a',
        userName: 'User A',
        rating: 5.0,
        comment: 'Masterpiece.',
      );
      await ReviewService.instance.createReview(
        attractionId: 'sagrada-familia',
        userId: 'user-b',
        userName: 'User B',
        rating: 3.0,
        comment: 'Under construction.',
      );

      final summary = await ReviewService.instance.getRatingSummary('sagrada-familia');
      // (5.0 + 3.0) / 2 = 4.0
      expect(summary.averageRating, 4.0);
      expect(summary.totalReviews, 2);
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

    testWidgets('authenticated user can open write review sheet and submit new review', (tester) async {
      ReviewService.testReviews = <String, List<Review>>{'attr-ui': <Review>[]};

      await tester.pumpWidget(buildTestableWidget(
        const ReviewsSection(
          attractionId: 'attr-ui',
          currentUserId: 'user-ui-1',
          currentUserName: 'Traveler Dan',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Write a Review'), findsOneWidget);
      await tester.tap(find.text('Write a Review'));
      await tester.pumpAndSettle();

      // Verify write sheet opened
      expect(find.text('Your Rating'), findsOneWidget);
      expect(find.text('Your Review'), findsOneWidget);

      // Select 4-star rating
      await tester.tap(find.byKey(const Key('write_review_star_4')));
      await tester.pumpAndSettle();
      expect(find.text('4.0 / 5.0'), findsOneWidget);

      // Enter comment
      await tester.enterText(
        find.byKey(const Key('write_review_comment_field')),
        'Fantastic guided tour and very informative.',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('write_review_submit_button')));
      await tester.pumpAndSettle();

      // Verify review submitted and displayed in UI
      expect(find.text('Fantastic guided tour and very informative.'), findsOneWidget);
      expect(find.text('Traveler Dan'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Edit Your Review'), findsOneWidget);
    });

    testWidgets('owner can open edit review sheet and save updated review', (tester) async {
      final initialReview = Review(
        id: 'rev-edit-1',
        attractionId: 'attr-edit',
        userId: 'user-owner',
        userName: 'Traveler Dan',
        rating: 3.0,
        comment: 'Initial 3-star comment.',
        createdAt: DateTime(2026, 10, 5),
        updatedAt: DateTime(2026, 10, 5),
      );
      ReviewService.testReviews = <String, List<Review>>{
        'attr-edit': <Review>[initialReview],
      };

      await tester.pumpWidget(buildTestableWidget(
        const ReviewsSection(
          attractionId: 'attr-edit',
          currentUserId: 'user-owner',
          currentUserName: 'Traveler Dan',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Initial 3-star comment.'), findsOneWidget);
      expect(find.byKey(const Key('review_card_edit_button_rev-edit-1')), findsOneWidget);

      // Tap Edit button on the card
      await tester.tap(find.byKey(const Key('review_card_edit_button_rev-edit-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Your Review'), findsWidgets);

      // Update to 5 stars
      await tester.tap(find.byKey(const Key('write_review_star_5')));
      await tester.pumpAndSettle();

      // Update comment
      await tester.enterText(
        find.byKey(const Key('write_review_comment_field')),
        'Updated comment: 5-star experience after revisit!',
      );
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.byKey(const Key('write_review_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Updated comment: 5-star experience after revisit!'), findsOneWidget);
    });

    testWidgets('owner can delete review with confirmation dialog', (tester) async {
      final reviewToDelete = Review(
        id: 'rev-del-1',
        attractionId: 'attr-del',
        userId: 'user-owner',
        userName: 'Traveler Dan',
        rating: 4.0,
        comment: 'Comment to delete.',
        createdAt: DateTime(2026, 10, 5),
        updatedAt: DateTime(2026, 10, 5),
      );
      ReviewService.testReviews = <String, List<Review>>{
        'attr-del': <Review>[reviewToDelete],
      };

      await tester.pumpWidget(buildTestableWidget(
        const ReviewsSection(
          attractionId: 'attr-del',
          currentUserId: 'user-owner',
          currentUserName: 'Traveler Dan',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Comment to delete.'), findsOneWidget);

      // Tap Delete on review card
      await tester.tap(find.byKey(const Key('review_card_delete_button_rev-del-1')));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Delete Review'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_review_button')), findsOneWidget);

      // Confirm delete
      await tester.tap(find.byKey(const Key('confirm_delete_review_button')));
      await tester.pumpAndSettle();

      // Review is gone and empty state is shown
      expect(find.text('Comment to delete.'), findsNothing);
      expect(find.text('No reviews yet.'), findsOneWidget);
    });
  });
}
