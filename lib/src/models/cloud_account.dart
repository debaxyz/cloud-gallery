import 'package:flutter/foundation.dart';

enum CloudProvider { googleDrive, dropbox }

@immutable
class CloudAccount {
  final String id;
  final CloudProvider provider;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isConnected;
  final int? usedBytes;
  final int? totalBytes;
  final DateTime? lastSynced;

  const CloudAccount({
    required this.id,
    required this.provider,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isConnected = false,
    this.usedBytes,
    this.totalBytes,
    this.lastSynced,
  });

  CloudAccount copyWith({
    String? id,
    CloudProvider? provider,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isConnected,
    int? usedBytes,
    int? totalBytes,
    DateTime? lastSynced,
  }) {
    return CloudAccount(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isConnected: isConnected ?? this.isConnected,
      usedBytes: usedBytes ?? this.usedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  String get providerName {
    switch (provider) {
      case CloudProvider.googleDrive:
        return 'Google Drive';
      case CloudProvider.dropbox:
        return 'Dropbox';
    }
  }

  String get usedStorageLabel {
    if (usedBytes == null || totalBytes == null) return '—';
    final usedMb = usedBytes! / (1024 * 1024);
    final totalGb = totalBytes! / (1024 * 1024 * 1024);
    if (usedMb < 1024) {
      return '${usedMb.toStringAsFixed(0)} MB of ${totalGb.toStringAsFixed(0)} GB';
    }
    return '${(usedMb / 1024).toStringAsFixed(1)} GB of ${totalGb.toStringAsFixed(0)} GB';
  }

  double get usageFraction {
    if (usedBytes == null || totalBytes == null || totalBytes == 0) return 0;
    return (usedBytes! / totalBytes!).clamp(0.0, 1.0);
  }
}
