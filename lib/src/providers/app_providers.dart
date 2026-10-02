import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final hasSeenOnboardingProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('has_seen_onboarding') ?? false;
});

final themeModeProvider = StateProvider<bool>((ref) {
  // true = dark
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('is_dark_mode') ?? false;
});

Future<void> setOnboardingSeen(SharedPreferences prefs) async {
  await prefs.setBool('has_seen_onboarding', true);
}

Future<void> setDarkMode(SharedPreferences prefs, bool isDark) async {
  await prefs.setBool('is_dark_mode', isDark);
}
