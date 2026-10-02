import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/cloud_account.dart';
import '../models/media_item.dart';

/// Scopes: drive.file keeps verification simple (only files created by the app).
/// Switch to drive.readonly / drive if you need full Drive browsing.
const _driveScopes = <String>[
  drive.DriveApi.driveFileScope,
  // Uncomment for broader access (requires extra verification):
  // drive.DriveApi.driveReadonlyScope,
];

class GoogleDriveService {
  GoogleDriveService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _driveScopes,
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  String? _appFolderId;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<CloudAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // user cancelled

      _currentUser = account;
      await _initDriveApi();
      await _ensureAppFolder();

      return CloudAccount(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        provider: 'google',
        connectedAt: DateTime.now(),
      );
    } catch (e) {
      throw GoogleDriveException('Sign-in failed: $e');
    }
  }

  Future<CloudAccount?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      _currentUser = account;
      await _initDriveApi();
      await _ensureAppFolder();
      return CloudAccount(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        provider: 'google',
        connectedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _appFolderId = null;
  }

  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
    _driveApi = null;
    _appFolderId = null;
  }

  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw GoogleDriveException('Could not obtain authenticated client');
    }
    _driveApi = drive.DriveApi(httpClient);
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

  /// List media files created by this app (or in the app folder).
  Future<List<MediaItem>> listMedia({
    int pageSize = 50,
    String? pageToken,
  }) async {
    if (_driveApi == null) throw GoogleDriveException('Not signed in');

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

    final items = <MediaItem>[];
    for (final f in response.files ?? []) {
      items.add(_fileToMediaItem(f));
    }
    return items;
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
    if (_driveApi == null) throw GoogleDriveException('Not signed in');
    await _ensureAppFolder();

    final name = customName ?? file.uri.pathSegments.last;
    final mime = _guessMime(name);

    final driveFile = drive.File()
      ..name = name
      ..parents = _appFolderId != null ? [_appFolderId!] : null;

    final media = drive.Media(file.openRead(), file.lengthSync());
    final created = await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
    );

    // Re-fetch with full metadata
    final full = await _driveApi!.files.get(
      created.id!,
      $fields:
          'id, name, mimeType, size, createdTime, modifiedTime, imageMediaMetadata, videoMediaMetadata, thumbnailLink, webContentLink, webViewLink',
    ) as drive.File;

    return _fileToMediaItem(full);
  }

  /// Download a Drive file to a temporary location.
  Future<File> downloadFile(MediaItem item) async {
    if (_driveApi == null || item.driveFileId == null) {
      throw GoogleDriveException('Cannot download');
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
    if (_driveApi == null) throw GoogleDriveException('Not signed in');
    await _driveApi!.files.delete(fileId);
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    return 'application/octet-stream';
  }
}

class GoogleDriveException implements Exception {
  final String message;
  GoogleDriveException(this.message);
  @override
  String toString() => message;
}
