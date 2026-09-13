import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await AuthService.instance.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final user = credential.user;

      if (user != null) {
        await FirestoreService.instance.ensureUserProfile(_appUserFrom(user));
      }

      if (!mounted) return;
      context.go(AppRouter.home);
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetFormKey = GlobalKey<FormState>();
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: Form(
            key: resetFormKey,
            child: TextFormField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _validateEmail,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (resetFormKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, resetEmailController.text.trim());
                }
              },
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );

    resetEmailController.dispose();

    if (email == null) {
      return;
    }

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
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (email.isEmpty) {
      return 'Please enter your email';
    }
    if (!emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  AppUser _appUserFrom(User user) {
    return AppUser(
      uid: user.uid,
      name: user.displayName,
      email: user.email ?? _emailController.text.trim(),
      photoUrl: user.photoURL,
      phoneNumber: user.phoneNumber,
      provider: user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                    Icon(
                      Icons.travel_explore_rounded,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome back',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue exploring ${AppConstants.defaultCity}.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : _showForgotPasswordDialog,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Login'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Google Sign-In will be added in a later step.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.go(AppRouter.register),
                          child: const Text('Create Account'),
                        ),
                      ],
                    ),
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
