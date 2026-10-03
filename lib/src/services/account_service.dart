import '../models/cloud_account.dart';
import 'dropbox_service.dart';
import 'google_drive_service.dart';

/// Manages cloud account sessions (Google Drive + Dropbox).
class AccountService {
  AccountService({
    GoogleDriveService? drive,
    DropboxService? dropbox,
  })  : drive = drive ?? GoogleDriveService(),
        dropbox = dropbox ?? DropboxService();

  final GoogleDriveService drive;
  final DropboxService dropbox;

  /// Returns current connection state for both providers.
  Future<List<CloudAccount>> getAccounts() async {
    final list = <CloudAccount>[];

    // Google Drive
    try {
      final gd = await drive.silentSignIn();
      if (gd != null) {
        list.add(gd);
      } else {
        list.add(const CloudAccount(
          id: 'gd_placeholder',
          provider: CloudProvider.googleDrive,
          email: '',
          displayName: 'Google Drive',
          isConnected: false,
        ));
      }
    } catch (_) {
      list.add(const CloudAccount(
        id: 'gd_placeholder',
        provider: CloudProvider.googleDrive,
        email: '',
        displayName: 'Google Drive',
        isConnected: false,
      ));
    }

    // Dropbox
    try {
      final db = await dropbox.restoreSession();
      if (db != null) {
        list.add(db);
      } else {
        list.add(const CloudAccount(
          id: 'db_placeholder',
          provider: CloudProvider.dropbox,
          email: '',
          displayName: 'Dropbox',
          isConnected: false,
        ));
      }
    } catch (_) {
      list.add(const CloudAccount(
        id: 'db_placeholder',
        provider: CloudProvider.dropbox,
        email: '',
        displayName: 'Dropbox',
        isConnected: false,
      ));
    }

    return list;
  }

  Future<CloudAccount> connect(CloudProvider provider) async {
    switch (provider) {
      case CloudProvider.googleDrive:
        final account = await drive.signIn();
        if (account == null) {
          throw StateError('Google sign-in cancelled');
        }
        return account;
      case CloudProvider.dropbox:
        // Starts external browser; caller must complete via handleDropboxRedirect
        await dropbox.startAuth();
        throw DropboxAuthPendingException();
    }
  }

  Future<CloudAccount> completeDropboxAuth(Uri redirectUri) {
    return dropbox.handleRedirect(redirectUri);
  }

  Future<void> disconnect(CloudProvider provider) async {
    switch (provider) {
      case CloudProvider.googleDrive:
        await drive.signOut();
        break;
      case CloudProvider.dropbox:
        await dropbox.disconnect();
        break;
    }
  }
}

/// Thrown when Dropbox OAuth is started and waiting for redirect.
class DropboxAuthPendingException implements Exception {
  @override
  String toString() =>
      'Dropbox auth started in browser. Complete sign-in, then handle the redirect URI.';
}
