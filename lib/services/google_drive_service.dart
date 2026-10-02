import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

import '../models/media_item.dart';
import 'auth_service.dart';

/// Google Drive operations.
///
/// Uses the same [GoogleSignIn] instance from [AuthService] so Drive scopes
/// granted at sign-in are available. Do NOT use Firebase ID tokens for Drive.
class GoogleDriveService {
  GoogleDriveService(this._authService);

  final AuthService _authService;

  drive.DriveApi? _driveApi;
  String? _appFolderId;

  GoogleSignIn get _googleSignIn => _authService.googleSignIn;

  bool get isReady => _driveApi != null;

  Future<void> ensureInitialized() async {
    if (_driveApi != null) return;
    await _initDriveApi();
    await _ensureAppFolder();
  }

  Future<void> _initDriveApi() async {
    // Requires google_sign_in session with Drive scopes (set in AuthService).
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw GoogleDriveException(
        'Not signed in with Google, or Drive scope missing. Sign in again.',
      );
    }
    _driveApi = drive.DriveApi(httpClient);
  }

  void reset() {
    _driveApi = null;
    _appFolderId = null;
  }

  /// Creates (or finds) a folder named "Cloud Gallery" in the user's Drive.
  Future<void> _ensureAppFolder() async {
    if (_driveApi == null) return;
    const folderName = 'Cloud Gallery';

    final result = await _driveApi!.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      _appFolderId = result.files!.first.id;
      return;
    }

    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _driveApi!.files.create(folder);
    _appFolderId = created.id;
  }

  /// List media files in the app folder.
  Future<List<MediaItem>> listMedia({
    int pageSize = 50,
    String? pageToken,
  }) async {
    await ensureInitialized();

    final q = _appFolderId != null
        ? "'$_appFolderId' in parents and trashed = false and (mimeType contains 'image/' or mimeType contains 'video/')"
        : "trashed = false and (mimeType contains 'image/' or mimeType contains 'video/')";

    final response = await _driveApi!.files.list(
      q: q,
      pageSize: pageSize,
      pageToken: pageToken,
      $fields:
          'nextPageToken, files(id, name, mimeType, size, createdTime, modifiedTime, imageMediaMetadata, videoMediaMetadata, thumbnailLink, webContentLink, webViewLink)',
      orderBy: 'modifiedTime desc',
    );

    return (response.files ?? []).map(_fileToMediaItem).toList();
  }

  MediaItem _fileToMediaItem(drive.File f) {
    final mime = f.mimeType ?? '';
    final type = mime.startsWith('image/')
        ? MediaType.image
        : mime.startsWith('video/')
            ? MediaType.video
            : MediaType.unknown;

    int? width, height;
    Duration? duration;
    if (f.imageMediaMetadata != null) {
      width = f.imageMediaMetadata!.width;
      height = f.imageMediaMetadata!.height;
    }
    if (f.videoMediaMetadata != null) {
      width = f.videoMediaMetadata!.width;
      height = f.videoMediaMetadata!.height;
      final ms = f.videoMediaMetadata!.durationMillis;
      if (ms != null) {
        duration = Duration(milliseconds: int.tryParse(ms) ?? 0);
      }
    }

    return MediaItem(
      id: f.id ?? '',
      name: f.name ?? 'Untitled',
      type: type,
      source: MediaSource.googleDrive,
      createdAt: f.createdTime,
      modifiedAt: f.modifiedTime,
      sizeBytes: int.tryParse(f.size ?? ''),
      width: width,
      height: height,
      duration: duration,
      mimeType: mime,
      thumbnailUrl: f.thumbnailLink,
      driveFileId: f.id,
      webContentLink: f.webContentLink,
      webViewLink: f.webViewLink,
    );
  }

  /// Upload a local file into the app folder.
  Future<MediaItem> uploadFile(File file, {String? customName}) async {
    await ensureInitialized();
    await _ensureAppFolder();

    final name = customName ?? file.uri.pathSegments.last;

    final driveFile = drive.File()
      ..name = name
      ..parents = _appFolderId != null ? [_appFolderId!] : null;

    final media = drive.Media(file.openRead(), file.lengthSync());
    final created = await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
    );

    final full = await _driveApi!.files.get(
      created.id!,
      $fields:
          'id, name, mimeType, size, createdTime, modifiedTime, imageMediaMetadata, videoMediaMetadata, thumbnailLink, webContentLink, webViewLink',
    ) as drive.File;

    return _fileToMediaItem(full);
  }

  /// Download a Drive file to a temporary location.
  Future<File> downloadFile(MediaItem item) async {
    await ensureInitialized();
    if (item.driveFileId == null) {
      throw GoogleDriveException('Cannot download: missing file id');
    }

    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/${item.name}';
    final file = File(savePath);

    final response = await _driveApi!.files.get(
      item.driveFileId!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final sink = file.openWrite();
    await response.stream.pipe(sink);
    await sink.close();
    return file;
  }

  Future<void> deleteFile(String fileId) async {
    await ensureInitialized();
    await _driveApi!.files.delete(fileId);
  }
}

class GoogleDriveException implements Exception {
  GoogleDriveException(this.message);
  final String message;

  @override
  String toString() => message;
}
