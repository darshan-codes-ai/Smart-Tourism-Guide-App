import 'package:firebase_auth/firebase_auth.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
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
    try {
      return await _auth.signInWithEmailAndPassword(
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

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong. Please try again.',
      );
    }
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
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
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled yet.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
