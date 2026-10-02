import 'dart:math';

import '../models/media_item.dart';

/// Mock media service that generates realistic sample data.
/// On real devices you can swap this with photo_manager + Drive/Dropbox APIs.
class MediaService {
  static final _random = Random(42);

  static final List<String> _sampleImageUrls = [
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600',
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600',
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600',
    'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=600',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
    'https://images.unsplash.com/photo-1475924156734-496f6aca89fc?w=600',
    'https://images.unsplash.com/photo-1433086966358-54859d0ed716?w=600',
    'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=600',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600',
    'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=600',
    'https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=600',
    'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=600',
    'https://images.unsplash.com/photo-1465146633011-14f8e0781093?w=600',
    'https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=600',
    'https://images.unsplash.com/photo-1493246507139-91e8fad9978e?w=600',
    'https://images.unsplash.com/photo-1510798831973-525d619b3a66?w=600',
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=600',
    'https://images.unsplash.com/photo-1418065460487-3e41a6c84dc5?w=600',
    'https://images.unsplash.com/photo-1482192505345-5655af888cc4?w=600',
  ];

  Future<List<MediaItem>> getLocalMedia() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _generateItems(MediaSource.local, 24);
  }

  Future<List<MediaItem>> getGoogleDriveMedia() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _generateItems(MediaSource.googleDrive, 16);
  }

  Future<List<MediaItem>> getDropboxMedia() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return _generateItems(MediaSource.dropbox, 12);
  }

  Future<List<MediaItem>> getAllMedia() async {
    final results = await Future.wait([
      getLocalMedia(),
      getGoogleDriveMedia(),
      getDropboxMedia(),
    ]);
    final all = results.expand((e) => e).toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  List<MediaItem> _generateItems(MediaSource source, int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final isVideo = _random.nextDouble() < 0.18;
      final url = _sampleImageUrls[i % _sampleImageUrls.length];
      final daysAgo = _random.nextInt(90);
      final created = now.subtract(Duration(days: daysAgo, hours: _random.nextInt(24)));

      return MediaItem(
        id: '${source.name}_$i',
        title: isVideo ? 'Video ${i + 1}' : 'Photo ${i + 1}',
        thumbnailUrl: url,
        path: url,
        type: isVideo ? MediaType.video : MediaType.image,
        source: source,
        createdAt: created,
        sizeBytes: isVideo
            ? 8 * 1024 * 1024 + _random.nextInt(40 * 1024 * 1024)
            : 800 * 1024 + _random.nextInt(4 * 1024 * 1024),
        duration: isVideo ? Duration(seconds: 15 + _random.nextInt(180)) : null,
        width: 1200 + _random.nextInt(800),
        height: 800 + _random.nextInt(600),
        isFavorite: _random.nextDouble() < 0.12,
      );
    });
  }
}
