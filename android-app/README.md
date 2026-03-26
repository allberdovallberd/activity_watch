# Android App (Flutter)

## Behavior

- Permission gate: app is blocked until Usage Access is granted.
- Device link is manual:
  - main screen shows red `Device is not set!` if empty
  - tap `Set now`, enter `device_id`, and app validates with backend
  - on success, green `All is set` is shown
  - each ID can bind to one physical installation at a time
- Auto collect/sync:
  - runs automatically
  - stores locally offline
  - syncs when network is available

- Settings (top-right icon):
  - Display name
  - Reset config

## Build

```bash
flutter pub get
flutter build apk --debug
```

## Necessary Steps

1. Create category hierarchy and device in web app:
   - Main category (Faculty)
   - Sub category (Year intake)
   - Device ID
2. Install APK on tablet.
3. Open app and grant Usage Access.
4. Tap `Set now`, enter exact Device ID from web app.
5. Keep tablet on same network as backend at least once to bind Device ID.
6. Verify in web app that:
   - device appears as active
   - `Last Seen` updates
   - usage data appears after some activity
