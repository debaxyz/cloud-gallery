import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/accounts_screen.dart';
import '../screens/media_detail_screen.dart';
import '../screens/shell_screen.dart';
import '../models/media_item.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: hasSeenOnboarding ? '/home' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/accounts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AccountsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/media/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final media = state.extra as MediaItem?;
          if (media == null) {
            return const Scaffold(body: Center(child: Text('Media not found')));
          }
          return MediaDetailScreen(media: media);
        },
      ),
    ],
  );
});
