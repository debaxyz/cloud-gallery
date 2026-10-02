import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/prefs_provider.dart';
import 'theme/app_theme.dart';
import 'utils/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase — requires google-services.json (Android) / GoogleService-Info.plist (iOS)
  // generated from Firebase Console. See README for setup steps.
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    // Allow app to start even if Firebase config is missing (e.g. first clone).
    // Sign-in will fail with a clear error until config is added.
    debugPrint('Firebase.initializeApp failed: $e');
    debugPrint('$st');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CloudGalleryApp(),
    ),
  );
}

class CloudGalleryApp extends ConsumerWidget {
  const CloudGalleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Cloud Gallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
