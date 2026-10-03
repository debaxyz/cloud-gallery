
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../config/app_config.dart';
import '../models/media_item.dart';

/// Real device gallery via photo_manager.
/// Requires permission (photos / storage). Web is not fully supported.
class LocalMediaService {
  bool _permissionGranted = false;

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      _permissionGranted = false;
      return false;
    }
    final state = await PhotoManager.requestPermissionExtend();
    _permissionGranted = state.isAuth || state.hasAccess;
    return _permissionGranted;
  }

  Future<bool> get hasPermission async {
    if (kIsWeb) return false;
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    _permissionGranted = state.isAuth || state.hasAccess;
    return _permissionGranted;
  }

  /// Loads recent images & videos from the device.
  Future<List<MediaItem>> getLocalMedia({
    int page = 0,
    int pageSize = AppConfig.localMediaPageSize,
  }) async {
    if (kIsWeb) return [];

    final ok = await requestPermission();
    if (!ok) return [];

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // images + videos
      onlyAll: true,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        videoOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (albums.isEmpty) return [];

    final recent = albums.first;
    final assets = await recent.getAssetListPaged(page: page, size: pageSize);

    final items = <MediaItem>[];
    for (final asset in assets) {
      items.add(_fromAsset(asset));
    }
    return items;
  }

  MediaItem _fromAsset(AssetEntity asset) {
    final isVideo = asset.type == AssetType.video;
    return MediaItem(
      id: 'local_${asset.id}',
      title: asset.title ?? (isVideo ? 'Video' : 'Photo'),
      path: asset.id,
      localAssetId: asset.id,
      type: isVideo ? MediaType.video : MediaType.image,
      source: MediaSource.local,
      createdAt: asset.createDateTime,
      sizeBytes: null, // can be filled via asset.file later if needed
      duration: isVideo && asset.duration > 0
          ? Duration(seconds: asset.duration)
          : null,
      width: asset.width,
      height: asset.height,
      mimeType: asset.mimeType,
    );
  }

  /// Thumbnail bytes for a local asset (for Image.memory / grid).
  Future<Uint8List?> getThumbnail(
    String assetId, {
    int width = 300,
    int height = 300,
  }) async {
    if (kIsWeb) return null;
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(
      ThumbnailSize(width, height),
      quality: 80,
    );
  }

  /// Full file bytes (for upload).
  Future<Uint8List?> getOriginBytes(String assetId) async {
    if (kIsWeb) return null;
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.originBytes;
  }

  Future<AssetEntity?> getAsset(String assetId) async {
    if (kIsWeb) return null;
    return AssetEntity.fromId(assetId);
  }
}
