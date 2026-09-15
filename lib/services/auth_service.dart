import 'package:firebase_auth/firebase_auth.dart';
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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

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
      throw const AuthServiceException('Something went wrong. Please try again.');
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
      throw const AuthServiceException('Something went wrong. Please try again.');
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('cancel')) {
        throw const AuthServiceException('Google Sign-In was cancelled.');
      }
      throw const AuthServiceException('Google Sign-In failed. Please try again.');
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(FirebaseAuthException error) verificationFailed,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
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
      throw const AuthServiceException('Could not send the verification code. Please try again.');
    }
  }

  Future<UserCredential> signInWithPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException('Could not verify the code. Please try again.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException('Something went wrong. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Firebase sign-out is authoritative; Google account sign-out is best effort.
      }
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (_) {
      throw const AuthServiceException('Something went wrong. Please try again.');
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
}
