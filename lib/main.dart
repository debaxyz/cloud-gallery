import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'src/providers/app_providers.dart';
import 'src/router/app_router.dart';
import 'src/services/crashlytics_service.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase (Analytics + Crashlytics)
  // Safe if credentials are still placeholders — app continues without Firebase.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await CrashlyticsService.init();
    firebaseReady = true;
    if (kDebugMode) debugPrint('Firebase initialized');
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Firebase init skipped (configure with flutterfire): $e');
      debugPrint('$st');
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: CloudGalleryApp(firebaseReady: firebaseReady),
    ),
  );
}

class CloudGalleryApp extends ConsumerWidget {
  final bool firebaseReady;

  const CloudGalleryApp({super.key, this.firebaseReady = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Cloud Gallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
