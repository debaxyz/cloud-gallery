import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_account.dart';
import '../services/auth_service.dart';
import '../services/prefs_service.dart';
import 'prefs_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<CloudAccount?>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<CloudAccount?>> {
  AuthNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _restore();
  }

  final Ref _ref;

  AuthService get _auth => _ref.read(authServiceProvider);
  PrefsService get _prefs => _ref.read(prefsServiceProvider);

  Future<void> _restore() async {
    try {
      final account = await _auth.restoreSession();
      if (account != null) {
        await _prefs.addOrUpdateAccount(account);
      }
      if (mounted) state = AsyncValue.data(account);
    } catch (_) {
      if (mounted) state = const AsyncValue.data(null);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final account = await _auth.signInWithEmail(
        email: email,
        password: password,
      );
      await _prefs.addOrUpdateAccount(account);
      state = AsyncValue.data(account);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final account = await _auth.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _prefs.addOrUpdateAccount(account);
      state = AsyncValue.data(account);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> disconnect() async {
    final current = state.valueOrNull;
    await _auth.disconnect();
    if (current != null) {
      await _prefs.removeAccount(current.id);
    }
    state = const AsyncValue.data(null);
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});
