import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/media_item.dart';
import '../providers/prefs_provider.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/details/details_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/preview/preview_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ref.watch(onboardingDoneProvider);

  return GoRouter(
    initialLocation: onboardingDone ? '/' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: 'details',
            builder: (context, state) {
              final item = state.extra as MediaItem;
              return DetailsScreen(item: item);
            },
          ),
          GoRoute(
            path: 'preview',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              final items = extra['items'] as List<MediaItem>;
              final index = extra['index'] as int;
              return PreviewScreen(items: items, initialIndex: index);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Page not found', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
  );
});
