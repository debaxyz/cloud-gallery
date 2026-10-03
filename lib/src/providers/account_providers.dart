import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_account.dart';
import '../services/account_service.dart';
import 'services_providers.dart';

final accountsNotifierProvider =
    StateNotifierProvider<AccountsNotifier, AsyncValue<List<CloudAccount>>>((ref) {
  return AccountsNotifier(ref);
});

class AccountsNotifier extends StateNotifier<AsyncValue<List<CloudAccount>>> {
  final Ref _ref;

  AccountsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  AccountService get _service => _ref.read(accountServiceProvider);

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.getAccounts());
  }

  Future<void> connect(CloudProvider provider) async {
    try {
      final account = await _service.connect(provider);
      final current = List<CloudAccount>.from(state.valueOrNull ?? []);
      final idx = current.indexWhere((a) => a.provider == provider);
      if (idx >= 0) {
        current[idx] = account;
      } else {
        current.add(account);
      }
      state = AsyncValue.data(current);
    } on DropboxAuthPendingException {
      // UI should show "Complete sign-in in browser"
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeDropboxAuth(Uri uri) async {
    final account = await _service.completeDropboxAuth(uri);
    final current = List<CloudAccount>.from(state.valueOrNull ?? []);
    final idx = current.indexWhere((a) => a.provider == CloudProvider.dropbox);
    if (idx >= 0) {
      current[idx] = account;
    } else {
      current.add(account);
    }
    state = AsyncValue.data(current);
  }

  Future<void> disconnect(CloudProvider provider) async {
    await _service.disconnect(provider);
    final current = List<CloudAccount>.from(state.valueOrNull ?? []);
    final idx = current.indexWhere((a) => a.provider == provider);
    if (idx >= 0) {
      current[idx] = current[idx].copyWith(
        isConnected: false,
        email: '',
        usedBytes: null,
        totalBytes: null,
      );
    }
    state = AsyncValue.data(current);
  }

  Future<void> refresh() => _load();
}
