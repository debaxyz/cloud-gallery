import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../models/media_item.dart';
import '../providers/media_provider.dart';

class MediaGrid extends ConsumerWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.onTap,
    required this.onLongPress,
    this.onLoadMore,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item) onLongPress;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMediaProvider);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (onLoadMore != null &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
          onLoadMore!();
        }
        return false;
      },
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(8),
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selected.contains(item.id);

          return GestureDetector(
            onTap: () => onTap(item, index),
            onLongPress: () => onLongPress(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _Thumbnail(item: item),
                ),
                if (item.isVideo)
                  const Positioned(
                    bottom: 6,
                    right: 6,
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 22),
                  ),
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.35),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    ),
                    child: const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.check_circle, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isLocal) {
      return FutureBuilder<AssetEntity?>(
        future: AssetEntity.fromId(item.id),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            return Container(color: Colors.grey.shade300);
          }
          return AssetEntityImage(
            snap.data!,
            isOriginal: false,
            thumbnailSize: const ThumbnailSize.square(300),
            fit: BoxFit.cover,
          );
        },
      );
    }

    if (item.thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: item.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.grey.shade300),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined),
      );
    }

    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        item.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey.shade600,
      ),
    );
  }
}
