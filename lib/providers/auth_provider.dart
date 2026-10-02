import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_account.dart';
import '../services/google_drive_service.dart';
import '../services/prefs_service.dart';
import 'prefs_provider.dart';

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<CloudAccount?>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<CloudAccount?>> {
  AuthNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _trySilentSignIn();
  }

  final Ref _ref;

  GoogleDriveService get _drive => _ref.read(googleDriveServiceProvider);
  PrefsService get _prefs => _ref.read(prefsServiceProvider);

  Future<void> _trySilentSignIn() async {
    state = const AsyncValue.loading();
    try {
      final account = await _drive.signInSilently();
      if (account != null) {
        await _prefs.addOrUpdateAccount(account);
      }
      state = AsyncValue.data(account);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn() async {
    state = const AsyncValue.loading();
    try {
      final account = await _drive.signIn();
      if (account != null) {
        await _prefs.addOrUpdateAccount(account);
      }
      state = AsyncValue.data(account);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _drive.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> disconnect() async {
    final current = state.valueOrNull;
    await _drive.disconnect();
    if (current != null) {
      await _prefs.removeAccount(current.id);
    }
    state = const AsyncValue.data(null);
  }
}

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});
