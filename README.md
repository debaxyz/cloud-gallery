# Cloud Gallery


Flutter app for photos & videos on **device + Google Drive**, with **Firebase Authentication (Google Sign-In)**.

## Auth architecture

```
User taps "Sign in with Google"
        │
        ▼
 Google Sign-In (scopes: drive.file)
        │
        ├──► Firebase Auth  (idToken / accessToken → GoogleAuthProvider.credential)
        │         └── app user session (uid, email)
        │
        └──► Google Drive API  (same GoogleSignIn authenticated HTTP client)
                  └── list / upload / download / delete
```

**Important:** Firebase ID tokens are **not** valid for the Drive API.  
Drive always uses the Google Sign-In access token (via `extension_google_sign_in_as_googleapis_auth`).

## Firebase + Google Sign-In setup

### 1. Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Create a project (or use an existing one)
3. Add an **Android** app:
   - Package name: `com.example.cloud_gallery`
   - Download **`google-services.json`**
   - Place it at: `android/app/google-services.json`

### 2. Enable Google Sign-In in Firebase

1. Firebase Console → **Authentication** → **Sign-in method**
2. Enable **Google**
3. Set support email → Save

### 3. Google Cloud (Drive API + OAuth)

Firebase creates a Google Cloud project automatically.

1. [Google Cloud Console](https://console.cloud.google.com/) → select the **same** project
2. **APIs & Services → Library** → enable **Google Drive API**
3. **OAuth consent screen** → add scope:
   - `https://www.googleapis.com/auth/drive.file`
4. **Credentials**:
   - Ensure an **Android** OAuth client exists with:
     - Package: `com.example.cloud_gallery`
     - **SHA-1** of your debug (and release) keystore

#### Debug SHA-1

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Add that SHA-1 under Firebase Project settings → Your Android app → Add fingerprint  
(and/or in Google Cloud OAuth Android client).

### 4. Run

```bash
flutter pub get
flutter run -d android
```

## Features

- Firebase Auth + Google Sign-In
- Device gallery (photo_manager)
- Google Drive browse / upload / download / delete
- Onboarding, multi-select, preview, details, accounts
- Material 3 light / dark / system

## Project layout

```
lib/
├── main.dart                 # Firebase.initializeApp()
├── services/
│   ├── auth_service.dart     # Firebase + Google Sign-In
│   ├── google_drive_service.dart
│   ├── local_media_service.dart
│   └── prefs_service.dart
├── providers/
│   ├── auth_provider.dart
│   └── ...
└── screens/ ...
```

## Common errors

| Error | Fix |
|-------|-----|
| `Firebase.initializeApp` fails | Missing / wrong `google-services.json` |
| `DEVELOPER_ERROR` / code 10 | SHA-1 not registered for the package |
| `operation-not-allowed` | Enable Google in Firebase Auth |
| Drive API 403 | Drive API not enabled, or scope missing |
| `MissingPluginException` photo_manager | Run on **Android device/emulator**, not web |

## License

MIT
