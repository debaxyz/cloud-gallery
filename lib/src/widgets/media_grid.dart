import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../theme/app_theme.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<MediaItem> onTap;
  final ValueChanged<MediaItem> onLongPress;

  const MediaGrid({
    super.key,
    required this.items,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(item.id);

        return _MediaTile(
          item: item,
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          onTap: () => onTap(item),
          onLongPress: () => onLongPress(item),
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaTile({
    required this.item,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppTheme.primary, width: 3)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 7 : 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: item.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  ),
                )
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_outlined, color: Colors.grey),
                ),
              // Source badge
              Positioned(
                top: 6,
                left: 6,
                child: _SourceBadge(source: item.source),
              ),
              // Video duration
              if (item.type == MediaType.video)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          item.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Selection overlay
              if (isSelectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.primary : Colors.black38,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              // Favorite heart
              if (item.isFavorite && !isSelectionMode)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final MediaSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (source) {
      case MediaSource.local:
        color = Colors.green;
        icon = Icons.phone_android_rounded;
        break;
      case MediaSource.googleDrive:
        color = const Color(0xFF4285F4);
        icon = Icons.add_to_drive_rounded;
        break;
      case MediaSource.dropbox:
        color = const Color(0xFF0061FF);
        icon = Icons.cloud_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}
