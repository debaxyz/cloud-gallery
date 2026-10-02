import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../services/google_drive_service.dart';
import '../services/local_media_service.dart';

final localMediaServiceProvider = Provider<LocalMediaService>((ref) {
  return LocalMediaService();
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

/// Whether Google Drive OAuth is connected (separate from Firebase email auth).
final driveConnectedProvider =
    StateNotifierProvider<DriveConnectedNotifier, bool>((ref) {
  return DriveConnectedNotifier(ref);
});

class DriveConnectedNotifier extends StateNotifier<bool> {
  DriveConnectedNotifier(this._ref) : super(false) {
    _trySilent();
  }

  final Ref _ref;

  Future<void> _trySilent() async {
    final ok =
        await _ref.read(googleDriveServiceProvider).connectSilently();
    state = ok;
  }

  Future<bool> connect() async {
    final account = await _ref.read(googleDriveServiceProvider).connect();
    state = account != null;
    return state;
  }

  Future<void> disconnect() async {
    await _ref.read(googleDriveServiceProvider).disconnect();
    state = false;
  }
}

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
    } finally {
      _loadingMore = false;
    }
  }
}

final driveMediaProvider =
    StateNotifierProvider<DriveMediaNotifier, AsyncValue<List<MediaItem>>>(
        (ref) {
  return DriveMediaNotifier(ref);
});

class DriveMediaNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  DriveMediaNotifier(this._ref) : super(const AsyncValue.data([])) {
    _ref.listen(driveConnectedProvider, (prev, next) {
      if (next) {
        load(refresh: true);
      } else {
        state = const AsyncValue.data([]);
      }
    });
  }

  final Ref _ref;

  Future<void> load({bool refresh = false}) async {
    if (!_ref.read(driveConnectedProvider)) {
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
      } catch (_) {}
    }
    await load(refresh: true);
    return success;
  }

  Future<int> download(List<MediaItem> driveItems) async {
    final drive = _ref.read(googleDriveServiceProvider);
    final local = _ref.read(localMediaServiceProvider);
    var success = 0;
    for (final item in driveItems) {
      try {
        final file = await drive.downloadFile(item);
        await local.saveToGallery(file, isVideo: item.isVideo);
        success++;
      } catch (_) {}
    }
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

final homeTabProvider = StateProvider<int>((ref) => 0);
