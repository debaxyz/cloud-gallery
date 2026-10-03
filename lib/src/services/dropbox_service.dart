import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/cloud_account.dart';
import '../models/media_item.dart';

/// Dropbox OAuth2 (PKCE) + Files API.
///
/// Setup:
/// 1. Create app at https://www.dropbox.com/developers/apps
/// 2. Permission: files.content.read, files.content.write, account_info.read
/// 3. Redirect URI = AppConfig.dropboxRedirectUri
/// 4. Pass DROPBOX_APP_KEY via --dart-define
class DropboxService {
  DropboxService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  static const _tokenKey = 'dropbox_access_token';
  static const _refreshKey = 'dropbox_refresh_token';
  static const _emailKey = 'dropbox_email';
  static const _nameKey = 'dropbox_name';

  String? _accessToken;
  String? _codeVerifier;

  bool get isConnected => _accessToken != null && _accessToken!.isNotEmpty;

  Future<void> loadStoredSession() async {
    _accessToken = await _storage.read(key: _tokenKey);
  }

  /// Starts browser OAuth (PKCE). Call [handleRedirect] with the callback URI.
  Future<String> startAuth() async {
    if (AppConfig.dropboxAppKey.isEmpty) {
      throw StateError(
        'DROPBOX_APP_KEY is not set. Pass via --dart-define=DROPBOX_APP_KEY=...',
      );
    }

    _codeVerifier = _generateCodeVerifier();
    final challenge = _codeChallenge(_codeVerifier!);

    final uri = Uri.parse(AppConfig.dropboxAuthUrl).replace(queryParameters: {
      'client_id': AppConfig.dropboxAppKey,
      'response_type': 'code',
      'token_access_type': 'offline',
      'redirect_uri': AppConfig.dropboxRedirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw StateError('Could not open Dropbox auth URL');
    return uri.toString();
  }

  /// Exchange authorization code from redirect for tokens.
  Future<CloudAccount> handleRedirect(Uri redirectUri) async {
    final code = redirectUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('No authorization code in redirect');
    }
    if (_codeVerifier == null) {
      throw StateError('Missing code_verifier — call startAuth first');
    }

    final response = await _dio.post(
      AppConfig.dropboxTokenUrl,
      data: {
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': AppConfig.dropboxRedirectUri,
        'code_verifier': _codeVerifier,
        'client_id': AppConfig.dropboxAppKey,
        if (AppConfig.dropboxAppSecret.isNotEmpty)
          'client_secret': AppConfig.dropboxAppSecret,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;

    if (_accessToken == null) throw StateError('No access_token from Dropbox');

    await _storage.write(key: _tokenKey, value: _accessToken);
    if (refresh != null) {
      await _storage.write(key: _refreshKey, value: refresh);
    }

    final account = await getAccountInfo();
    return account;
  }

  Future<CloudAccount> getAccountInfo() async {
    await _ensureToken();
    final res = await _dio.post(
      '${AppConfig.dropboxApiBase}/users/get_current_account',
      options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
    );
    final data = res.data as Map<String, dynamic>;
    final email = data['email'] as String? ?? '';
    final name = (data['name'] as Map?)?['display_name'] as String? ?? email;

    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _nameKey, value: name);

    // Space usage
    int? used;
    int? allocated;
    try {
      final space = await _dio.post(
        '${AppConfig.dropboxApiBase}/users/get_space_usage',
        options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
      );
      final s = space.data as Map<String, dynamic>;
      used = s['used'] as int?;
      final allocation = s['allocation'] as Map<String, dynamic>?;
      allocated = allocation?['allocated'] as int?;
    } catch (_) {}

    return CloudAccount(
      id: data['account_id'] as String? ?? 'dropbox',
      provider: CloudProvider.dropbox,
      email: email,
      displayName: name,
      isConnected: true,
      usedBytes: used,
      totalBytes: allocated,
      lastSynced: DateTime.now(),
    );
  }

  Future<CloudAccount?> restoreSession() async {
    await loadStoredSession();
    if (!isConnected) return null;
    try {
      return await getAccountInfo();
    } catch (_) {
      await disconnect();
      return null;
    }
  }

  Future<void> disconnect() async {
    _accessToken = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nameKey);
  }

  Future<List<MediaItem>> listMedia({String path = ''}) async {
    await _ensureToken();

    final res = await _dio.post(
      '${AppConfig.dropboxApiBase}/files/list_folder',
      data: {
        'path': path,
        'recursive': true,
        'include_media_info': true,
        'limit': AppConfig.cloudMediaPageSize,
      },
      options: Options(headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      }),
    );

    final entries = (res.data['entries'] as List?) ?? [];
    final items = <MediaItem>[];

    for (final e in entries) {
      final map = e as Map<String, dynamic>;
      if (map['.tag'] != 'file') continue;
      final name = map['name'] as String? ?? '';
      final lower = name.toLowerCase();
      final isImage = lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.heic') ||
          lower.endsWith('.webp');
      final isVideo = lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.m4v') ||
          lower.endsWith('.avi');
      if (!isImage && !isVideo) continue;

      final id = map['id'] as String? ?? map['path_lower'] as String? ?? name;
      final pathDisplay = map['path_display'] as String? ?? '';
      final size = map['size'] as int?;
      final clientModified = map['client_modified'] as String?;
      DateTime created = DateTime.now();
      if (clientModified != null) {
        created = DateTime.tryParse(clientModified) ?? created;
      }

      // Temporary link for thumbnail / preview
      String? thumb;
      try {
        final linkRes = await _dio.post(
          '${AppConfig.dropboxApiBase}/files/get_temporary_link',
          data: {'path': pathDisplay.isNotEmpty ? pathDisplay : id},
          options: Options(headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          }),
        );
        thumb = linkRes.data['link'] as String?;
      } catch (_) {}

      items.add(MediaItem(
        id: 'dropbox_$id',
        title: name,
        thumbnailUrl: thumb,
        path: pathDisplay.isNotEmpty ? pathDisplay : id,
        type: isVideo ? MediaType.video : MediaType.image,
        source: MediaSource.dropbox,
        createdAt: created,
        sizeBytes: size,
      ));
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<Uint8List?> downloadFile(String path) async {
    await _ensureToken();
    final res = await _dio.post(
      '${AppConfig.dropboxContentBase}/files/download',
      options: Options(
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Dropbox-API-Arg': jsonEncode({'path': path}),
        },
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(res.data as List<int>);
  }

  Future<MediaItem?> uploadBytes({
    required String path,
    required Uint8List bytes,
    String mode = 'add',
  }) async {
    await _ensureToken();
    final res = await _dio.post(
      '${AppConfig.dropboxContentBase}/files/upload',
      data: bytes,
      options: Options(
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Dropbox-API-Arg': jsonEncode({
            'path': path,
            'mode': mode,
            'autorename': true,
            'mute': false,
          }),
          'Content-Type': 'application/octet-stream',
        },
      ),
    );
    final map = res.data as Map<String, dynamic>;
    final name = map['name'] as String? ?? path.split('/').last;
    return MediaItem(
      id: 'dropbox_${map['id']}',
      title: name,
      path: map['path_display'] as String? ?? path,
      type: MediaType.image,
      source: MediaSource.dropbox,
      createdAt: DateTime.now(),
      sizeBytes: map['size'] as int?,
    );
  }

  Future<void> _ensureToken() async {
    if (_accessToken == null) await loadStoredSession();
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw StateError('Not signed in to Dropbox');
    }
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
