import '../models/media_item.dart';
import 'dropbox_service.dart';
import 'google_drive_service.dart';
import 'local_media_service.dart';

/// Facade over local + Google Drive + Dropbox media sources.
class MediaService {
  MediaService({
    LocalMediaService? local,
    GoogleDriveService? drive,
    DropboxService? dropbox,
  })  : local = local ?? LocalMediaService(),
        drive = drive ?? GoogleDriveService(),
        dropbox = dropbox ?? DropboxService();

  final LocalMediaService local;
  final GoogleDriveService drive;
  final DropboxService dropbox;

  Future<List<MediaItem>> getLocalMedia() => local.getLocalMedia();

  Future<List<MediaItem>> getGoogleDriveMedia() async {
    if (!drive.isSignedIn) {
      final restored = await drive.silentSignIn();
      if (restored == null) return [];
    }
    return drive.listMedia();
  }

  Future<List<MediaItem>> getDropboxMedia() async {
    await dropbox.loadStoredSession();
    if (!dropbox.isConnected) return [];
    return dropbox.listMedia();
  }

  Future<List<MediaItem>> getAllMedia() async {
    final results = await Future.wait([
      getLocalMedia(),
      getGoogleDriveMedia(),
      getDropboxMedia(),
    ]);
    final all = results.expand((e) => e).toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }
}
