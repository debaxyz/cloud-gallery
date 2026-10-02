import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../services/local_media_service.dart';
import 'auth_provider.dart';

final localMediaServiceProvider = Provider<LocalMediaService>((ref) {
  return LocalMediaService();
});

/// Currently selected media items (for multi-select actions).
final selectedMediaProvider =
    StateNotifierProvider<SelectedMediaNotifier, Set<String>>((ref) {
  return SelectedMediaNotifier();
});

class SelectedMediaNotifier extends StateNotifier<Set<String>> {
  SelectedMediaNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  void clear() => state = {};

  void selectAll(Iterable<String> ids) => state = ids.toSet();

  bool isSelected(String id) => state.contains(id);
}

/// Device media list with simple pagination.
final deviceMediaProvider =
    StateNotifierProvider<DeviceMediaNotifier, AsyncValue<List<MediaItem>>>(
        (ref) {
  return DeviceMediaNotifier(ref);
});

class DeviceMediaNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  DeviceMediaNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  LocalMediaService get _local => _ref.read(localMediaServiceProvider);

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
      state = const AsyncValue.loading();
    }
    try {
      final items = await _local.loadRecent(page: _page, size: 60);
      _hasMore = items.length >= 60;
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      _page++;
      final more = await _local.loadRecent(page: _page, size: 60);
      _hasMore = more.length >= 60;
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, ...more]);
    } catch (_) {
      // keep existing data on partial failure
    } finally {
      _loadingMore = false;
    }
  }
}

/// Google Drive media list.
final driveMediaProvider =
    StateNotifierProvider<DriveMediaNotifier, AsyncValue<List<MediaItem>>>(
        (ref) {
  return DriveMediaNotifier(ref);
});

class DriveMediaNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  DriveMediaNotifier(this._ref) : super(const AsyncValue.data([])) {
    // Reload when auth changes
    _ref.listen(authStateProvider, (prev, next) {
      if (next.valueOrNull != null) {
        load(refresh: true);
      } else {
        state = const AsyncValue.data([]);
      }
    });
  }

  final Ref _ref;

  Future<void> load({bool refresh = false}) async {
    final signedIn = _ref.read(isSignedInProvider);
    if (!signedIn) {
      state = const AsyncValue.data([]);
      return;
    }
    if (refresh) state = const AsyncValue.loading();
    try {
      final drive = _ref.read(googleDriveServiceProvider);
      final items = await drive.listMedia();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Upload local media items to the Cloud Gallery folder on Drive.
  Future<int> upload(List<MediaItem> localItems) async {
    final drive = _ref.read(googleDriveServiceProvider);
    var success = 0;

    for (final item in localItems) {
      if (item.localPath == null) continue;
      final file = File(item.localPath!);
      if (!await file.exists()) continue;
      try {
        await drive.uploadFile(file, customName: item.name);
        success++;
      } catch (_) {
        // continue with remaining files
      }
    }

    await load(refresh: true);
    return success;
  }

  /// Download Drive items and save them into the device gallery.
  Future<int> download(List<MediaItem> driveItems) async {
    final drive = _ref.read(googleDriveServiceProvider);
    final local = _ref.read(localMediaServiceProvider);
    var success = 0;

    for (final item in driveItems) {
      try {
        final file = await drive.downloadFile(item);
        await local.saveToGallery(file, isVideo: item.isVideo);
        success++;
      } catch (_) {
        // continue with remaining files
      }
    }

    // Refresh device list so newly saved items appear
    await _ref.read(deviceMediaProvider.notifier).load(refresh: true);
    return success;
  }

  Future<void> delete(List<MediaItem> items) async {
    final drive = _ref.read(googleDriveServiceProvider);
    for (final item in items) {
      if (item.driveFileId == null) continue;
      try {
        await drive.deleteFile(item.driveFileId!);
      } catch (_) {}
    }
    await load(refresh: true);
  }
}

/// Active tab: 0 = Device, 1 = Drive
final homeTabProvider = StateProvider<int>((ref) => 0);
