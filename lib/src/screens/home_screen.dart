import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/media_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/media_grid.dart';
import '../widgets/filter_chips.dart';
import '../widgets/selection_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final selected = ref.watch(selectedMediaProvider);
    final mediaAsync = ref.watch(filteredMediaProvider);
    final filter = ref.watch(mediaFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: isSelectionMode
            ? Text('${selected.length} selected')
            : const Text('Cloud Gallery'),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(isSelectionModeProvider.notifier).state = false;
                ref.read(selectedMediaProvider.notifier).state = {};
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search coming soon')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => _showMoreMenu(context, ref),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (!isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilterChips(
                current: filter,
                onChanged: (f) {
                  ref.read(mediaFilterProvider.notifier).state = f;
                },
              ),
            ),
          Expanded(
            child: mediaAsync.when(
              loading: () => const _LoadingGrid(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Failed to load media\n$e', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(filteredMediaProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyState(filter: filter);
                }
                return MediaGrid(
                  items: items,
                  isSelectionMode: isSelectionMode,
                  selectedIds: selected,
                  onTap: (item) {
                    if (isSelectionMode) {
                      _toggleSelection(ref, item.id);
                    } else {
                      context.push('/media/${item.id}', extra: item);
                    }
                  },
                  onLongPress: (item) {
                    if (!isSelectionMode) {
                      ref.read(isSelectionModeProvider.notifier).state = true;
                      ref.read(selectedMediaProvider.notifier).state = {item.id};
                    }
                  },
                );
              },
            ),
          ),
          if (isSelectionMode && selected.isNotEmpty)
            SelectionBar(
              count: selected.length,
              onUpload: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upload to cloud started…')),
                );
                ref.read(isSelectionModeProvider.notifier).state = false;
                ref.read(selectedMediaProvider.notifier).state = {};
              },
              onDownload: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download started…')),
                );
                ref.read(isSelectionModeProvider.notifier).state = false;
                ref.read(selectedMediaProvider.notifier).state = {};
              },
              onDelete: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deleted (mock)')),
                );
                ref.read(isSelectionModeProvider.notifier).state = false;
                ref.read(selectedMediaProvider.notifier).state = {};
              },
            ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pick media to upload (connect accounts first)'),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Upload'),
            ),
    );
  }

  void _toggleSelection(WidgetRef ref, String id) {
    final current = {...ref.read(selectedMediaProvider)};
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    ref.read(selectedMediaProvider.notifier).state = current;
    if (current.isEmpty) {
      ref.read(isSelectionModeProvider.notifier).state = false;
    }
  }

  void _showMoreMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
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
            ListTile(
              leading: const Icon(Icons.select_all_rounded),
              title: const Text('Select items'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(isSelectionModeProvider.notifier).state = true;
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(ctx);
                ref.invalidate(allMediaProvider);
                ref.invalidate(localMediaProvider);
                ref.invalidate(googleDriveMediaProvider);
                ref.invalidate(dropboxMediaProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About Cloud Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                showAboutDialog(
                  context: context,
                  applicationName: 'Cloud Gallery',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Inspired by Canopas Cloud Gallery\nOpen-source Flutter project',
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: 18,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final MediaFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;
    switch (filter) {
      case MediaFilter.local:
        message = 'No local media found.\nGrant photo permission or add some photos.';
        icon = Icons.photo_outlined;
        break;
      case MediaFilter.googleDrive:
        message = 'No Google Drive media.\nConnect your account in the Accounts tab.';
        icon = Icons.cloud_outlined;
        break;
      case MediaFilter.dropbox:
        message = 'No Dropbox media.\nConnect your account in the Accounts tab.';
        icon = Icons.cloud_outlined;
        break;
      case MediaFilter.all:
        message = 'No media yet.\nConnect cloud accounts or add local photos.';
        icon = Icons.photo_library_outlined;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppTheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
