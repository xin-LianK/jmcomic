# JM Visual Flutter Client

## First setup

```powershell
.\tool\bootstrap_flutter.ps1
```

The script runs `flutter create --platforms=android,ios,web .` and then `flutter pub get`.

## Run

```powershell
flutter run -d chrome --dart-define=JM_API_BASE=http://127.0.0.1:8766
```

The client now prefers the Toolbox Hub JM API prefix `/api/jm`. To use the
legacy standalone adapter, pass:

```powershell
flutter run -d chrome --dart-define=JM_API_BASE=http://127.0.0.1:8766 --dart-define=JM_API_PREFIX=/api
```

For Android emulator:

```powershell
flutter run -d android --dart-define=JM_API_BASE=http://10.0.2.2:8766
```
