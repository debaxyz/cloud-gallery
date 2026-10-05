import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../providers/services_providers.dart';
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
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space12,
        0,
        AppTheme.space12,
        100,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
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

class _MediaTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryAccent
                : (isDark ? const Color(0xFF374151) : AppTheme.border),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isDark ? null : AppTheme.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            isSelected ? AppTheme.radiusSm - 1.5 : AppTheme.radiusSm,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumbnail(item: item),
              Positioned(
                top: 6,
                left: 6,
                child: _SourceBadge(source: item.source),
              ),
              if (item.type == MediaType.video)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          item.formattedDuration.isEmpty
                              ? 'Video'
                              : item.formattedDuration,
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
              if (isSelectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.primaryAccent
                          : Colors.black.withValues(alpha: 0.35),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              if (item.isFavorite && !isSelectionMode)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  final MediaItem item;

  const _Thumbnail({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = Container(
      color: isDark ? const Color(0xFF2A2E38) : AppTheme.cardSoft,
    );

    if (item.isLocal && item.localAssetId != null) {
      return FutureBuilder<Uint8List?>(
        future: ref
            .read(localMediaServiceProvider)
            .getThumbnail(item.localAssetId!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          }
          return placeholder;
        },
      );
    }

    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => Container(
          color: isDark ? const Color(0xFF2A2E38) : AppTheme.cardSoft,
          child: Icon(
            Icons.broken_image_outlined,
            color: AppTheme.textMuted,
            size: AppTheme.iconMd,
          ),
        ),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF2A2E38) : AppTheme.cardSoft,
      child: Icon(
        Icons.image_outlined,
        color: AppTheme.textMuted,
        size: AppTheme.iconMd,
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final MediaSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late IconData icon;
    switch (source) {
      case MediaSource.local:
        color = const Color(0xFF10B981);
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
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        boxShadow: AppTheme.softShadow,
      ),
      child: Icon(icon, size: 11, color: Colors.white),
    );
  }
}
