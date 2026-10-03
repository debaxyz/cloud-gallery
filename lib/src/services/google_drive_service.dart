import 'dart:async';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../config/app_config.dart';
import '../models/cloud_account.dart';
import '../models/media_item.dart';

/// Google Sign-In + Drive API (photos / videos).
class GoogleDriveService {
  GoogleDriveService() {
    _googleSignIn = GoogleSignIn(
      scopes: AppConfig.googleScopes,
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
  }

  late final GoogleSignIn _googleSignIn;
  GoogleSignInAccount? _account;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _account;
  bool get isSignedIn => _account != null;

  Future<CloudAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // user cancelled
      _account = account;
      await _initDriveApi();
      final about = await _driveApi!.about.get($fields: 'storageQuota,user');
      final used = int.tryParse(about.storageQuota?.usage ?? '0') ?? 0;
      final total = int.tryParse(about.storageQuota?.limit ?? '0') ?? 0;

      return CloudAccount(
        id: account.id,
        provider: CloudProvider.googleDrive,
        email: account.email,
        displayName: account.displayName ?? account.email,
        photoUrl: account.photoUrl,
        isConnected: true,
        usedBytes: used,
        totalBytes: total > 0 ? total : null,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _driveApi = null;
  }

  Future<CloudAccount?> silentSignIn() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) return null;
    _account = account;
    await _initDriveApi();
    final about = await _driveApi!.about.get($fields: 'storageQuota,user');
    final used = int.tryParse(about.storageQuota?.usage ?? '0') ?? 0;
    final total = int.tryParse(about.storageQuota?.limit ?? '0') ?? 0;
    return CloudAccount(
      id: account.id,
      provider: CloudProvider.googleDrive,
      email: account.email,
      displayName: account.displayName ?? account.email,
      photoUrl: account.photoUrl,
      isConnected: true,
      usedBytes: used,
      totalBytes: total > 0 ? total : null,
      lastSynced: DateTime.now(),
    );
  }

  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw StateError('Failed to obtain authenticated HTTP client');
    }
    _driveApi = drive.DriveApi(httpClient);
  }

  Future<List<MediaItem>> listMedia({
    String? pageToken,
    int pageSize = AppConfig.cloudMediaPageSize,
  }) async {
    if (_driveApi == null) {
      await silentSignIn();
      if (_driveApi == null) return [];
    }

    // Images + videos only, not trashed
    const q =
        "(mimeType contains 'image/' or mimeType contains 'video/') and trashed = false";

    final result = await _driveApi!.files.list(
      q: q,
      $fields:
          'nextPageToken, files(id, name, mimeType, thumbnailLink, webContentLink, size, createdTime, imageMediaMetadata, videoMediaMetadata)',
      pageSize: pageSize,
      pageToken: pageToken,
      orderBy: 'createdTime desc',
      spaces: 'drive',
    );

    final files = result.files ?? [];
    return files.map(_fileToMediaItem).toList();
  }

  MediaItem _fileToMediaItem(drive.File file) {
    final mime = file.mimeType ?? '';
    final isVideo = mime.startsWith('video/');
    final created = file.createdTime ?? DateTime.now();
    int? width;
    int? height;
    Duration? duration;

    if (file.imageMediaMetadata != null) {
      width = file.imageMediaMetadata!.width;
      height = file.imageMediaMetadata!.height;
    }
    if (file.videoMediaMetadata != null) {
      width = file.videoMediaMetadata!.width;
      height = file.videoMediaMetadata!.height;
      final ms = int.tryParse(file.videoMediaMetadata!.durationMillis ?? '');
      if (ms != null) duration = Duration(milliseconds: ms);
    }

    return MediaItem(
      id: 'gdrive_${file.id}',
      title: file.name ?? 'Untitled',
      thumbnailUrl: file.thumbnailLink,
      path: file.id,
      type: isVideo ? MediaType.video : MediaType.image,
      source: MediaSource.googleDrive,
      createdAt: created,
      sizeBytes: int.tryParse(file.size ?? ''),
      duration: duration,
      width: width,
      height: height,
      mimeType: mime,
    );
  }

  /// Download file content (for save-to-device).
  Future<Uint8List?> downloadFile(String fileId) async {
    if (_driveApi == null) return null;
    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media?;
    if (media == null) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Upload bytes to Drive (creates a new file in root or optional folder).
  Future<MediaItem?> uploadBytes({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    String? parentFolderId,
  }) async {
    if (_driveApi == null) return null;

    final fileMeta = drive.File()
      ..name = name
      ..mimeType = mimeType;
    if (parentFolderId != null) {
      fileMeta.parents = [parentFolderId];
    }

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType,
    );

    final created = await _driveApi!.files.create(
      fileMeta,
      uploadMedia: media,
      $fields:
          'id, name, mimeType, thumbnailLink, size, createdTime, imageMediaMetadata, videoMediaMetadata',
    );
    return _fileToMediaItem(created);
  }
}
