import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onUpload;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const SelectionBar({
    super.key,
    required this.count,
    required this.onUpload,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppTheme.cardDark : AppTheme.card,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF374151) : AppTheme.border,
            ),
          ),
          boxShadow: isDark ? null : AppTheme.softShadow,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Action(
                  icon: Icons.cloud_upload_rounded,
                  label: 'Upload',
                  color: AppTheme.primaryAccent,
                  onTap: onUpload,
                ),
                _Action(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  color: AppTheme.secondary,
                  onTap: onDownload,
                ),
                _Action(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: const Color(0xFFEF4444),
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: AppTheme.iconLg),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
