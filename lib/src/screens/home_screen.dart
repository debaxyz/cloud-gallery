import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../providers/media_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/media_grid.dart';
import '../widgets/filter_chips.dart';
import '../widgets/selection_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _driveRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh Google Drive every 2 minutes
    _driveRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      final filter = ref.read(mediaFilterProvider);
      if (filter == MediaFilter.googleDrive || filter == MediaFilter.all) {
        ref.invalidate(googleDriveMediaProvider);
        ref.invalidate(allMediaProvider);
      }
    });
  }

  @override
  void dispose() {
    _driveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleTheme() async {
    final isDark = ref.read(themeModeProvider);
    final next = !isDark;
    ref.read(themeModeProvider.notifier).state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await setDarkMode(prefs, next);
  }

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final selected = ref.watch(selectedMediaProvider);
    final mediaAsync = ref.watch(filteredMediaProvider);
    final filter = ref.watch(mediaFilterProvider);
    final isDark = ref.watch(themeModeProvider);

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
            // Day / Night theme toggle
            IconButton(
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
              onPressed: _toggleTheme,
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(localMediaProvider);
                ref.invalidate(googleDriveMediaProvider);
                ref.invalidate(dropboxMediaProvider);
                ref.invalidate(allMediaProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing…'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => _showMoreMenu(context),
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
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Failed to load media\n$e', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(localMediaProvider);
                        ref.invalidate(googleDriveMediaProvider);
                        ref.invalidate(dropboxMediaProvider);
                        ref.invalidate(allMediaProvider);
                      },
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
                      _toggleSelection(item.id);
                    } else {
                      final index = items.indexWhere((e) => e.id == item.id);
                      context.push(
                        '/media/${item.id}',
                        extra: {
                          'media': item,
                          'gallery': items,
                          'index': index < 0 ? 0 : index,
                        },
                      );
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
                  const SnackBar(content: Text('Deleted')),
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

  void _toggleSelection(String id) {
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

  void _showMoreMenu(BuildContext context) {
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
              title: const Text('Refresh all'),
              onTap: () {
                Navigator.pop(ctx);
                ref.invalidate(allMediaProvider);
                ref.invalidate(localMediaProvider);
                ref.invalidate(googleDriveMediaProvider);
                ref.invalidate(dropboxMediaProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_rounded),
              title: const Text('Refresh Google Drive now'),
              onTap: () {
                Navigator.pop(ctx);
                ref.invalidate(googleDriveMediaProvider);
                ref.invalidate(allMediaProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Google Drive refreshed')),
                );
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
                  applicationLegalese: 'Local + Google Drive + Dropbox',
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
        message =
            'No local media found.\nGrant photo permission in system settings.';
        icon = Icons.photo_outlined;
        break;
      case MediaFilter.googleDrive:
        message =
            'No Google Drive media.\nConnect Google Drive in the Accounts tab.';
        icon = Icons.cloud_outlined;
        break;
      case MediaFilter.dropbox:
        message =
            'No Dropbox media.\nConnect Dropbox in the Accounts tab.';
        icon = Icons.cloud_outlined;
        break;
      case MediaFilter.all:
        message =
            'No media yet.\nAllow photo access or connect a cloud account.';
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
