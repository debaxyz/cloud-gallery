import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import 'services_providers.dart';

final localMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.watch(mediaServiceProvider).getLocalMedia();
});

final googleDriveMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.watch(mediaServiceProvider).getGoogleDriveMedia();
});

final dropboxMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.watch(mediaServiceProvider).getDropboxMedia();
});

final allMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.watch(mediaServiceProvider).getAllMedia();
});

final selectedMediaProvider = StateProvider<Set<String>>((ref) => {});

final isSelectionModeProvider = StateProvider<bool>((ref) => false);

enum MediaFilter { all, local, googleDrive, dropbox }

final mediaFilterProvider = StateProvider<MediaFilter>((ref) => MediaFilter.all);

final filteredMediaProvider = Provider<AsyncValue<List<MediaItem>>>((ref) {
  final filter = ref.watch(mediaFilterProvider);
  switch (filter) {
    case MediaFilter.all:
      return ref.watch(allMediaProvider);
    case MediaFilter.local:
      return ref.watch(localMediaProvider);
    case MediaFilter.googleDrive:
      return ref.watch(googleDriveMediaProvider);
    case MediaFilter.dropbox:
      return ref.watch(dropboxMediaProvider);
  }
});

final localPermissionProvider = FutureProvider<bool>((ref) async {
  return ref.watch(localMediaServiceProvider).requestPermission();
});
