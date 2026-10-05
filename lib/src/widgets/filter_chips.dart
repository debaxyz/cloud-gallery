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
          SoftPillButton(
            label: 'All',
            icon: Icons.apps_rounded,
            selected: current == MediaFilter.all,
            onPressed: () => onChanged(MediaFilter.all),
          ),
          const SizedBox(width: AppTheme.space8),
          SoftPillButton(
            label: 'Local',
            icon: Icons.phone_android_rounded,
            selected: current == MediaFilter.local,
            onPressed: () => onChanged(MediaFilter.local),
          ),
          const SizedBox(width: AppTheme.space8),
          SoftPillButton(
            label: 'Drive',
            icon: Icons.add_to_drive_rounded,
            selected: current == MediaFilter.googleDrive,
            onPressed: () => onChanged(MediaFilter.googleDrive),
          ),
          const SizedBox(width: AppTheme.space8),
          SoftPillButton(
            label: 'Dropbox',
            icon: Icons.cloud_rounded,
            selected: current == MediaFilter.dropbox,
            onPressed: () => onChanged(MediaFilter.dropbox),
          ),
        ],
      ),
    );
  }
}
