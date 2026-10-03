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
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    _account = account;
    await _initDriveApi();
    return _accountFromAbout(account);
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
    return _accountFromAbout(account);
  }

  Future<CloudAccount> _accountFromAbout(GoogleSignInAccount account) async {
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

  Future<void> _ensureApi() async {
    if (_driveApi != null) return;
    await silentSignIn();
    if (_driveApi == null) throw StateError('Not signed in to Google Drive');
  }

  /// List media; loads multiple pages so more than one batch appears.
  Future<List<MediaItem>> listMedia({
    int maxItems = 500,
  }) async {
    await _ensureApi();

    const q =
        "(mimeType contains 'image/' or mimeType contains 'video/') and trashed = false";

    final items = <MediaItem>[];
    String? pageToken;

    do {
      final result = await _driveApi!.files.list(
        q: q,
        $fields:
            'nextPageToken, files(id, name, mimeType, thumbnailLink, webContentLink, webViewLink, size, createdTime, imageMediaMetadata, videoMediaMetadata)',
        pageSize: AppConfig.cloudMediaPageSize,
        pageToken: pageToken,
        orderBy: 'createdTime desc',
        spaces: 'drive',
      );

      for (final f in result.files ?? []) {
        items.add(_fileToMediaItem(f));
      }
      pageToken = result.nextPageToken;
    } while (pageToken != null && items.length < maxItems);

    return items;
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

    // Prefer larger thumbnail: Drive often serves =s220; bump size for grid quality
    String? thumb = file.thumbnailLink;
    if (thumb != null) {
      thumb = thumb
          .replaceAll(RegExp(r'=s\d+'), '=s800')
          .replaceAll(RegExp(r'sz=\d+'), 'sz=800');
    }

    return MediaItem(
      id: 'gdrive_${file.id}',
      title: file.name ?? 'Untitled',
      thumbnailUrl: thumb,
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

  /// Download **original** file bytes (full resolution).
  Future<Uint8List?> downloadFile(String fileId) async {
    await _ensureApi();
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

  Future<MediaItem?> uploadBytes({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    String? parentFolderId,
  }) async {
    await _ensureApi();

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
