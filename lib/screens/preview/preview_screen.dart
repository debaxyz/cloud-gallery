import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/media_item.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MediaItem> items;
  final int initialIndex;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          item.name,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/details', extra: item),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final m = widget.items[i];
          if (m.isVideo) {
            return _VideoPreview(item: m);
          }
          return _ImagePreview(item: m);
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isLocal && item.extra?['assetEntityId'] != null) {
      // Use photo_manager provider for local assets
      return FutureBuilder<AssetEntity?>(
        future: AssetEntity.fromId(item.id),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return InteractiveViewer(
            child: AssetEntityImage(
              snap.data!,
              isOriginal: true,
              fit: BoxFit.contain,
            ),
          );
        },
      );
    }

    if (item.thumbnailUrl != null || item.webContentLink != null) {
      final url = item.webContentLink ?? item.thumbnailUrl!;
      return InteractiveViewer(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      );
    }

    return const Center(
      child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.item});

  final MediaItem item;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.item.isLocal && widget.item.localPath != null) {
        _controller = VideoPlayerController.file(File(widget.item.localPath!));
      } else if (widget.item.webContentLink != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.item.webContentLink!),
        );
      } else {
        setState(() => _error = 'No playable source');
        return;
      }
      await _controller!.initialize();
      _chewie = ChewieController(
        videoPlayerController: _controller!,
        autoPlay: true,
        looping: false,
        aspectRatio: _controller!.value.aspectRatio,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (_chewie == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: _chewie!);
  }
}
