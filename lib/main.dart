import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

class TourMateApp extends StatelessWidget {
  const TourMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TourMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TourMateApp());
}
