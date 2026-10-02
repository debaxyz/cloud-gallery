# Cloud Gallery

A beautiful Flutter app to manage, organize, and back up photos & videos from **local storage**, **Google Drive**, and **Dropbox** — all in one place.

Inspired by the open-source [Canopas Cloud Gallery](https://github.com/canopas/cloud-gallery).

## Features

- 📸 Unified media gallery (Local + Google Drive + Dropbox)
- ☁️ Connect / disconnect cloud accounts
- 🔄 Multi-select → Upload / Download / Delete
- 🖼️ Full-screen media preview with metadata
- 🌙 Light & Dark theme support
- ✨ Modern Material 3 UI
- 📱 Works on Android, iOS & Web

> **Note**: This is a fully functional **demo** with realistic mock data.  
> Replace `MediaService` and `AccountService` with real Google Drive / Dropbox API integrations for production.

## Screenshots flow

1. **Onboarding** – 3 beautiful intro pages  
2. **Gallery** – Filterable grid (All / Local / Drive / Dropbox)  
3. **Accounts** – Connect cloud providers, view storage usage  
4. **Media Detail** – Zoomable preview + actions  

## Tech Stack

| Category          | Package              |
|-------------------|----------------------|
| State management  | flutter_riverpod     |
| Navigation        | go_router            |
| Local media       | photo_manager        |
| Caching           | cached_network_image |
| Preferences       | shared_preferences   |

## Getting Started

```bash
# Clone / open the project
cd cloud_gallery

# Get dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run on Android / iOS emulator
flutter run
```

## Project Structure

```
lib/
├── main.dart
└── src/
    ├── models/          # MediaItem, CloudAccount
    ├── providers/       # Riverpod providers
    ├── screens/         # UI screens
    ├── widgets/         # Reusable widgets
    ├── services/        # Mock media & account services
    ├── theme/           # AppTheme (light/dark)
    └── router/          # GoRouter config
```

## Next Steps (Production)

1. Add real Google Sign-In + Drive API
2. Add Dropbox OAuth + API
3. Use `photo_manager` for real local gallery
4. Implement background upload / auto-backup
5. Add Firebase Analytics & Crashlytics

## License

Apache 2.0 — free to use and modify.
