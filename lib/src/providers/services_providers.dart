import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/account_service.dart';
import '../services/dropbox_service.dart';
import '../services/google_drive_service.dart';
import '../services/local_media_service.dart';
import '../services/media_service.dart';

final localMediaServiceProvider = Provider<LocalMediaService>((ref) {
  return LocalMediaService();
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

final dropboxServiceProvider = Provider<DropboxService>((ref) {
  return DropboxService();
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(
    local: ref.watch(localMediaServiceProvider),
    drive: ref.watch(googleDriveServiceProvider),
    dropbox: ref.watch(dropboxServiceProvider),
  );
});

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(
    drive: ref.watch(googleDriveServiceProvider),
    dropbox: ref.watch(dropboxServiceProvider),
  );
});
