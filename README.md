# Cloud Gallery

Production-ready Flutter app to manage photos & videos from **local storage**, **Google Drive**, and **Dropbox**.

## Features

- Real local gallery via `photo_manager` (permission-aware)
- Google Sign-In + Google Drive API (list / download / upload)
- Dropbox OAuth2 (PKCE) + Files API (list / download / upload)
- Unified filterable grid (All / Local / Drive / Dropbox)
- Multi-select actions (upload / download)
- Full-screen preview with metadata
- Secure token storage (`flutter_secure_storage`)
- Material 3 light / dark themes
- Android & iOS permissions + Dropbox deep link

## Quick start

```bash
flutter pub get

# Run with your credentials
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com \
  --dart-define=DROPBOX_APP_KEY=YOUR_DROPBOX_APP_KEY \
  --dart-define=DROPBOX_REDIRECT_URI=cloudgallery://oauth/dropbox
```

## Google Drive setup

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project → enable **Google Drive API**
3. Credentials → **OAuth 2.0 Client IDs**
   - Android: package `com.canopas.cloud_gallery` + SHA-1
   - iOS: bundle ID from Xcode
   - Web: used as `GOOGLE_SERVER_CLIENT_ID` for `google_sign_in`
4. Pass the **Web client ID** via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`

Scopes used:
- `email`
- `https://www.googleapis.com/auth/drive.readonly`
- `https://www.googleapis.com/auth/drive.file`

## Dropbox setup

1. Open [Dropbox App Console](https://www.dropbox.com/developers/apps)
2. Create app → Scoped access → permissions:
   - `files.content.read`
   - `files.content.write`
   - `account_info.read`
3. Redirect URI: `cloudgallery://oauth/dropbox` (must match `AppConfig`)
4. Copy **App key** → `--dart-define=DROPBOX_APP_KEY=...`

Android deep link and iOS URL scheme `cloudgallery` are already configured.

## Project structure

```
lib/src/
├── config/app_config.dart      # API keys via --dart-define
├── models/                     # MediaItem, CloudAccount
├── services/
│   ├── local_media_service.dart    # photo_manager
│   ├── google_drive_service.dart   # Sign-In + Drive API
│   ├── dropbox_service.dart        # PKCE OAuth + Files API
│   ├── media_service.dart          # Facade
│   └── account_service.dart
├── providers/
├── screens/
├── widgets/
├── theme/
└── router/
```

## Permissions

| Platform | What |
|----------|------|
| Android  | `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `INTERNET` |
| iOS      | `NSPhotoLibraryUsageDescription`, URL scheme |

## Notes

- Local media works on **Android / iOS**. On web, local gallery is empty (photo_manager limitation).
- Dropbox OAuth opens the system browser; complete sign-in there. On mobile, the redirect returns to the app via the custom scheme.
- Upload prefers Google Drive if signed in, otherwise Dropbox.
- Saving downloaded cloud files into the device gallery can be extended with `gal` / `image_gallery_saver`.

## License

Apache 2.0
