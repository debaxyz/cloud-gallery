# Cloud Gallery

A polished Flutter app that keeps all your photos and videos in one place — on the device and in Google Drive.

## Features

- **Onboarding** – short, friendly intro with permission explanation
- **Unified home** – tabs for Device and Google Drive media
- **Multi-select** – long-press or tap to select, then upload / download / delete
- **Full-screen preview** – swipe through images and videos (Chewie player)
- **File details** – size, date, resolution, source, MIME, path / Drive ID
- **Accounts** – connect / disconnect Google Drive, view account info
- **Backup & sync** – upload selected device media to a dedicated “Cloud Gallery” folder on Drive; download cloud media into the device gallery
- **Persistent choices** – remembers last tab, theme mode, onboarding status, connected accounts
- **Helpful errors** – clear messages with retry actions
- **Material 3** – light / dark / system themes, clean staggered grid

## Architecture

```
lib/
├── main.dart
├── theme/app_theme.dart
├── models/
│   ├── media_item.dart
│   └── cloud_account.dart
├── services/
│   ├── local_media_service.dart   # photo_manager
│   ├── google_drive_service.dart  # googleapis Drive v3
│   └── prefs_service.dart         # SharedPreferences
├── providers/                     # Riverpod
│   ├── auth_provider.dart
│   ├── media_provider.dart
│   └── prefs_provider.dart
├── screens/
│   ├── onboarding/
│   ├── home/
│   ├── accounts/
│   ├── details/
│   └── preview/
├── widgets/
│   ├── media_grid.dart
│   └── selection_bar.dart
└── utils/
    ├── router.dart                # go_router
    └── helpers.dart
```

## Prerequisites

- Flutter 3.22+ (Dart 3.5+)
- Android Studio / VS Code with Flutter plugins
- A Google Cloud project with **Google Drive API** enabled

## Google Drive setup

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Create (or select) a project → **APIs & Services → Library** → enable **Google Drive API**
3. **OAuth consent screen**
   - User type: External
   - Add scopes:
     - `https://www.googleapis.com/auth/drive.file` (recommended — only files the app creates; simpler verification)
     - Optionally `drive.readonly` if you need to browse the user’s entire Drive (extra verification)
4. **Credentials → Create credentials → OAuth client ID**
   - Application type: **Android**
   - Package name: `com.example.cloud_gallery` (or your chosen applicationId)
   - SHA-1 fingerprint of your debug/release keystore

### Get debug SHA-1

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copy the SHA-1 value into the Android OAuth client.

> No `google-services.json` is required — the app uses pure `google_sign_in` + `googleapis`.

## Run the app

```bash
# From the project root
flutter create . --project-name cloud_gallery --org com.example
# (only needed once if the android/ios folders are incomplete)

flutter pub get
flutter run
```

If you already have a Flutter project scaffold, just copy the `lib/`, `pubspec.yaml`, and `android/app/src/main/AndroidManifest.xml` permissions.

## Android permissions

Already declared in `AndroidManifest.xml`:

- `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (Android 13+)
- `READ_EXTERNAL_STORAGE` (maxSdk 32)
- `WRITE_EXTERNAL_STORAGE` (maxSdk 28)
- `INTERNET`

On first launch the onboarding flow requests the necessary runtime permissions via `photo_manager` and `permission_handler`.

## Key packages

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `photo_manager` + `photo_manager_image_provider` | Device media access & thumbnails |
| `google_sign_in` + `extension_google_sign_in_as_googleapis_auth` | OAuth |
| `googleapis` (Drive v3) | List / upload / download / delete |
| `cached_network_image` | Drive thumbnails |
| `video_player` + `chewie` | Video preview |
| `shared_preferences` | Persist theme, tab, accounts, onboarding |

## How sync works

- **Upload** – selected device items are uploaded into a folder named **“Cloud Gallery”** on the user’s Drive (created automatically). Because we use the `drive.file` scope, the app only sees files it created.
- **Download** – selected Drive items are downloaded to a temp file and saved into the system gallery via `PhotoManager.editor`.
- **Delete** – only removes files from Drive (device originals are never deleted by the app).

## Extending

- **Broader Drive access**: change `_driveScopes` in `google_drive_service.dart` to include `drive.DriveApi.driveReadonlyScope` and update the OAuth consent screen.
- **Auto-backup**: a preference flag (`autoBackup`) is already stored; wire a background isolate / WorkManager job to call the upload path.
- **More providers**: the `CloudAccount` model and Accounts screen are designed so you can add Dropbox / OneDrive later.

## License

MIT
