import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/models/app_user.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/screens/admin/admin_dashboard_screen.dart';
import 'package:tourmate/screens/admin/attraction_form_dialog.dart';
import 'package:tourmate/screens/main/profile_screen.dart';
import 'package:tourmate/services/admin_service.dart';
import 'package:tourmate/services/attraction_service.dart';
import 'package:tourmate/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final sampleAttraction1 = Attraction(
    id: 'eiffel-tower',
    name: 'Eiffel Tower',
    category: 'Monument',
    city: 'Paris',
    country: 'France',
    location: 'Champ de Mars, 5 Av. Anatole France',
    description: 'Iconic iron lattice tower in Paris.',
    imageUrl: 'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f',
    rating: 4.8,
    reviewCount: 12500,
    openingHours: '09:00 - 23:45',
    distance: '2.5 km',
    entryFee: '€26.0',
    latitude: 48.8584,
    longitude: 2.2945,
  );

  final sampleAttraction2 = Attraction(
    id: 'colosseum',
    name: 'Colosseum',
    category: 'Historical',
    city: 'Rome',
    country: 'Italy',
    location: 'Piazza del Colosseo, 1',
    description: 'Ancient Roman amphitheatre in central Rome.',
    imageUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5',
    rating: 4.7,
    reviewCount: 8900,
    openingHours: '08:30 - 19:00',
    distance: '1.2 km',
    entryFee: '€16.0',
    latitude: 41.8902,
    longitude: 12.4922,
  );

  setUp(() {
    AdminService.testIsAdminOverride = null;
    AdminService.testAdminStreamController = null;
    FirestoreService.testUsers = null;
    AttractionService.testAttractions = null;
    AttractionService.testStream = null;
    AttractionService.testAttractionsStreamController = null;
  });

  tearDown(() {
    AdminService.testIsAdminOverride = null;
    AdminService.testAdminStreamController?.close();
    AdminService.testAdminStreamController = null;
    FirestoreService.testUsers = null;
    AttractionService.testAttractions = null;
    AttractionService.testStream = null;
    AttractionService.testAttractionsStreamController?.close();
    AttractionService.testAttractionsStreamController = null;
  });

  group('1. Admin Authorization & Profile Tests', () {
    test('AppUser role and isAdmin getter', () {
      const normalUser = AppUser(
        uid: 'user_1',
        provider: 'password',
        role: 'user',
      );
      expect(normalUser.isAdmin, isFalse);

      const adminUser = AppUser(
        uid: 'admin_1',
        provider: 'password',
        role: 'admin',
      );
      expect(adminUser.isAdmin, isTrue);

      const caseAdminUser = AppUser(
        uid: 'admin_2',
        provider: 'password',
        role: '  Admin  ',
      );
      expect(caseAdminUser.isAdmin, isTrue);
    });

    test('AdminService.isCurrentUserAdmin returns false when unauthenticated', () async {
      AdminService.testIsAdminOverride = null;
      final isAdmin = await AdminService.instance.isCurrentUserAdmin();
      expect(isAdmin, isFalse);
    });

    test('AdminService.isCurrentUserAdmin obeys testIsAdminOverride', () async {
      AdminService.testIsAdminOverride = true;
      expect(await AdminService.instance.isCurrentUserAdmin(), isTrue);

      AdminService.testIsAdminOverride = false;
      expect(await AdminService.instance.isCurrentUserAdmin(), isFalse);
    });

    test('AdminService.assertAdmin throws when unauthorized and succeeds when authorized', () async {
      AdminService.testIsAdminOverride = false;
      expect(
        () => AdminService.instance.assertAdmin(),
        throwsA(isA<AdminAuthorizationException>()),
      );

      AdminService.testIsAdminOverride = true;
      await expectLater(AdminService.instance.assertAdmin(), completes);
    });

    test('FirestoreService.ensureUserProfile preserves existing admin role on sync', () async {
      FirestoreService.testUsers = {
        'admin_uid_99': const AppUser(
          uid: 'admin_uid_99',
          name: 'Existing Admin',
          email: 'admin@tourmate.app',
          provider: 'password',
          role: 'admin',
        ),
      };

      // Normal sign-in default constructs user with role: 'user'
      const signingInUser = AppUser(
        uid: 'admin_uid_99',
        name: 'Existing Admin Updated Name',
        email: 'admin@tourmate.app',
        provider: 'password',
        role: 'user',
      );

      await FirestoreService.instance.ensureUserProfile(signingInUser);

      final storedProfile = await FirestoreService.instance.getUserProfile('admin_uid_99');
      expect(storedProfile, isNotNull);
      expect(storedProfile!.role, 'admin');
      expect(storedProfile.isAdmin, isTrue);
      expect(storedProfile.name, 'Existing Admin Updated Name');
    });

    test('AdminService.isUserAdmin returns correct status via Firestore profile', () async {
      FirestoreService.testUsers = {
        'user_reg': const AppUser(uid: 'user_reg', provider: 'password', role: 'user'),
        'user_adm': const AppUser(uid: 'user_adm', provider: 'password', role: 'admin'),
      };

      expect(await AdminService.instance.isUserAdmin('user_reg'), isFalse);
      expect(await AdminService.instance.isUserAdmin('user_adm'), isTrue);
      expect(await AdminService.instance.isUserAdmin('non_existent'), isFalse);
    });
  });

  group('2. Attraction Validation Tests', () {
    test('generateId creates URL-safe slug from name', () {
      expect(AttractionService.generateId('Statue of Liberty'), 'statue-of-liberty');
      expect(AttractionService.generateId('Eiffel Tower! (Paris)'), 'eiffel-tower-paris');
      expect(AttractionService.generateId('Mount Fuji'), 'mount-fuji');
    });

    test('valid attraction passes validateAttraction', () {
      expect(
        () => AttractionService.instance.validateAttraction(sampleAttraction1),
        returnsNormally,
      );
    });

    test('empty name throws validation exception', () {
      final invalid = sampleAttraction1.copyWith(name: '   ');
      expect(
        () => AttractionService.instance.validateAttraction(invalid),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('name cannot be empty'),
        )),
      );
    });

    test('empty category throws validation exception', () {
      final invalid = sampleAttraction1.copyWith(category: '');
      expect(
        () => AttractionService.instance.validateAttraction(invalid),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('Category cannot be empty'),
        )),
      );
    });

    test('empty description throws validation exception', () {
      final invalid = sampleAttraction1.copyWith(description: ' ');
      expect(
        () => AttractionService.instance.validateAttraction(invalid),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('Description cannot be empty'),
        )),
      );
    });

    test('rating outside 0.0 - 5.0 throws validation exception', () {
      final invalidLow = sampleAttraction1.copyWith(rating: -0.5);
      expect(
        () => AttractionService.instance.validateAttraction(invalidLow),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('Rating must be between 0.0 and 5.0'),
        )),
      );

      final invalidHigh = sampleAttraction1.copyWith(rating: 5.5);
      expect(
        () => AttractionService.instance.validateAttraction(invalidHigh),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('Rating must be between 0.0 and 5.0'),
        )),
      );
    });

    test('latitude outside -90 to 90 throws validation exception', () {
      final invalidLat = sampleAttraction1.copyWith(latitude: 95.0);
      expect(
        () => AttractionService.instance.validateAttraction(invalidLat),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('Latitude must be between -90.0 and 90.0'),
        )),
      );
    });

    test('longitude outside -180 to 180 throws validation exception', () {
      final invalidLng = sampleAttraction1.copyWith(longitude: -185.0);
      expect(
        () => AttractionService.instance.validateAttraction(invalidLng),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('Longitude must be between -180.0 and 180.0'),
        )),
      );
    });

    test('invalid image URL throws validation exception', () {
      final invalidImg = sampleAttraction1.copyWith(imageUrl: 'not_a_valid_url');
      expect(
        () => AttractionService.instance.validateAttraction(invalidImg),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('valid HTTP or HTTPS URL'),
        )),
      );
    });
  });

  group('3. Attraction CRUD Operations Tests', () {
    setUp(() {
      AttractionService.testAttractions = {
        sampleAttraction1.id: sampleAttraction1,
      };
    });

    test('createAttraction adds attraction and auto-generates id if missing', () async {
      final toAdd = sampleAttraction2.copyWith(id: '');
      final created = await AttractionService.instance.createAttraction(toAdd);

      expect(created.id, 'colosseum');
      expect(AttractionService.testAttractions!.containsKey('colosseum'), isTrue);
      expect(AttractionService.testAttractions!['colosseum']!.name, 'Colosseum');
    });

    test('createAttraction prevents duplicate attraction ID', () async {
      expect(
        () => AttractionService.instance.createAttraction(sampleAttraction1),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        )),
      );
    });

    test('updateAttraction modifies existing attraction', () async {
      final updated = sampleAttraction1.copyWith(rating: 4.9, entryFee: '€28.0');
      final result = await AttractionService.instance.updateAttraction(updated);

      expect(result.rating, 4.9);
      expect(result.entryFee, '€28.0');
      expect(AttractionService.testAttractions!['eiffel-tower']!.rating, 4.9);
    });

    test('updateAttraction on non-existent id throws exception', () async {
      final nonExistent = sampleAttraction2.copyWith(id: 'non-existent-id');
      expect(
        () => AttractionService.instance.updateAttraction(nonExistent),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        )),
      );
    });

    test('deleteAttraction removes attraction from dataset', () async {
      expect(AttractionService.testAttractions!.containsKey('eiffel-tower'), isTrue);
      await AttractionService.instance.deleteAttraction('eiffel-tower');
      expect(AttractionService.testAttractions!.containsKey('eiffel-tower'), isFalse);
    });

    test('deleteAttraction on non-existent id throws exception', () async {
      expect(
        () => AttractionService.instance.deleteAttraction('does-not-exist'),
        throwsA(isA<AttractionValidationException>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        )),
      );
    });
  });

  group('4. Admin Dashboard UI Widget Tests', () {
    testWidgets('shows Access Denied when user is not admin', (tester) async {
      AdminService.testIsAdminOverride = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AdminDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.byKey(const Key('admin_unauthorized_return_button')), findsOneWidget);
      expect(find.text('Total Attractions'), findsNothing);
    });

    testWidgets('authorized admin sees dashboard metrics and attractions', (tester) async {
      AdminService.testIsAdminOverride = true;
      AttractionService.testAttractions = {
        sampleAttraction1.id: sampleAttraction1,
        sampleAttraction2.id: sampleAttraction2,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AdminDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header and analytics
      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('Dataset Analytics'), findsOneWidget);
      expect(find.text('Total Attractions'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 total attractions

      // Attractions list
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Colosseum'), findsOneWidget);
      expect(find.byKey(const Key('admin_add_attraction_button')), findsOneWidget);
    });

    testWidgets('search filters attraction list in real time', (tester) async {
      AdminService.testIsAdminOverride = true;
      AttractionService.testAttractions = {
        sampleAttraction1.id: sampleAttraction1,
        sampleAttraction2.id: sampleAttraction2,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AdminDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Colosseum'), findsOneWidget);

      // Search for Rome
      await tester.enterText(find.byKey(const Key('admin_search_field')), 'Rome');
      await tester.pumpAndSettle();

      expect(find.text('Colosseum'), findsOneWidget);
      expect(find.text('Eiffel Tower'), findsNothing);
    });

    testWidgets('empty search results displays empty state', (tester) async {
      AdminService.testIsAdminOverride = true;
      AttractionService.testAttractions = {
        sampleAttraction1.id: sampleAttraction1,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AdminDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin_search_field')), 'Atlantis');
      await tester.pumpAndSettle();

      expect(find.text('No attractions found'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);
    });

    testWidgets('delete attraction prompts confirmation dialog and can be cancelled', (tester) async {
      AdminService.testIsAdminOverride = true;
      AttractionService.testAttractions = {
        sampleAttraction1.id: sampleAttraction1,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AdminDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete on Eiffel Tower
      await tester.tap(find.byKey(Key('admin_delete_button_${sampleAttraction1.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Attraction'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete "Eiffel Tower"?'), findsOneWidget);

      // Cancel deletion
      await tester.tap(find.byKey(const Key('admin_delete_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Attraction'), findsNothing);
      expect(AttractionService.testAttractions!.containsKey('eiffel-tower'), isTrue);
    });
  });

  group('5. AttractionFormDialog Widget Tests', () {
    testWidgets('validates required fields on submit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AttractionFormDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear all fields and tap Save
      await tester.enterText(find.byKey(const Key('admin_attraction_name_field')), '');
      await tester.enterText(find.byKey(const Key('admin_attraction_description_field')), '');
      await tester.enterText(find.byKey(const Key('admin_attraction_image_url_field')), '');
      await tester.tap(find.byKey(const Key('admin_attraction_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Attraction name is required.'), findsOneWidget);
      expect(find.text('Description is required.'), findsOneWidget);
      expect(find.text('Image URL is required.'), findsOneWidget);
    });

    testWidgets('pre-populates existing attraction data when editing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AttractionFormDialog(attraction: sampleAttraction1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Attraction'), findsOneWidget);
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
    });
  });

  group('6. ProfileScreen Admin Tile Visibility Tests', () {
    testWidgets('hides Admin Dashboard tile when user is not admin', (tester) async {
      AdminService.testIsAdminOverride = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_dashboard_profile_tile')), findsNothing);
      expect(find.text('Admin Dashboard'), findsNothing);
    });

    testWidgets('shows Admin Dashboard tile when user is admin', (tester) async {
      AdminService.testIsAdminOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_dashboard_profile_tile')), findsOneWidget);
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  });
}

