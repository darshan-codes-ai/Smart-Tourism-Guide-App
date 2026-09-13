import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/main/main_shell.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../services/auth_service.dart';

class AppRouter {
  AppRouter._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';

  static final _authRefresh = _GoRouterRefreshStream(
    AuthService.instance.authStateChanges,
  );

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    refreshListenable: _authRefresh,
    redirect: (context, state) {
      final signedIn = AuthService.instance.currentUser != null;
      final location = state.uri.path;
      final onSplash = location == splash;
      final onAuthRoute = location == login || location == register;
      final onOnboarding = location == onboarding;
      final inMainApp = location == home;

      if (onSplash) {
        return null;
      }

      if (signedIn && (onAuthRoute || onOnboarding)) {
        return home;
      }

      if (!signedIn && inMainApp) {
        return login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const MainShell(),
      ),
    ],
  );
}

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
