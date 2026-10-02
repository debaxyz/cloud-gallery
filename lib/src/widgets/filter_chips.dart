import 'package:flutter/material.dart';

import '../providers/media_providers.dart';
import '../theme/app_theme.dart';

class FilterChips extends StatelessWidget {
  final MediaFilter current;
  final ValueChanged<MediaFilter> onChanged;

  const FilterChips({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'All',
            icon: Icons.apps_rounded,
            selected: current == MediaFilter.all,
            onTap: () => onChanged(MediaFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Local',
            icon: Icons.phone_android_rounded,
            selected: current == MediaFilter.local,
            onTap: () => onChanged(MediaFilter.local),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Drive',
            icon: Icons.add_to_drive_rounded,
            selected: current == MediaFilter.googleDrive,
            onTap: () => onChanged(MediaFilter.googleDrive),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Dropbox',
            icon: Icons.cloud_rounded,
            selected: current == MediaFilter.dropbox,
            onTap: () => onChanged(MediaFilter.dropbox),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
