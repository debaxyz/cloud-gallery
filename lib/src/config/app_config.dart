/// Production configuration.
///
/// 1. Google Cloud Console → create OAuth 2.0 Client IDs (Android, iOS, Web)
///    Enable "Google Drive API"
/// 2. Dropbox App Console → create app with files.content.read / files.content.write
///    Enable PKCE; set redirect URI (e.g. cloudgallery://oauth/dropbox)
///
/// Never commit real secrets. Use --dart-define or env in CI.
class AppConfig {
  // ── Google ──────────────────────────────────────────────────────────────
  /// Web client ID (also used by google_sign_in on some platforms)
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '', // e.g. '123456789-abc.apps.googleusercontent.com'
  );

  /// Optional: Android client ID is usually taken from google-services / SHA-1
  static const List<String> googleScopes = [
    'email',
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/drive.file',
  ];

  // ── Dropbox ─────────────────────────────────────────────────────────────
  static const String dropboxAppKey = String.fromEnvironment(
    'DROPBOX_APP_KEY',
    defaultValue: '', // from Dropbox App Console
  );

  static const String dropboxAppSecret = String.fromEnvironment(
    'DROPBOX_APP_SECRET',
    defaultValue: '', // only needed if not using pure PKCE public client
  );

  /// Must match the redirect URI registered in Dropbox App Console
  static const String dropboxRedirectUri = String.fromEnvironment(
    'DROPBOX_REDIRECT_URI',
    defaultValue: 'cloudgallery://oauth/dropbox',
  );

  static const String dropboxAuthUrl =
      'https://www.dropbox.com/oauth2/authorize';
  static const String dropboxTokenUrl =
      'https://api.dropboxapi.com/oauth2/token';
  static const String dropboxApiBase = 'https://api.dropboxapi.com/2';
  static const String dropboxContentBase = 'https://content.dropboxapi.com/2';

  // ── App ─────────────────────────────────────────────────────────────────
  static const String appName = 'Cloud Gallery';
  static const int localMediaPageSize = 80;
  static const int cloudMediaPageSize = 50;
}
