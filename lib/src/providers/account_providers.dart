import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_account.dart';
import '../services/account_service.dart';

final accountServiceProvider = Provider<AccountService>((ref) => AccountService());

final accountsProvider = FutureProvider<List<CloudAccount>>((ref) async {
  return ref.watch(accountServiceProvider).getAccounts();
});

final accountsNotifierProvider =
    StateNotifierProvider<AccountsNotifier, AsyncValue<List<CloudAccount>>>((ref) {
  return AccountsNotifier(ref);
});

class AccountsNotifier extends StateNotifier<AsyncValue<List<CloudAccount>>> {
  final Ref _ref;

  AccountsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _ref.read(accountServiceProvider).getAccounts());
  }

  Future<void> connect(CloudProvider provider) async {
    final current = state.valueOrNull ?? [];
    // Optimistic update
    final updated = current.map((a) {
      if (a.provider == provider) {
        return a.copyWith(isConnected: true);
      }
      return a;
    }).toList();
    state = AsyncValue.data(updated);

    try {
      final account = await _ref.read(accountServiceProvider).connectAccount(provider);
      final finalList = current.map((a) {
        if (a.provider == provider) return account;
        return a;
      }).toList();
      // Ensure the account exists
      if (!finalList.any((a) => a.provider == provider)) {
        finalList.add(account);
      }
      state = AsyncValue.data(finalList);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> disconnect(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.map((a) {
      if (a.id == id) return a.copyWith(isConnected: false);
      return a;
    }).toList();
    state = AsyncValue.data(updated);
    await _ref.read(accountServiceProvider).disconnectAccount(id);
  }

  Future<void> refresh() => _load();
}
