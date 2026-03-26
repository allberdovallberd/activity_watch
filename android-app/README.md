# Android App

This app collects usage data on Android, stores it locally, and syncs it to the backend.

## Requirements

- Flutter SDK
- Android SDK
- `adb` for manual install/debug
- running backend reachable from the tablet

## Important Behavior

- Usage Access permission is required.
- Device linking is manual.
- Data is stored locally first and synced when the backend is reachable.
- The backend URL is editable from app settings.
- The latest saved backend URL is the only active sync target.
- There is no fallback and no automatic switch to another server.

Main code paths:

- default backend value: `android-app/lib/src/app_config.dart`
- settings persistence: `android-app/lib/src/settings_store.dart`
- sync logic: `android-app/lib/src/sync_service.dart`

## Build

```bash
flutter pub get
flutter build apk --release
```

Release APK output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Versioning Before Update

If you want Android or MDM to recognize a new APK as an update, increase the version in:

- `android-app/pubspec.yaml`

Example:

```yaml
version: 1.0.1+2
```

Rules:

- the value after `+` must always increase
- the visible version on the left can be changed as needed

## Install

Replace existing install:

```bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

If replace fails because of an older conflicting install:

```bash
adb uninstall com.example.usage_collector
adb install build/app/outputs/flutter-apk/app-release.apk
```

## First Device Setup

1. Install the APK.
2. Open the app.
3. Grant Usage Access.
4. Open settings and confirm the backend URL.
5. Enter the correct `device_id` from the web app.
6. Let the app reach the backend once to bind and start syncing.

## Backend URL Behavior

Current behavior:

- `AppConfig.defaultBackendBaseUrl` is only the first-run default
- after that, the saved settings value is used
- changing the backend URL in settings replaces the previous value
- you can edit it as many times as needed

## Notes

- If background sync seems wrong, check the saved backend URL on the device first.
- If you distribute a rebuilt APK through MDM, bump the version before publishing it.
- If the app is installed on a managed device, device-owner or policy behavior depends on that device's MDM setup.
