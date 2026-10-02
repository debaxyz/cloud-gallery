import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/media_item.dart';

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview header
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  item.isVideo ? Icons.videocam : Icons.image,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            item.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Chip(
            avatar: Icon(
              item.isLocal ? Icons.phone_android : Icons.cloud,
              size: 18,
            ),
            label: Text(item.isLocal ? 'On device' : 'Google Drive'),
          ),
          const SizedBox(height: 24),
          _InfoTile(label: 'Type', value: item.type.name),
          _InfoTile(label: 'Size', value: item.formattedSize),
          _InfoTile(label: 'Resolution', value: item.resolution),
          if (item.duration != null)
            _InfoTile(
              label: 'Duration',
              value: _formatDuration(item.duration!),
            ),
          if (item.mimeType != null)
            _InfoTile(label: 'MIME', value: item.mimeType!),
          if (item.createdAt != null)
            _InfoTile(
              label: 'Created',
              value: dateFmt.format(item.createdAt!.toLocal()),
            ),
          if (item.modifiedAt != null)
            _InfoTile(
              label: 'Modified',
              value: dateFmt.format(item.modifiedAt!.toLocal()),
            ),
          if (item.driveFileId != null)
            _InfoTile(label: 'Drive ID', value: item.driveFileId!),
          if (item.localPath != null)
            _InfoTile(label: 'Path', value: item.localPath!),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
