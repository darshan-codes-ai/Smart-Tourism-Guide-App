# TourMate — Google Sign-In Production Bug Fix Report

**Project:** TourMate — Smart Tourism Guide App  
**Local Path:** `C:\Users\Darsh\tourmate`  
**Live URL:** [https://tourmate-70d03.web.app](https://tourmate-70d03.web.app)  
**Firebase Project:** `tourmate-70d03`  
**GitHub Repository:** `darshan-codes-ai/Smart-Tourism-Guide-App`  
**Date:** November 18, 2026  

---

## 1. Executive Summary

A critical issue on the deployed Flutter Web release (`https://tourmate-70d03.web.app`) caused Google Sign-In attempts to fail with a generic error: *"Google Sign-In failed. Please try again."*

The root cause was identified, a platform-specific authentication strategy was implemented, error code handling was improved, profile synchronization was decoupled from core credential acquisition, and automated tests were added. The solution was validated with `flutter analyze` (0 issues), the complete test suite (263/263 passed), a production release web build (`flutter build web --release`), and a live deployment to Firebase Hosting with live HTTP/1.1 200 verification.

---

## 2. Root Cause Analysis

1. **Unconditional `google_sign_in` 7.x Web Initialization:**
   In `google_sign_in: ^7.2.0`, calling `GoogleSignIn.instance.initialize()` followed by `GoogleSignIn.instance.authenticate()` unconditionally on Flutter Web requires specific client configuration (GIS meta tags/scripts or renderButton) and behaves differently than native mobile platforms. On web browsers, this threw an unhandled exception that was caught and collapsed into the generic failure message.
2. **Coupled Authentication & Firestore Profile Synchronization:**
   In `LoginScreen._loginWithGoogle()`, `AuthService.instance.signInWithGoogle()` and `_ensureProfile(credential.user)` were executed inside the same `try/catch` block. If `_ensureProfile` suffered any Firestore permission or network delay, the exception was caught by `catch (_)` and displayed as *"Google Sign-In failed. Please try again."*, obscuring that the user was actually authenticated with Firebase.
3. **Generic Error Collapsing:**
   `AuthService._messageForAuthError` lacked mappings for web-specific OAuth error codes (`popup-closed-by-user`, `popup-blocked`, `unauthorized-domain`, `account-exists-with-different-credential`, `cancelled-popup-request`). Legitimate user actions (such as closing the popup window) were reported as unexpected failures rather than cancellations.

---

## 3. Implemented Fixes

### A. Platform-Specific Google Sign-In (`lib/services/auth_service.dart`)
- **Flutter Web (`kIsWeb`):**
  Uses Firebase Auth's native popup provider:
  ```dart
  if (kIsWeb) {
    try {
      final googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      return await auth.signInWithPopup(googleProvider);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    } catch (error) { ... }
  }
  ```
- **Native Platforms (Android, iOS, macOS, Windows):**
  - Caches `GoogleSignIn.instance.initialize()` via `_googleSignInInitFuture` to prevent redundant initialization cycles.
  - Verifies `_googleSignIn.supportsAuthenticate()`.
  - Validates `googleAuth.idToken` null-safety before invoking `GoogleAuthProvider.credential(idToken: idToken)`.
- **Sign-Out Guarding:**
  `AuthService.signOut()` guards `_googleSignIn.signOut()` with `if (!kIsWeb)` so uninitialized web plugin states do not raise background warnings during session termination.

### B. Comprehensive Error Mapping
Added `AuthService.messageForAuthErrorCode(String code)` covering all web and OAuth scenarios:
- `popup-closed-by-user` & user aborts: `"Sign-in was cancelled."`
- `popup-blocked`: `"Sign-in popup was blocked by your browser. Please allow popups for this site."`
- `unauthorized-domain`: `"This domain is not authorized for Google Sign-In. Please check your Firebase authorized domains."`
- `account-exists-with-different-credential`: `"An account already exists with this email address using a different sign-in method."`
- `cancelled-popup-request`: `"Only one popup request is allowed at a time."`
- `invalid-oauth-client-id` / `invalid-api-key`: `"Google Sign-In configuration error. Please contact support."`

### C. Login Screen Decoupling (`lib/screens/auth/login_screen.dart`)
- Separated authentication acquisition from `_ensureProfile()`.
- If Google or Email sign-in succeeds, profile synchronization runs with error trapping (`debugPrint('Profile sync error: $error')`) so transient Firestore latency never aborts navigation or masquerades as authentication failure.
- Existing user roles (including `admin`) are preserved by `FirestoreService.instance.ensureUserProfile()`.
- UI loading indicator resets cleanly on any cancellation or failure.

### D. Firebase Authorized Domains Verification
The Firebase project `tourmate-70d03` has `authDomain: 'tourmate-70d03.firebaseapp.com'`. Authorized domains verified for Google OAuth:
- `tourmate-70d03.firebaseapp.com`
- `tourmate-70d03.web.app`
- `localhost`

---

## 4. Verification and Test Results

### 1. Static Analysis (`flutter analyze`)
```
Analyzing tourmate...
No issues found! (ran in 2.8s)
```

### 2. Unit & Widget Testing
Added new test suite [test/auth_service_test.dart](file:///C:/Users/Darsh/tourmate/test/auth_service_test.dart):
- Web Google Sign-In error codes mapped accurately.
- Standard authentication error codes verified.
- Uninitialized Firebase error handled.
- Test override delegation verified.
- `LoginScreen` Google Sign-In cancellation UI test (shows `"Google Sign-In was cancelled."` SnackBar).
- `LoginScreen` popup blocked UI test (shows `"Sign-in popup was blocked..."` SnackBar).

**Full Suite Execution:**
```
00:26 +263: All tests passed!
```
- Total test files: 17
- Total tests executed: 263
- Passed: 263 (100%)
- Failed: 0

### 3. Release Web Compilation
```
$ flutter build web --release
Compiling lib\main.dart for the Web... 76.5s
√ Built build\web
```

### 4. Live Firebase Hosting Deployment
```
$ firebase deploy --only hosting --project tourmate-70d03
=== Deploying to 'tourmate-70d03'...
i  deploying hosting
+  hosting[tourmate-70d03]: file upload complete
+  hosting[tourmate-70d03]: version finalized
+  hosting[tourmate-70d03]: release complete
+  Deploy complete!
Hosting URL: https://tourmate-70d03.web.app
```

### 5. Live HTTP Verification
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Last-Modified: Wed, 18 Nov 2026 07:54:58 GMT
Strict-Transport-Security: max-age=31556926; includeSubDomains; preload
```

---

## 5. Modified Files Summary

| File | Status | Description |
|---|---|---|
| [lib/services/auth_service.dart](file:///C:/Users/Darsh/tourmate/lib/services/auth_service.dart) | Modified | Added `kIsWeb` popup authentication, cached native init, null-safety checks, error code mapping |
| [lib/screens/auth/login_screen.dart](file:///C:/Users/Darsh/tourmate/lib/screens/auth/login_screen.dart) | Modified | Decoupled authentication from profile creation, refined error feedback |
| [test/auth_service_test.dart](file:///C:/Users/Darsh/tourmate/test/auth_service_test.dart) | Added | 6 new unit and widget tests for auth service and login UI flows |
| [docs/GOOGLE_SIGNIN_FIX_REPORT.md](file:///C:/Users/Darsh/tourmate/docs/GOOGLE_SIGNIN_FIX_REPORT.md) | Added | Comprehensive bug fix documentation and deployment records |
