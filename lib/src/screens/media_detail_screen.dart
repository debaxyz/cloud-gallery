import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/media_item.dart';
import '../providers/services_providers.dart';

/// Full-screen viewer with swipe slideshow for Local + Drive (+ Dropbox).
class MediaDetailScreen extends ConsumerStatefulWidget {
  final MediaItem media;
  final List<MediaItem> gallery;
  final int initialIndex;

  const MediaDetailScreen({
    super.key,
    required this.media,
    this.gallery = const [],
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  late PageController _pageController;
  late int _index;
  bool _slideshow = false;
  Timer? _slideshowTimer;
  bool _showUi = true;

  List<MediaItem> get _items {
    if (widget.gallery.isNotEmpty) return widget.gallery;
    return [widget.media];
  }

  MediaItem get _current => _items[_index.clamp(0, _items.length - 1)];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, (_items.length - 1).clamp(0, 999999));
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSlideshow() {
    setState(() => _slideshow = !_slideshow);
    _slideshowTimer?.cancel();
    if (_slideshow) {
      _slideshowTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted || _items.isEmpty) return;
        final next = (_index + 1) % _items.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final media = _current;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showUi
          ? AppBar(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                media.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (_items.length > 1)
                  IconButton(
                    tooltip: _slideshow ? 'Stop slideshow' : 'Slideshow',
                    icon: Icon(
                      _slideshow ? Icons.pause_circle_outline : Icons.slideshow_rounded,
                    ),
                    onPressed: _toggleSlideshow,
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => _showActions(context),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showUi = !_showUi),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(child: _FullImage(item: _items[i])),
                );
              },
            ),
            if (_showUi && _items.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_index + 1} / ${_items.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            if (_showUi)
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_circle_fill,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                media.formattedDuration.isEmpty
                                    ? 'Video'
                                    : media.formattedDuration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _InfoRow(label: 'Source', value: media.sourceLabel),
                      _InfoRow(
                          label: 'Date',
                          value: dateFormat.format(media.createdAt)),
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
      ),
    );
  }

  void _showActions(BuildContext context) {
    final media = _current;
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
                  await _uploadToCloud(context);
                },
              ),
            if (media.isCloud)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download original'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _download(context);
                },
              ),
            if (_items.length > 1)
              ListTile(
                leading: Icon(
                  _slideshow ? Icons.pause_rounded : Icons.slideshow_rounded,
                ),
                title: Text(_slideshow ? 'Stop slideshow' : 'Start slideshow'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleSlideshow();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadToCloud(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final media = _current;
    try {
      if (media.localAssetId == null) return;
      final bytes = await ref
          .read(localMediaServiceProvider)
          .getOriginBytes(media.localAssetId!);
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not read file')));
        return;
      }
      final mime = media.mimeType ?? 'image/jpeg';
      final name =
          media.title.contains('.') ? media.title : '${media.title}.jpg';

      final drive = ref.read(googleDriveServiceProvider);
      if (drive.isSignedIn) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Uploading to Google Drive…')));
        await drive.uploadBytes(name: name, bytes: bytes, mimeType: mime);
        messenger.showSnackBar(
            const SnackBar(content: Text('Uploaded to Google Drive')));
        return;
      }

      final dropbox = ref.read(dropboxServiceProvider);
      await dropbox.loadStoredSession();
      if (dropbox.isConnected) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Uploading to Dropbox…')));
        await dropbox.uploadBytes(path: '/$name', bytes: bytes);
        messenger.showSnackBar(const SnackBar(content: Text('Uploaded to Dropbox')));
        return;
      }

      messenger.showSnackBar(
          const SnackBar(content: Text('Connect a cloud account first')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final media = _current;
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Downloading original…')));
      Uint8List? bytes;
      if (media.source == MediaSource.googleDrive && media.path != null) {
        bytes =
            await ref.read(googleDriveServiceProvider).downloadFile(media.path!);
      } else if (media.source == MediaSource.dropbox && media.path != null) {
        bytes = await ref.read(dropboxServiceProvider).downloadFile(media.path!);
      }
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Download failed')));
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Original downloaded (${media.formattedSize})')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }
}

/// Loads **original** resolution for Local + Drive (not just thumbnail).
class _FullImage extends ConsumerWidget {
  final MediaItem item;

  const _FullImage({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Local → original bytes
    if (item.isLocal && item.localAssetId != null) {
      return FutureBuilder<Uint8List?>(
        future: ref.read(localMediaServiceProvider).getFullImage(item.localAssetId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading(item);
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            );
          }
          return const Icon(Icons.broken_image_rounded,
              size: 80, color: Colors.white38);
        },
      );
    }

    // Google Drive → download original (not thumbnail)
    if (item.source == MediaSource.googleDrive && item.path != null) {
      return FutureBuilder<Uint8List?>(
        future: ref.read(googleDriveServiceProvider).downloadFile(item.path!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading(item);
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            );
          }
          // Fallback to network thumbnail if download fails
          if (item.thumbnailUrl != null) {
            return CachedNetworkImage(
              imageUrl: item.thumbnailUrl!,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image_rounded,
                size: 80,
                color: Colors.white38,
              ),
            );
          }
          return const Icon(Icons.broken_image_rounded,
              size: 80, color: Colors.white38);
        },
      );
    }

    // Dropbox / other → temporary link or thumbnail
    if (item.thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: item.thumbnailUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) => _loading(item),
        errorWidget: (_, __, ___) => const Icon(
          Icons.broken_image_rounded,
          size: 80,
          color: Colors.white38,
        ),
      );
    }

    return const Icon(Icons.image_not_supported, size: 80, color: Colors.white38);
  }

  Widget _loading(MediaItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.thumbnailUrl != null)
          SizedBox(
            width: 120,
            height: 120,
            child: CachedNetworkImage(
              imageUrl: item.thumbnailUrl!,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(color: Colors.white54),
        const SizedBox(height: 12),
        const Text(
          'Loading original…',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
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
