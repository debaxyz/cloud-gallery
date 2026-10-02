import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/prefs_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/selection_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final last = ref.read(prefsServiceProvider).lastTab;
    _tabController = TabController(length: 2, vsync: this, initialIndex: last);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(homeTabProvider.notifier).state = _tabController.index;
        ref.read(prefsServiceProvider).setLastTab(_tabController.index);
        // Clear selection when switching tabs
        ref.read(selectedMediaProvider.notifier).clear();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedMediaProvider);
    final isSelecting = selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Gallery'),
        actions: [
          if (!isSelecting) ...[
            IconButton(
              tooltip: 'Accounts',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.push('/accounts'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'theme') _showThemeSheet();
                if (v == 'refresh') _refreshCurrent();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                const PopupMenuItem(value: 'theme', child: Text('Theme')),
              ],
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Device', icon: Icon(Icons.phone_android)),
            Tab(text: 'Google Drive', icon: Icon(Icons.cloud_outlined)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (isSelecting)
            SelectionBar(
              count: selected.length,
              onClear: () => ref.read(selectedMediaProvider.notifier).clear(),
              onUpload: _onUpload,
              onDownload: _onDownload,
              onDelete: _onDelete,
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DeviceTab(),
                _DriveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshCurrent() {
    if (_tabController.index == 0) {
      ref.read(deviceMediaProvider.notifier).load(refresh: true);
    } else {
      ref.read(driveMediaProvider.notifier).load(refresh: true);
    }
  }

  void _showThemeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System'),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Light'),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark'),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onUpload() async {
    final selectedIds = ref.read(selectedMediaProvider);
    final deviceItems = ref.read(deviceMediaProvider).valueOrNull ?? [];
    final toUpload =
        deviceItems.where((m) => selectedIds.contains(m.id)).toList();

    if (toUpload.isEmpty) {
      _snack('Select device media to upload');
      return;
    }

    final signedIn = ref.read(isSignedInProvider);
    if (!signedIn) {
      _snack('Sign in to Google Drive first (Accounts)');
      return;
    }

    final drive = ref.read(googleDriveServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Uploading…')));

    try {
      int success = 0;
      for (final item in toUpload) {
        if (item.localPath == null) continue;
        final file = await pathToFile(item.localPath!);
        if (file == null) continue;
        await drive.uploadFile(file, customName: item.name);
        success++;
      }
      ref.read(selectedMediaProvider.notifier).clear();
      ref.read(driveMediaProvider.notifier).load(refresh: true);
      messenger.hideCurrentSnackBar();
      _snack(success > 0 ? 'Uploaded $success file(s)' : 'Nothing uploaded');
    } catch (e) {
      messenger.hideCurrentSnackBar();
      _snack('Upload failed: $e');
    }
  }

  Future<void> _onDownload() async {
    final selectedIds = ref.read(selectedMediaProvider);
    final driveItems = ref.read(driveMediaProvider).valueOrNull ?? [];
    final toDownload =
        driveItems.where((m) => selectedIds.contains(m.id)).toList();

    if (toDownload.isEmpty) {
      _snack('Select Google Drive media to download');
      return;
    }

    final drive = ref.read(googleDriveServiceProvider);
    final local = ref.read(localMediaServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Downloading…')));

    try {
      for (final item in toDownload) {
        final file = await drive.downloadFile(item);
        await local.saveToGallery(file, isVideo: item.isVideo);
      }
      ref.read(selectedMediaProvider.notifier).clear();
      ref.read(deviceMediaProvider.notifier).load(refresh: true);
      messenger.hideCurrentSnackBar();
      _snack('Saved to gallery');
    } catch (e) {
      messenger.hideCurrentSnackBar();
      _snack('Download failed: $e');
    }
  }

  Future<void> _onDelete() async {
    final selectedIds = ref.read(selectedMediaProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected?'),
        content: Text(
          'This will permanently remove ${selectedIds.length} item(s) from Google Drive. Device files are not deleted by this action.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final drive = ref.read(googleDriveServiceProvider);
    final driveItems = ref.read(driveMediaProvider).valueOrNull ?? [];
    try {
      for (final item in driveItems.where((m) => selectedIds.contains(m.id))) {
        if (item.driveFileId != null) {
          await drive.deleteFile(item.driveFileId!);
        }
      }
      ref.read(selectedMediaProvider.notifier).clear();
      ref.read(driveMediaProvider.notifier).load(refresh: true);
      _snack('Deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _DeviceTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deviceMediaProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: 'Could not load device media.\n$e',
        onRetry: () => ref.read(deviceMediaProvider.notifier).load(refresh: true),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyView(
            icon: Icons.photo_outlined,
            title: 'No media found',
            subtitle: 'Grant photo permission or add some photos to your device.',
          );
        }
        return MediaGrid(
          items: items,
          onLoadMore: () => ref.read(deviceMediaProvider.notifier).loadMore(),
          onTap: (item, index) {
            final selected = ref.read(selectedMediaProvider);
            if (selected.isNotEmpty) {
              ref.read(selectedMediaProvider.notifier).toggle(item.id);
            } else {
              context.push('/preview', extra: {
                'items': items,
                'index': index,
              });
            }
          },
          onLongPress: (item) {
            ref.read(selectedMediaProvider.notifier).toggle(item.id);
          },
        );
      },
    );
  }
}

class _DriveTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final async = ref.watch(driveMediaProvider);

    return auth.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: 'Sign-in error: $e',
        onRetry: () => ref.read(authStateProvider.notifier).signIn(),
      ),
      data: (account) {
        if (account == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Connect Google Drive',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to browse, upload and back up your media.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(authStateProvider.notifier).signIn(),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                ],
              ),
            ),
          );
        }

        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: 'Could not load Drive media.\n$e',
            onRetry: () =>
                ref.read(driveMediaProvider.notifier).load(refresh: true),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyView(
                icon: Icons.cloud_outlined,
                title: 'Drive is empty',
                subtitle:
                    'Upload photos from the Device tab or add files to the “Cloud Gallery” folder.',
              );
            }
            return MediaGrid(
              items: items,
              onTap: (item, index) {
                final selected = ref.read(selectedMediaProvider);
                if (selected.isNotEmpty) {
                  ref.read(selectedMediaProvider.notifier).toggle(item.id);
                } else {
                  context.push('/preview', extra: {
                    'items': items,
                    'index': index,
                  });
                }
              },
              onLongPress: (item) {
                ref.read(selectedMediaProvider.notifier).toggle(item.id);
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
