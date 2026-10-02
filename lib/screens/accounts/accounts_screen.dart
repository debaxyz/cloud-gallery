import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/prefs_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final prefs = ref.watch(prefsServiceProvider);
    final saved = prefs.getAccounts();

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Connected services',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          auth.when(
            loading: () => const Card(
              child: ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Checking account…'),
              ),
            ),
            error: (e, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Error'),
                subtitle: Text('$e'),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(authStateProvider.notifier).signIn(),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (account) {
              if (account == null) {
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.cloud_outlined),
                    ),
                    title: const Text('Google Drive'),
                    subtitle: const Text('Not connected'),
                    trailing: FilledButton(
                      onPressed: () =>
                          ref.read(authStateProvider.notifier).signIn(),
                      child: const Text('Connect'),
                    ),
                  ),
                );
              }

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: account.photoUrl != null
                            ? NetworkImage(account.photoUrl!)
                            : null,
                        child: account.photoUrl == null
                            ? Text(account.email[0].toUpperCase())
                            : null,
                      ),
                      title: Text(account.displayName ?? 'Google Account'),
                      subtitle: Text(account.email),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      title: const Text('Connected'),
                      trailing: Text(
                        DateFormat.yMMMd().format(account.connectedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(authStateProvider.notifier)
                                    .signOut();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Signed out')),
                                  );
                                }
                              },
                              child: const Text('Sign out'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Disconnect?'),
                                    content: const Text(
                                      'This revokes access. You can reconnect later.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Disconnect'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ref
                                      .read(authStateProvider.notifier)
                                      .disconnect();
                                }
                              },
                              child: const Text('Disconnect'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'About permissions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Cloud Gallery uses the drive.file scope so it can only see files '
            'it creates (inside a “Cloud Gallery” folder). Your other Drive '
            'files stay private.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Previously connected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...saved.map(
              (a) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(a.email),
                subtitle: Text(a.provider),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
