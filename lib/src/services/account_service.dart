import '../models/cloud_account.dart';

class AccountService {
  Future<List<CloudAccount>> getAccounts() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      const CloudAccount(
        id: 'gd_1',
        provider: CloudProvider.googleDrive,
        email: 'you@gmail.com',
        displayName: 'You',
        isConnected: true,
        usedBytes: 12 * 1024 * 1024 * 1024, // 12 GB
        totalBytes: 15 * 1024 * 1024 * 1024, // 15 GB
      ),
      const CloudAccount(
        id: 'db_1',
        provider: CloudProvider.dropbox,
        email: 'you@dropbox.com',
        displayName: 'You',
        isConnected: false,
        usedBytes: 0,
        totalBytes: 2 * 1024 * 1024 * 1024, // 2 GB free
      ),
    ];
  }

  Future<CloudAccount> connectAccount(CloudProvider provider) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    // Simulate successful OAuth
    if (provider == CloudProvider.googleDrive) {
      return const CloudAccount(
        id: 'gd_1',
        provider: CloudProvider.googleDrive,
        email: 'you@gmail.com',
        displayName: 'You',
        isConnected: true,
        usedBytes: 12 * 1024 * 1024 * 1024,
        totalBytes: 15 * 1024 * 1024 * 1024,
      );
    }
    return const CloudAccount(
      id: 'db_1',
      provider: CloudProvider.dropbox,
      email: 'you@dropbox.com',
      displayName: 'You',
      isConnected: true,
      usedBytes: 450 * 1024 * 1024,
      totalBytes: 2 * 1024 * 1024 * 1024,
    );
  }

  Future<void> disconnectAccount(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
