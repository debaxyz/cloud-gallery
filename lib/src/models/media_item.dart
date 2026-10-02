import 'package:flutter/foundation.dart';

enum MediaSource { local, googleDrive, dropbox }

enum MediaType { image, video }

@immutable
class MediaItem {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final String? path;
  final MediaType type;
  final MediaSource source;
  final DateTime createdAt;
  final int? sizeBytes;
  final Duration? duration;
  final int? width;
  final int? height;
  final bool isFavorite;

  const MediaItem({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.path,
    required this.type,
    required this.source,
    required this.createdAt,
    this.sizeBytes,
    this.duration,
    this.width,
    this.height,
    this.isFavorite = false,
  });

  MediaItem copyWith({
    String? id,
    String? title,
    String? thumbnailUrl,
    String? path,
    MediaType? type,
    MediaSource? source,
    DateTime? createdAt,
    int? sizeBytes,
    Duration? duration,
    int? width,
    int? height,
    bool? isFavorite,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      path: path ?? this.path,
      type: type ?? this.type,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  String get sourceLabel {
    switch (source) {
      case MediaSource.local:
        return 'Local';
      case MediaSource.googleDrive:
        return 'Google Drive';
      case MediaSource.dropbox:
        return 'Dropbox';
    }
  }

  String get formattedSize {
    if (sizeBytes == null) return '—';
    final kb = sizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    if (duration == null) return '';
    final m = duration!.inMinutes;
    final s = duration!.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
