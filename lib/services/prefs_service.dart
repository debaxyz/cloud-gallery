import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cloud_account.dart';

class PrefsService {
  PrefsService(this._prefs);

  final SharedPreferences _prefs;

  static const _keyOnboardingDone = 'onboarding_done';
  static const _keyThemeMode = 'theme_mode';
  static const _keyLastTab = 'last_tab'; // 0 = device, 1 = drive
  static const _keyViewMode = 'view_mode'; // grid / list
  static const _keyAccounts = 'cloud_accounts';
  static const _keyAutoBackup = 'auto_backup';

  bool get onboardingDone => _prefs.getBool(_keyOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(_keyOnboardingDone, value);

  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_keyThemeMode, mode);

  int get lastTab => _prefs.getInt(_keyLastTab) ?? 0;
  Future<void> setLastTab(int index) => _prefs.setInt(_keyLastTab, index);

  String get viewMode => _prefs.getString(_keyViewMode) ?? 'grid';
  Future<void> setViewMode(String mode) =>
      _prefs.setString(_keyViewMode, mode);

  bool get autoBackup => _prefs.getBool(_keyAutoBackup) ?? false;
  Future<void> setAutoBackup(bool value) =>
      _prefs.setBool(_keyAutoBackup, value);

  List<CloudAccount> getAccounts() {
    final raw = _prefs.getString(_keyAccounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CloudAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccounts(List<CloudAccount> accounts) async {
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _prefs.setString(_keyAccounts, encoded);
  }

  Future<void> addOrUpdateAccount(CloudAccount account) async {
    final list = getAccounts();
    final idx = list.indexWhere((a) => a.id == account.id);
    if (idx >= 0) {
      list[idx] = account;
    } else {
      list.add(account);
    }
    await saveAccounts(list);
  }

  Future<void> removeAccount(String id) async {
    final list = getAccounts()..removeWhere((a) => a.id == id);
    await saveAccounts(list);
  }
}
