# DeliciasGo

Aplicacion Flutter de ride-sharing con roles de Conductor y Pasajero, integrada con Firebase, notificaciones y Google Maps.

## Requisitos

- Flutter SDK (3.11+)
- Dart SDK
- Firebase project configurado
- Google Maps API key con Directions API habilitada

## Configuracion

1. Clona el repositorio e instala dependencias:
   ```bash
   flutter pub get
   ```

2. Configura Firebase:
   - Android: coloca `google-services.json` en `android/app/`
   - iOS: coloca `GoogleService-Info.plist` en `ios/Runner/`
   - (Opcional) `flutterfire configure` para regenerar `firebase_options.dart`

3. Configura Google Maps API Key (obligatorio para rutas):
   - Ejecuta con `--dart-define`:
     ```bash
     flutter run --dart-define=GOOGLE_MAPS_API_KEY=TU_API_KEY
     ```
   - En VS Code puedes agregarlo en `.vscode/launch.json`:
     ```json
     "dart.flutterRunAdditionalArgs": ["--dart-define=GOOGLE_MAPS_API_KEY=TU_API_KEY"]
     ```

## Ejecutar

- Android/iOS:
  ```bash
  flutter run
  ```
- Web:
  ```bash
  flutter run -d chrome
  ```

## Tests

```bash
flutter analyze
flutter test
```

## Notas

- `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist` no se suben al repo (estan en .gitignore).
- El API key de Google Maps se pasa por `--dart-define` y no debe hardcodearse.
