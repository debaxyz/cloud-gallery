enum MediaSource { device, googleDrive }

enum MediaType { image, video, unknown }

class MediaItem {
  final String id;
  final String name;
  final MediaType type;
  final MediaSource source;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final Duration? duration;
  final String? mimeType;
  final String? thumbnailUrl; // network or local path
  final String? localPath; // for device items
  final String? driveFileId; // for Drive items
  final String? webContentLink;
  final String? webViewLink;
  final Map<String, dynamic>? extra;

  const MediaItem({
    required this.id,
    required this.name,
    required this.type,
    required this.source,
    this.createdAt,
    this.modifiedAt,
    this.sizeBytes,
    this.width,
    this.height,
    this.duration,
    this.mimeType,
    this.thumbnailUrl,
    this.localPath,
    this.driveFileId,
    this.webContentLink,
    this.webViewLink,
    this.extra,
  });

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;
  bool get isLocal => source == MediaSource.device;
  bool get isCloud => source == MediaSource.googleDrive;

  String get formattedSize {
    if (sizeBytes == null) return '—';
    final kb = sizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  String get resolution {
    if (width == null || height == null) return '—';
    return '${width}×$height';
  }

  MediaItem copyWith({
    String? id,
    String? name,
    MediaType? type,
    MediaSource? source,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? sizeBytes,
    int? width,
    int? height,
    Duration? duration,
    String? mimeType,
    String? thumbnailUrl,
    String? localPath,
    String? driveFileId,
    String? webContentLink,
    String? webViewLink,
    Map<String, dynamic>? extra,
  }) {
    return MediaItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      mimeType: mimeType ?? this.mimeType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localPath: localPath ?? this.localPath,
      driveFileId: driveFileId ?? this.driveFileId,
      webContentLink: webContentLink ?? this.webContentLink,
      webViewLink: webViewLink ?? this.webViewLink,
      extra: extra ?? this.extra,
    );
  }
}
