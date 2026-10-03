import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../config/app_config.dart';
import '../models/media_item.dart';

/// Real device gallery via photo_manager.
/// Loads **all** local photos & videos (paginated under the hood).
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

  /// Loads **all** images & videos from the device (every page).
  Future<List<MediaItem>> getLocalMedia({
    int pageSize = AppConfig.localMediaPageSize,
  }) async {
    if (kIsWeb) return [];

    final ok = await requestPermission();
    if (!ok) return [];

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
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
    final total = await recent.assetCountAsync;
    if (total == 0) return [];

    final items = <MediaItem>[];
    var page = 0;
    // Fetch every page until exhausted
    while (true) {
      final assets = await recent.getAssetListPaged(page: page, size: pageSize);
      if (assets.isEmpty) break;
      for (final asset in assets) {
        items.add(_fromAsset(asset));
      }
      if (assets.length < pageSize) break;
      page++;
      // Safety cap for very large libraries
      if (items.length >= 10000) break;
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
      sizeBytes: null,
      duration: isVideo && asset.duration > 0
          ? Duration(seconds: asset.duration)
          : null,
      width: asset.width,
      height: asset.height,
      mimeType: asset.mimeType,
    );
  }

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

  /// High-quality local image for detail view (prefer origin, fallback large thumb).
  Future<Uint8List?> getFullImage(String assetId) async {
    if (kIsWeb) return null;
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    final origin = await asset.originBytes;
    if (origin != null && origin.isNotEmpty) return origin;
    return asset.thumbnailDataWithSize(
      const ThumbnailSize(2000, 2000),
      quality: 95,
    );
  }

  Future<Uint8List?> getOriginBytes(String assetId) => getFullImage(assetId);

  Future<AssetEntity?> getAsset(String assetId) async {
    if (kIsWeb) return null;
    return AssetEntity.fromId(assetId);
  }
}
