import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

import '../models/media_item.dart';

/// Google Drive connection (optional). Independent of Firebase Email auth.
class GoogleDriveService {
  GoogleDriveService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[drive.DriveApi.driveFileScope],
  );

  drive.DriveApi? _driveApi;
  String? _appFolderId;
  GoogleSignInAccount? _account;

  GoogleSignInAccount? get googleAccount => _account;
  bool get isConnected => _account != null;

  Future<GoogleSignInAccount?> connect() async {
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      _account = account;
      await _initDriveApi();
      await _ensureAppFolder();
      return account;
    } catch (e) {
      _account = null;
      _driveApi = null;
      throw GoogleDriveException('Could not connect Google Drive: $e');
    }
  }

  Future<bool> connectSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;
      _account = account;
      await _initDriveApi();
      await _ensureAppFolder();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }
    reset();
  }

  void reset() {
    _driveApi = null;
    _appFolderId = null;
    _account = null;
  }

  Future<void> ensureInitialized() async {
    if (_driveApi != null) return;
    if (_googleSignIn.currentUser == null) {
      final ok = await connectSilently();
      if (!ok) throw GoogleDriveException('Google Drive is not connected');
      return;
    }
    _account = _googleSignIn.currentUser;
    await _initDriveApi();
    await _ensureAppFolder();
  }

  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw GoogleDriveException('Could not get Drive credentials');
    }
    _driveApi = drive.DriveApi(httpClient);
  }

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

  Future<List<MediaItem>> listMedia({int pageSize = 50, String? pageToken}) async {
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

  Future<MediaItem> uploadFile(File file, {String? customName}) async {
    await ensureInitialized();
    await _ensureAppFolder();
    final name = customName ?? file.uri.pathSegments.last;
    final driveFile = drive.File()
      ..name = name
      ..parents = _appFolderId != null ? [_appFolderId!] : null;
    final media = drive.Media(file.openRead(), file.lengthSync());
    final created = await _driveApi!.files.create(driveFile, uploadMedia: media);
    final full = await _driveApi!.files.get(
      created.id!,
      $fields:
          'id, name, mimeType, size, createdTime, modifiedTime, imageMediaMetadata, videoMediaMetadata, thumbnailLink, webContentLink, webViewLink',
    ) as drive.File;
    return _fileToMediaItem(full);
  }

  Future<File> downloadFile(MediaItem item) async {
    await ensureInitialized();
    if (item.driveFileId == null) {
      throw GoogleDriveException('Cannot download: missing file id');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${item.name}');
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
