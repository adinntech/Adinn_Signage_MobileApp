# Adinn Recce (signage)

Field app for the Adinn Signage Recce CRM.

## Run

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

`API_BASE_URL` defaults to `http://10.0.2.2:4000/api/v1` (Android emulator to
host machine). For a physical device use your machine's LAN IP or an HTTPS URL.
Cleartext HTTP is allowed in debug/profile builds only.

```
flutter analyze
flutter test
```
