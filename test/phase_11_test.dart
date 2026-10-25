import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/models/review.dart';
import 'package:tourmate/screens/admin/admin_dashboard_screen.dart';
import 'package:tourmate/services/admin_service.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/review_service.dart';
import 'package:tourmate/services/seed_service.dart';

class MockAssetBundle extends CachingAssetBundle {
  MockAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (assets.containsKey(key)) {
      return assets[key]!;
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    final str = await loadString(key);
    final bytes = utf8.encode(str);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

Widget buildTestableWidget(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AdminService.testIsAdminOverride = null;
    AttractionService.testAttractions = null;
    AttractionService.testStream = null;
    ReviewService.resetForTest();
    SeedService.resetForTest();
  });

  tearDown(() {
    AdminService.testIsAdminOverride = null;
    AttractionService.testAttractions = null;
    AttractionService.testStream = null;
    ReviewService.resetForTest();
    SeedService.resetForTest();
  });

  group('Phase 11: Configuration & Platform Hardening Tests', () {
    test('.firebaserc is valid JSON and contains default project without whitespace', () {
      final file = File('.firebaserc');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final dynamic json = jsonDecode(content);

      expect(json, isA<Map<String, dynamic>>());
      final projects = json['projects'] as Map<String, dynamic>?;
      expect(projects, isNotNull);
      expect(projects!.containsKey('default'), isTrue);
      expect(projects.containsKey('default '), isFalse,
          reason: 'Must not contain trailing whitespace in project key');
      expect(projects['default'], 'tourmate-70d03');
    });

    test('ios/Runner/Info.plist contains NSLocationWhenInUseUsageDescription', () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('<key>NSLocationWhenInUseUsageDescription</key>'), isTrue);
      expect(content.contains('TourMate uses your location'), isTrue);
      expect(content.contains('<key>NSLocationAlwaysUsageDescription</key>'), isFalse,
          reason: 'Should not request background location unnecessarily');
    });

    test('android/app/src/main/AndroidManifest.xml contains HTTPS package visibility query', () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('<action android:name="android.intent.action.VIEW"'), isTrue);
      expect(content.contains('<data android:scheme="https"'), isTrue);
      expect(content.contains('android.intent.action.PROCESS_TEXT'), isTrue,
          reason: 'Existing declarations must be preserved');
    });

    test('pubspec.yaml registers global_attractions.json as asset', () {
      final file = File('pubspec.yaml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('assets:'), isTrue);
      expect(content.contains('assets/data/global_attractions.json'), isTrue);
    });

    test('.gitignore ignores test failure logs and debug files', () {
      final file = File('.gitignore');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('*.log'), isTrue);
      expect(content.contains('*failure*.txt'), isTrue);
      expect(content.contains('*-debug.txt'), isTrue);
    });
  });

  group('Phase 11: Firestore Review Moderation Rules Alignment Tests', () {
    test('ReviewService.moderateDeleteReview requires admin and deletes flagged review', () async {
      AdminService.testIsAdminOverride = true;
      ReviewService.testReviews = {
        'eiffel-tower': [
          Review(
            id: 'rev-spam-101',
            attractionId: 'eiffel-tower',
            userId: 'spammer-uid',
            userName: 'SpamBot',
            rating: 1.0,
            comment: 'Spam link: http://malicious.example.com',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      };

      await ReviewService.instance.moderateDeleteReview(
        attractionId: 'eiffel-tower',
        reviewId: 'rev-spam-101',
      );

      expect(ReviewService.testReviews!['eiffel-tower']!.isEmpty, isTrue);
    });

    test('ReviewService.moderateDeleteReview throws AdminAuthorizationException for normal user', () async {
      AdminService.testIsAdminOverride = false;
      ReviewService.testReviews = {
        'eiffel-tower': [
          Review(
            id: 'rev-valid-1',
            attractionId: 'eiffel-tower',
            userId: 'user-normal',
            userName: 'Normal Traveler',
            rating: 5.0,
            comment: 'Great trip!',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      };

      expect(
        () => ReviewService.instance.moderateDeleteReview(
          attractionId: 'eiffel-tower',
          reviewId: 'rev-valid-1',
        ),
        throwsA(isA<AdminAuthorizationException>()),
      );

      // Verify review was not deleted
      expect(ReviewService.testReviews!['eiffel-tower']!.length, 1);
    });
  });

  group('Phase 11: SeedService Safety, Parsing & Idempotency Tests', () {
    test('loadAttractionsFromAsset parses candidate attractions correctly', () async {
      final mockJson = jsonEncode([
        {
          'id': 'test-attr-1',
          'name': 'Test Taj',
          'category': 'Historical',
          'description': 'A beautiful test monument in India',
          'imageUrl': 'https://example.com/taj.jpg',
          'rating': 4.9,
          'city': 'Agra',
          'country': 'India',
          'latitude': 27.1751,
          'longitude': 78.0421,
          'entryFee': '₹50',
          'openingHours': '6:00 AM - 6:00 PM',
        },
        {
          'id': 'test-attr-2',
          'name': 'Test Colosseum',
          'category': 'Historical',
          'description': 'Ancient amphitheatre in Rome',
          'imageUrl': 'https://example.com/colosseum.jpg',
          'rating': 4.8,
          'city': 'Rome',
          'country': 'Italy',
          'latitude': 41.8902,
          'longitude': 12.4922,
          'entryFee': '€18',
          'openingHours': '8:30 AM - 7:00 PM',
        },
      ]);

      final mockBundle = MockAssetBundle({'assets/data/global_attractions.json': mockJson});
      final list = await SeedService.instance.loadAttractionsFromAsset(bundle: mockBundle);

      expect(list.length, 2);
      expect(list[0].id, 'test-attr-1');
      expect(list[0].name, 'Test Taj');
      expect(list[0].country, 'India');
      expect(list[1].id, 'test-attr-2');
      expect(list[1].name, 'Test Colosseum');
      expect(list[1].country, 'Italy');
    });

    test('seedGlobalAttractions requires admin authorization', () async {
      AdminService.testIsAdminOverride = false;

      expect(
        () => SeedService.instance.seedGlobalAttractions(),
        throwsA(isA<AdminAuthorizationException>()),
      );
    });

    test('seedGlobalAttractions skips existing documents without overwriting', () async {
      AdminService.testIsAdminOverride = true;
      SeedService.testExistingIds = {'existing-charminar'};
      SeedService.testWrittenAttractions = [];

      final candidates = [
        const Attraction(
          id: 'existing-charminar',
          name: 'Charminar New Attempt',
          category: 'Historical',
          description: 'Attempt to overwrite existing document',
          imageUrl: 'https://example.com/charminar.jpg',
          rating: 5.0,
          distance: '',
          location: 'Hyderabad, India',
          openingHours: '9:00 AM - 5:30 PM',
          entryFee: '₹25',
          latitude: 17.3616,
          longitude: 78.4747,
        ),
        const Attraction(
          id: 'new-eiffel',
          name: 'Eiffel Tower',
          category: 'Historical',
          description: 'Famous tower in Paris',
          imageUrl: 'https://example.com/eiffel.jpg',
          rating: 4.7,
          distance: '',
          location: 'Paris, France',
          openingHours: '9:00 AM - 11:45 PM',
          entryFee: '€29',
          latitude: 48.8584,
          longitude: 2.2945,
        ),
      ];

      final report = await SeedService.instance.seedGlobalAttractions(
        customAttractions: candidates,
        overwrite: false,
      );

      expect(report.totalExamined, 2);
      expect(report.seededCount, 1);
      expect(report.skippedCount, 1);
      expect(report.errors.isEmpty, isTrue);

      expect(SeedService.testWrittenAttractions!.length, 1);
      expect(SeedService.testWrittenAttractions![0].id, 'new-eiffel');
    });

    test('seedGlobalAttractions is idempotent on repeated runs', () async {
      AdminService.testIsAdminOverride = true;
      SeedService.testExistingIds = <String>{};
      SeedService.testWrittenAttractions = [];

      final candidates = [
        const Attraction(
          id: 'attr-1',
          name: 'Monument 1',
          category: 'Historical',
          description: 'Description 1',
          imageUrl: 'https://example.com/1.jpg',
          rating: 4.5,
          distance: '',
          location: 'City 1',
          openingHours: '9am - 5pm',
          entryFee: 'Free',
          latitude: 10.0,
          longitude: 10.0,
        ),
      ];

      // First run: seeds 1
      final report1 = await SeedService.instance.seedGlobalAttractions(
        customAttractions: candidates,
      );
      expect(report1.seededCount, 1);
      expect(report1.skippedCount, 0);

      // Second run: skips 1 (already exists)
      final report2 = await SeedService.instance.seedGlobalAttractions(
        customAttractions: candidates,
      );
      expect(report2.seededCount, 0);
      expect(report2.skippedCount, 1);
    });

    test('seedGlobalAttractions catches invalid candidates and logs errors', () async {
      AdminService.testIsAdminOverride = true;
      SeedService.testExistingIds = <String>{};
      SeedService.testWrittenAttractions = [];

      final candidates = [
        const Attraction(
          id: 'invalid-attr',
          name: '', // Invalid empty name
          category: 'Historical',
          description: 'Valid description',
          imageUrl: 'https://example.com/img.jpg',
          rating: 4.5,
          distance: '',
          location: 'City',
          openingHours: '9am - 5pm',
          entryFee: 'Free',
        ),
        const Attraction(
          id: 'valid-attr',
          name: 'Valid Name',
          category: 'Nature',
          description: 'Valid description',
          imageUrl: 'https://example.com/valid.jpg',
          rating: 4.0,
          distance: '',
          location: 'City',
          openingHours: '9am - 5pm',
          entryFee: 'Free',
          latitude: 20.0,
          longitude: 20.0,
        ),
      ];

      final report = await SeedService.instance.seedGlobalAttractions(
        customAttractions: candidates,
      );

      expect(report.totalExamined, 2);
      expect(report.seededCount, 1);
      expect(report.skippedCount, 1);
      expect(report.hasErrors, isTrue);
      expect(report.errors[0], contains('name cannot be empty'));
      expect(SeedService.testWrittenAttractions!.length, 1);
      expect(SeedService.testWrittenAttractions![0].id, 'valid-attr');
    });

    test('seedGlobalAttractions deduplicates duplicate IDs in candidate list', () async {
      AdminService.testIsAdminOverride = true;
      SeedService.testExistingIds = <String>{};
      SeedService.testWrittenAttractions = [];

      final candidates = [
        const Attraction(
          id: 'dup-id',
          name: 'First Occurrence',
          category: 'Nature',
          description: 'Description 1',
          imageUrl: 'https://example.com/1.jpg',
          rating: 4.0,
          distance: '',
          location: 'City',
          openingHours: '9am - 5pm',
          entryFee: 'Free',
          latitude: 10.0,
          longitude: 10.0,
        ),
        const Attraction(
          id: 'dup-id',
          name: 'Duplicate Occurrence',
          category: 'Nature',
          description: 'Description 2',
          imageUrl: 'https://example.com/2.jpg',
          rating: 4.5,
          distance: '',
          location: 'City',
          openingHours: '9am - 5pm',
          entryFee: 'Free',
          latitude: 10.0,
          longitude: 10.0,
        ),
      ];

      final report = await SeedService.instance.seedGlobalAttractions(
        customAttractions: candidates,
      );

      expect(report.totalExamined, 2);
      expect(report.seededCount, 1);
      expect(report.skippedCount, 1);
      expect(SeedService.testWrittenAttractions!.length, 1);
      expect(SeedService.testWrittenAttractions![0].name, 'First Occurrence');
    });
  });

  group('Phase 11: Admin Dashboard Seeding UI Widget Tests', () {
    testWidgets('displays Seed Database button and confirmation dialog in Admin Dashboard', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      AdminService.testIsAdminOverride = true;
      AttractionService.testAttractions = {};
      AttractionService.testStream = Stream.value(const <Attraction>[]);

      await tester.pumpWidget(buildTestableWidget(const AdminDashboardScreen()));
      await tester.pumpAndSettle();

      // Find the Seed Database button in the analytics header
      final seedButton = find.byKey(const Key('admin_seed_database_button'));
      expect(seedButton, findsOneWidget);

      // Tap Seed Database
      await tester.tap(seedButton);
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed with explanation
      expect(find.text('Seed Global Attractions'), findsOneWidget);
      expect(find.textContaining('This administrative operation populates the Firestore database'), findsOneWidget);
      expect(find.textContaining('Existing attractions will be detected and preserved'), findsOneWidget);

      // Tap Cancel
      final cancelButton = find.byKey(const Key('admin_seed_cancel_button'));
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Seed Global Attractions'), findsNothing);
    });

    testWidgets('confirming seed executes SeedService and displays result dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      AdminService.testIsAdminOverride = true;
      AttractionService.testAttractions = {};
      AttractionService.testStream = Stream.value(const <Attraction>[]);

      SeedService.testSeedReportOverride = const SeedReport(
        totalExamined: 829,
        seededCount: 828,
        skippedCount: 1,
        errors: [],
      );

      await tester.pumpWidget(buildTestableWidget(const AdminDashboardScreen()));
      await tester.pumpAndSettle();

      final seedButton = find.byKey(const Key('admin_seed_database_button'));
      await tester.tap(seedButton);
      await tester.pumpAndSettle();

      final confirmButton = find.byKey(const Key('admin_seed_confirm_button'));
      expect(confirmButton, findsOneWidget);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Result dialog appears
      expect(find.text('Seeding Complete'), findsOneWidget);
      expect(find.textContaining('Newly seeded: 828'), findsOneWidget);
      expect(find.textContaining('Skipped (already exist): 1'), findsOneWidget);

      final okButton = find.byKey(const Key('admin_seed_result_ok_button'));
      await tester.tap(okButton);
      await tester.pumpAndSettle();

      expect(find.text('Seeding Complete'), findsNothing);
    });
  });
}
