import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tourmate/core/theme/app_theme.dart';
import 'package:tourmate/screens/auth/login_screen.dart';
import 'package:tourmate/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AuthService error message mapping', () {
    test('maps web Google Sign-In error codes correctly', () {
      expect(
        AuthService.messageForAuthErrorCode('popup-closed-by-user'),
        'Sign-in was cancelled.',
      );
      expect(
        AuthService.messageForAuthErrorCode('popup-blocked'),
        'Sign-in popup was blocked by your browser. Please allow popups for this site.',
      );
      expect(
        AuthService.messageForAuthErrorCode('unauthorized-domain'),
        'This domain is not authorized for Google Sign-In. Please check your Firebase authorized domains.',
      );
      expect(
        AuthService.messageForAuthErrorCode(
          'account-exists-with-different-credential',
        ),
        'An account already exists with this email address using a different sign-in method.',
      );
      expect(
        AuthService.messageForAuthErrorCode('cancelled-popup-request'),
        'Only one popup request is allowed at a time.',
      );
      expect(
        AuthService.messageForAuthErrorCode('invalid-oauth-client-id'),
        'Google Sign-In configuration error. Please contact support.',
      );
      expect(
        AuthService.messageForAuthErrorCode('invalid-api-key'),
        'Google Sign-In configuration error. Please contact support.',
      );
    });

    test('maps standard authentication error codes correctly', () {
      expect(
        AuthService.messageForAuthErrorCode('email-already-in-use'),
        'An account with this email already exists.',
      );
      expect(
        AuthService.messageForAuthErrorCode('invalid-email'),
        'Please enter a valid email address.',
      );
      expect(
        AuthService.messageForAuthErrorCode('weak-password'),
        'Password must be at least 6 characters.',
      );
      expect(
        AuthService.messageForAuthErrorCode('wrong-password'),
        'Invalid email or password.',
      );
      expect(
        AuthService.messageForAuthErrorCode('user-not-found'),
        'Invalid email or password.',
      );
      expect(
        AuthService.messageForAuthErrorCode('invalid-credential'),
        'Invalid email or password.',
      );
      expect(
        AuthService.messageForAuthErrorCode('user-disabled'),
        'This account has been disabled.',
      );
      expect(
        AuthService.messageForAuthErrorCode('network-request-failed'),
        'Please check your internet connection and try again.',
      );
      expect(
        AuthService.messageForAuthErrorCode('operation-not-allowed'),
        'This sign-in method is not enabled yet.',
      );
      expect(
        AuthService.messageForAuthErrorCode('unknown-random-code'),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('AuthService uninitialized state and overrides', () {
    setUp(() {
      AuthService.resetForTest();
    });

    tearDown(() {
      AuthService.resetForTest();
    });

    test('signInWithGoogle throws when Firebase is not initialized', () async {
      expect(
        () => AuthService.instance.signInWithGoogle(),
        throwsA(
          isA<AuthServiceException>().having(
            (e) => e.message,
            'message',
            'Firebase is not initialized.',
          ),
        ),
      );
    });

    test('signInWithGoogle uses test override when configured', () async {
      AuthService.testSignInWithGoogleOverride = () async {
        throw const AuthServiceException('Test Google cancellation');
      };

      expect(
        () => AuthService.instance.signInWithGoogle(),
        throwsA(
          isA<AuthServiceException>().having(
            (e) => e.message,
            'message',
            'Test Google cancellation',
          ),
        ),
      );
    });
  });

  group('LoginScreen Google Sign-In UI interaction', () {
    setUp(() {
      AuthService.resetForTest();
    });

    tearDown(() {
      AuthService.resetForTest();
    });

    testWidgets('shows specific SnackBar error when Google Sign-In is cancelled', (
      tester,
    ) async {
      AuthService.testSignInWithGoogleOverride = () async {
        throw const AuthServiceException('Google Sign-In was cancelled.');
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final googleButton = find.text('Continue with Google');
      expect(googleButton, findsOneWidget);

      await tester.tap(googleButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Google Sign-In was cancelled.'), findsOneWidget);
    });

    testWidgets('shows specific SnackBar error when popup is blocked', (
      tester,
    ) async {
      AuthService.testSignInWithGoogleOverride = () async {
        throw const AuthServiceException(
          'Sign-in popup was blocked by your browser. Please allow popups for this site.',
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final googleButton = find.text('Continue with Google');
      await tester.tap(googleButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sign-in popup was blocked by your browser. Please allow popups for this site.',
        ),
        findsOneWidget,
      );
    });
  });
}
