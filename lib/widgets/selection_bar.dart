import 'package:flutter/material.dart';

class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onUpload,
    required this.onDownload,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onUpload;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClear,
                tooltip: 'Clear selection',
              ),
              Text(
                '$count selected',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.cloud_upload_outlined),
                tooltip: 'Upload to Drive',
                onPressed: onUpload,
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Download to device',
                onPressed: onDownload,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: theme.colorScheme.error),
                tooltip: 'Delete from Drive',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
