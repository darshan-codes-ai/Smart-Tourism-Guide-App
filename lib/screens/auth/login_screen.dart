import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final credential = await AuthService.instance.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await _ensureProfile(credential.user);
      if (mounted) context.go(AppRouter.home);
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      await _ensureProfile(credential.user);
      if (mounted) context.go(AppRouter.home);
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureProfile(User? user) async {
    if (user == null) return;
    await FirestoreService.instance.ensureUserProfile(_appUserFrom(user));
  }

  Future<void> _showForgotPasswordDialog() async {
    final key = GlobalKey<FormState>();
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
            validator: _validateEmail,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null) return;
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      _showMessage('Password reset email sent. Please check your inbox.');
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Please enter a valid email address.';
    return null;
  }

  AppUser _appUserFrom(User user) => AppUser(
        uid: user.uid,
        name: user.displayName,
        email: user.email ?? _emailController.text.trim(),
        photoUrl: user.photoURL,
        phoneNumber: user.phoneNumber,
        provider: user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password',
      );

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.travel_explore_rounded, size: 44, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Welcome back', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Sign in to continue exploring ${AppConstants.defaultCity}.', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 32),
                    TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: _validateEmail),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passwordController, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _isLoading ? null : _showForgotPasswordDialog, child: const Text('Forgot Password?'))),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: _isLoading ? null : _login, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Login'))),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _isLoading ? null : _loginWithGoogle, icon: const Icon(Icons.g_mobiledata_rounded, size: 28), label: const Text('Continue with Google'))),
                    const SizedBox(height: 20),
                    Wrap(alignment: WrapAlignment.center, children: [const Text("Don't have an account?"), TextButton(onPressed: _isLoading ? null : () => context.go(AppRouter.register), child: const Text('Create Account'))]),
                    const SizedBox(height: 8),
                    Center(child: TextButton.icon(onPressed: _isLoading ? null : () => context.go(AppRouter.phoneLogin), icon: const Icon(Icons.phone_outlined), label: const Text('Sign in with phone'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});
  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _message('Enter your phone number with country code.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyPhoneNumber(
        phoneNumber: phone,
        codeSent: (id, _) { if (mounted) setState(() => _verificationId = id); },
        verificationFailed: (error) => _message(error.message ?? 'Phone verification failed.'),
        verificationCompleted: _finishSignIn,
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
      _message('Verification code sent.');
    } on AuthServiceException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final id = _verificationId;
    final code = _codeController.text.trim();
    if (id == null) return _message('Send the verification code first.');
    if (code.length < 6) return _message('Enter the 6-digit verification code.');
    setState(() => _loading = true);
    try {
      final credential = await AuthService.instance.signInWithPhoneCode(verificationId: id, smsCode: code);
      await _saveProfile(credential.user);
      if (mounted) context.go(AppRouter.home);
    } on AuthServiceException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finishSignIn(PhoneAuthCredential credential) async {
    final credentialResult = await FirebaseAuth.instance.signInWithCredential(credential);
    await _saveProfile(credentialResult.user);
    if (mounted) context.go(AppRouter.home);
  }

  Future<void> _saveProfile(User? user) async {
    if (user == null) return;
    await FirestoreService.instance.ensureUserProfile(AppUser(uid: user.uid, name: user.displayName, email: user.email, photoUrl: user.photoURL, phoneNumber: user.phoneNumber ?? _phoneController.text.trim(), provider: 'phone'));
  }

  void _message(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Phone Sign-In')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.phone_android_rounded, size: 56),
                const SizedBox(height: 20),
                Text('Sign in with phone', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Enter your number with country code, for example +91XXXXXXXXXX.'),
                const SizedBox(height: 24),
                TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loading ? null : _sendCode, child: const Text('Send verification code')),
                if (_verificationId != null) ...[
                  const SizedBox(height: 24),
                  TextField(controller: _codeController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Verification code', prefixIcon: Icon(Icons.lock_outline_rounded))),
                  FilledButton(onPressed: _loading ? null : _verifyCode, child: const Text('Verify & Continue')),
                ],
                const SizedBox(height: 16),
                TextButton(onPressed: _loading ? null : () => context.go(AppRouter.login), child: const Text('Back to email sign-in')),
                if (_loading) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
              ]),
            ),
          ),
        ),
      );
}
