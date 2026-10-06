import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reporting helpers.
class CrashlyticsService {
  static Future<void> init() async {
    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Pass uncaught async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode, // disable in debug to keep console clean
    );
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
        reason: reason,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Crashlytics record failed: $e');
    }
  }

  static Future<void> log(String message) async {
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  static Future<void> setUserId(String id) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(id);
    } catch (_) {}
  }
}
