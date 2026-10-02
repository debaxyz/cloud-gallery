import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final driveConnected = ref.watch(driveConnectedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'App account (Firebase Email)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          auth.when(
            loading: () => const Card(
              child: ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Loading…'),
              ),
            ),
            error: (e, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Error'),
                subtitle: Text('$e'),
                trailing: TextButton(
                  onPressed: () => context.push('/auth'),
                  child: const Text('Sign in'),
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
                      child: const Icon(Icons.email_outlined),
                    ),
                    title: const Text('Email account'),
                    subtitle: const Text('Not signed in'),
                    trailing: FilledButton(
                      onPressed: () => context.push('/auth'),
                      child: const Text('Sign in'),
                    ),
                  ),
                );
              }

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          () {
                            final s = account.displayName ?? account.email;
                            return s.isNotEmpty ? s[0].toUpperCase() : '?';
                          }(),
                        ),
                      ),
                      title: Text(account.displayName ?? 'User'),
                      subtitle: Text(account.email),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      title: const Text('Signed in'),
                      trailing: Text(
                        DateFormat.yMMMd().format(account.connectedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref.read(authStateProvider.notifier).signOut();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Signed out')),
                              );
                            }
                          },
                          child: const Text('Sign out'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Google Drive',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: const Icon(Icons.add_to_drive),
              ),
              title: const Text('Google Drive'),
              subtitle: Text(
                driveConnected ? 'Connected' : 'Not connected',
              ),
              trailing: driveConnected
                  ? OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(driveConnectedProvider.notifier)
                            .disconnect();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Drive disconnected')),
                          );
                        }
                      },
                      child: const Text('Disconnect'),
                    )
                  : FilledButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(driveConnectedProvider.notifier)
                              .connect();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      child: const Text('Connect'),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'App login uses Firebase Email/Password. '
            'Google Drive is linked separately when you need cloud media.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
