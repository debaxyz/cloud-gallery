import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/media_item.dart';
import '../providers/services_providers.dart';

class MediaDetailScreen extends ConsumerWidget {
  final MediaItem media;

  const MediaDetailScreen({super.key, required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          media.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showActions(context, ref),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(child: _buildPreview(ref)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                40,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (media.type == MediaType.video)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            media.formattedDuration.isEmpty ? 'Video' : media.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _InfoRow(label: 'Source', value: media.sourceLabel),
                  _InfoRow(label: 'Date', value: dateFormat.format(media.createdAt)),
                  _InfoRow(label: 'Size', value: media.formattedSize),
                  if (media.width != null && media.height != null)
                    _InfoRow(
                      label: 'Resolution',
                      value: '${media.width} × ${media.height}',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(WidgetRef ref) {
    if (media.isLocal && media.localAssetId != null) {
      return FutureBuilder<Uint8List?>(
        future: ref.read(localMediaServiceProvider).getOriginBytes(media.localAssetId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator(color: Colors.white54);
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.contain);
          }
          // Fallback to thumbnail
          return FutureBuilder<Uint8List?>(
            future: ref.read(localMediaServiceProvider).getThumbnail(
                  media.localAssetId!,
                  width: 1200,
                  height: 1200,
                ),
            builder: (context, snap) {
              if (snap.hasData && snap.data != null) {
                return Image.memory(snap.data!, fit: BoxFit.contain);
              }
              return const Icon(Icons.broken_image_rounded, size: 80, color: Colors.white38);
            },
          );
        },
      );
    }

    if (media.thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: media.thumbnailUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const CircularProgressIndicator(color: Colors.white54),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image_rounded, size: 80, color: Colors.white38),
      );
    }

    return const Icon(Icons.image_not_supported, size: 80, color: Colors.white38);
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (media.isLocal)
              ListTile(
                leading: const Icon(Icons.cloud_upload_rounded),
                title: const Text('Upload to cloud'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _uploadToCloud(context, ref);
                },
              ),
            if (media.isCloud)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download to device'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _download(context, ref);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Use platform share sheet (add share_plus)')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadToCloud(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (media.localAssetId == null) return;
      final bytes =
          await ref.read(localMediaServiceProvider).getOriginBytes(media.localAssetId!);
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not read file')));
        return;
      }
      final mime = media.mimeType ?? 'image/jpeg';
      final name = media.title.contains('.') ? media.title : '${media.title}.jpg';

      // Prefer Google Drive if signed in
      final drive = ref.read(googleDriveServiceProvider);
      if (drive.isSignedIn) {
        messenger.showSnackBar(const SnackBar(content: Text('Uploading to Google Drive…')));
        await drive.uploadBytes(name: name, bytes: bytes, mimeType: mime);
        messenger.showSnackBar(
          const SnackBar(content: Text('Uploaded to Google Drive')),
        );
        return;
      }

      final dropbox = ref.read(dropboxServiceProvider);
      await dropbox.loadStoredSession();
      if (dropbox.isConnected) {
        messenger.showSnackBar(const SnackBar(content: Text('Uploading to Dropbox…')));
        await dropbox.uploadBytes(path: '/$name', bytes: bytes);
        messenger.showSnackBar(const SnackBar(content: Text('Uploaded to Dropbox')));
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Connect a cloud account first')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Downloading…')));
      Uint8List? bytes;
      if (media.source == MediaSource.googleDrive && media.path != null) {
        bytes = await ref.read(googleDriveServiceProvider).downloadFile(media.path!);
      } else if (media.source == MediaSource.dropbox && media.path != null) {
        bytes = await ref.read(dropboxServiceProvider).downloadFile(media.path!);
      }
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Download failed')));
        return;
      }
      // Production: save via path_provider + gallery_saver / photo_manager
      messenger.showSnackBar(
        SnackBar(content: Text('Downloaded ${bytes.length} bytes (save to gallery next)')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
