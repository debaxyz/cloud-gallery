import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_account.dart';
import '../providers/account_providers.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(accountsNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.read(accountsNotifierProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (accounts) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Connect Google Drive or Dropbox to browse, upload and back up media.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 24),
              ...accounts.map((account) => _AccountCard(account: account)),
              const SizedBox(height: 16),
              _SetupHints(),
            ],
          );
        },
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final CloudAccount account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDrive = account.provider == CloudProvider.googleDrive;
    final color = isDrive ? const Color(0xFF4285F4) : const Color(0xFF0061FF);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDrive ? Icons.add_to_drive_rounded : Icons.cloud_rounded,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.providerName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.isConnected
                            ? (account.email.isNotEmpty
                                ? account.email
                                : account.displayName)
                            : 'Not connected',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (account.isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
              ],
            ),
            if (account.isConnected) ...[
              const SizedBox(height: 20),
              if (account.usedBytes != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Storage',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      account.usedStorageLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: account.usageFraction,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(accountsNotifierProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refreshing account…')),
                        );
                      },
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Disconnect?'),
                          content: Text(
                            'Disconnect ${account.providerName}? Local media stays on the device.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await ref
                            .read(accountsNotifierProvider.notifier)
                            .disconnect(account.provider);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => _connect(context, ref, account.provider),
                  icon: const Icon(Icons.link_rounded),
                  label: Text('Connect ${account.providerName}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    CloudProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountsNotifierProvider.notifier).connect(provider);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${provider == CloudProvider.googleDrive ? "Google Drive" : "Dropbox"} connected'),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    } on DropboxAuthPendingException {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Complete Dropbox sign-in in the browser. '
              'The app will receive the redirect automatically on mobile.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class _SetupHints extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_outlined, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'API setup required',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Google Drive\n'
              '• Create OAuth client in Google Cloud Console\n'
              '• Enable Drive API\n'
              '• Pass GOOGLE_SERVER_CLIENT_ID via --dart-define\n'
              '• Configure SHA-1 / bundle ID for Android / iOS\n\n'
              'Dropbox\n'
              '• Create app at dropbox.com/developers\n'
              '• Enable files.content.read / write\n'
              '• Set redirect URI (cloudgallery://oauth/dropbox)\n'
              '• Pass DROPBOX_APP_KEY via --dart-define\n\n'
              'See README for full steps.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.75),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
