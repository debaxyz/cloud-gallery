import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_account.dart';
import '../services/auth_service.dart';
import '../services/google_drive_service.dart';
import '../services/prefs_service.dart';
import 'prefs_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final auth = ref.watch(authServiceProvider);
  return GoogleDriveService(auth);
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

  AuthService get _auth => _ref.read(authServiceProvider);
  GoogleDriveService get _drive => _ref.read(googleDriveServiceProvider);
  PrefsService get _prefs => _ref.read(prefsServiceProvider);

  Future<void> _trySilentSignIn() async {
    state = const AsyncValue.loading();
    try {
      final account = await _auth.signInSilently();
      if (account != null) {
        await _prefs.addOrUpdateAccount(account);
        // Warm up Drive client in background
        try {
          await _drive.ensureInitialized();
        } catch (_) {}
      }
      state = AsyncValue.data(account);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Google Sign-In + Firebase Auth.
  Future<void> signIn() async {
    state = const AsyncValue.loading();
    try {
      final account = await _auth.signInWithGoogle();
      if (account != null) {
        await _prefs.addOrUpdateAccount(account);
        try {
          await _drive.ensureInitialized();
        } catch (_) {}
      }
      state = AsyncValue.data(account);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    _drive.reset();
    await _auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> disconnect() async {
    final current = state.valueOrNull;
    _drive.reset();
    await _auth.disconnect();
    if (current != null) {
      await _prefs.removeAccount(current.id);
    }
    state = const AsyncValue.data(null);
  }
}

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});
