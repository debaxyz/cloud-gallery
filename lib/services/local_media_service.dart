import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';

class LocalMediaService {
  /// Request permission. Returns true if we have at least limited access.
  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  Future<bool> get hasPermission async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  /// Load recent media (images + videos) with pagination.
  Future<List<MediaItem>> loadRecent({
    int page = 0,
    int size = 60,
  }) async {
    final permitted = await requestPermission();
    if (!permitted) return [];

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
    );
    if (paths.isEmpty) return [];

    final path = paths.first;
    final entities = await path.getAssetListPaged(page: page, size: size);

    final items = <MediaItem>[];
    for (final e in entities) {
      items.add(await _toMediaItem(e));
    }
    return items;
  }

  Future<List<AssetPathEntity>> getAlbums() async {
    final permitted = await requestPermission();
    if (!permitted) return [];
    return PhotoManager.getAssetPathList(type: RequestType.common);
  }

  Future<List<MediaItem>> loadFromAlbum(
    AssetPathEntity album, {
    int page = 0,
    int size = 60,
  }) async {
    final entities = await album.getAssetListPaged(page: page, size: size);
    final items = <MediaItem>[];
    for (final e in entities) {
      items.add(await _toMediaItem(e));
    }
    return items;
  }

  Future<MediaItem> _toMediaItem(AssetEntity e) async {
    final type = e.type == AssetType.video
        ? MediaType.video
        : e.type == AssetType.image
            ? MediaType.image
            : MediaType.unknown;

    File? file;
    try {
      file = await e.file;
    } catch (_) {}

    return MediaItem(
      id: e.id,
      name: e.title ?? 'Untitled',
      type: type,
      source: MediaSource.device,
      createdAt: e.createDateTime,
      modifiedAt: e.modifiedDateTime,
      sizeBytes: await e.fileSizeBytes,
      width: e.width,
      height: e.height,
      duration: e.videoDuration,
      mimeType: e.mimeType,
      localPath: file?.path,
      thumbnailUrl: null, // use AssetEntityImageProvider in UI
      extra: {'assetEntityId': e.id},
    );
  }

  /// Save a file into the device gallery (for downloads from Drive).
  Future<AssetEntity?> saveToGallery(File file, {required bool isVideo}) async {
    if (isVideo) {
      return PhotoManager.editor.saveVideo(file, title: file.uri.pathSegments.last);
    }
    return PhotoManager.editor.saveImageWithPath(
      file.path,
      title: file.uri.pathSegments.last,
    );
  }
}

extension on AssetEntity {
  /// File size in bytes (AssetEntity.size is dart:ui Size for dimensions).
  Future<int?> get fileSizeBytes async {
    try {
      final f = await file;
      return f?.lengthSync();
    } catch (_) {
      return null;
    }
  }
}
