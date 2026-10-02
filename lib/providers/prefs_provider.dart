import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/prefs_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main()');
});

final prefsServiceProvider = Provider<PrefsService>((ref) {
  return PrefsService(ref.watch(sharedPreferencesProvider));
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(prefsServiceProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_fromString(_prefs.themeMode));

  final PrefsService _prefs;

  static ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final str = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _prefs.setThemeMode(str);
  }
}

final onboardingDoneProvider = StateProvider<bool>((ref) {
  return ref.watch(prefsServiceProvider).onboardingDone;
});
