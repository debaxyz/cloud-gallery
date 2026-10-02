class CloudAccount {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String provider; // 'google'
  final DateTime connectedAt;
  final bool isActive;

  const CloudAccount({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.provider = 'google',
    required this.connectedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'provider': provider,
        'connectedAt': connectedAt.toIso8601String(),
        'isActive': isActive,
      };

  factory CloudAccount.fromJson(Map<String, dynamic> json) => CloudAccount(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        provider: json['provider'] as String? ?? 'google',
        connectedAt: DateTime.parse(json['connectedAt'] as String),
        isActive: json['isActive'] as bool? ?? true,
      );

  CloudAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? provider,
    DateTime? connectedAt,
    bool? isActive,
  }) {
    return CloudAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider ?? this.provider,
      connectedAt: connectedAt ?? this.connectedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
