import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  @visibleForTesting
  static FirebaseAuth? testAuthOverride;

  @visibleForTesting
  static Future<UserCredential> Function()? testSignInWithGoogleOverride;

  @visibleForTesting
  static void resetForTest() {
    testAuthOverride = null;
    testSignInWithGoogleOverride = null;
  }

  FirebaseAuth? get _auth {
    if (testAuthOverride != null) return testAuthOverride;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance;
  }

  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  Future<void>? _googleSignInInitFuture;

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitFuture ??= _googleSignIn.initialize();
  }

  User? get currentUser => _auth?.currentUser;

  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) return const Stream<User?>.empty();
    return auth.authStateChanges();
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthServiceException('Firebase is not initialized.');
    }
    try {
      return await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong. Please try again.',
      );
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthServiceException('Firebase is not initialized.');
    }
    try {
      return await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong. Please try again.',
      );
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    if (testSignInWithGoogleOverride != null) {
      return await testSignInWithGoogleOverride!();
    }

    final auth = _auth;
    if (auth == null) {
      throw const AuthServiceException('Firebase is not initialized.');
    }

    if (kIsWeb) {
      try {
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        return await auth.signInWithPopup(googleProvider);
      } on FirebaseAuthException catch (error) {
        throw AuthServiceException(_messageForAuthError(error));
      } catch (error) {
        if (error is AuthServiceException) rethrow;
        final message = error.toString().toLowerCase();
        if (message.contains('cancel') ||
            message.contains('abort') ||
            message.contains('popup-closed-by-user')) {
          throw const AuthServiceException('Google Sign-In was cancelled.');
        }
        if (message.contains('popup-blocked')) {
          throw const AuthServiceException(
            'Sign-in popup was blocked by your browser. Please allow popups for this site.',
          );
        }
        if (message.contains('unauthorized-domain')) {
          throw const AuthServiceException(
            'This domain is not authorized for Google Sign-In. Please check your Firebase authorized domains.',
          );
        }
        throw const AuthServiceException(
          'Google Sign-In failed. Please try again.',
        );
      }
    }

    try {
      await _ensureGoogleSignInInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthServiceException(
          'Google Sign-In is not supported on this platform.',
        );
      }
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthServiceException(
          'Failed to retrieve Google authentication token. Please try again.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      return await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (error) {
      if (error is AuthServiceException) rethrow;
      final message = error.toString().toLowerCase();
      if (message.contains('cancel') || message.contains('abort')) {
        throw const AuthServiceException('Google Sign-In was cancelled.');
      }
      throw const AuthServiceException(
        'Google Sign-In failed. Please try again.',
      );
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(FirebaseAuthException error) verificationFailed,
    required void Function(PhoneAuthCredential credential)
    verificationCompleted,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthServiceException('Firebase is not initialized.');
    }
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        forceResendingToken: forceResendingToken,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Could not send the verification code. Please try again.',
      );
    }
  }

  Future<UserCredential> signInWithPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthServiceException('Firebase is not initialized.');
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Could not verify the code. Please try again.',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthServiceException('Firebase is not initialized.');
    }
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) return;
    try {
      await auth.signOut();
      if (!kIsWeb) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {
          // Firebase sign-out is authoritative; Google account sign-out is best effort.
        }
      }
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong. Please try again.',
      );
    }
  }

  static String messageForAuthErrorCode(String code) {
    switch (code) {
      case 'popup-closed-by-user':
        return 'Sign-in was cancelled.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked by your browser. Please allow popups for this site.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for Google Sign-In. Please check your Firebase authorized domains.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email address using a different sign-in method.';
      case 'cancelled-popup-request':
        return 'Only one popup request is allowed at a time.';
      case 'invalid-oauth-client-id':
      case 'invalid-api-key':
        return 'Google Sign-In configuration error. Please contact support.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect.';
      case 'invalid-verification-id':
        return 'The verification session expired. Please request a new code.';
      case 'session-expired':
        return 'The verification session expired. Please request a new code.';
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled yet.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String _messageForAuthError(FirebaseAuthException error) {
    return messageForAuthErrorCode(error.code);
  }
}
