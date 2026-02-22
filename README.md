# Nurio Mobile

Flutter migration of the Nurio customer mobile app.

## Repository Structure

- `flutter_app/`: native Flutter app (active customer app)
- `android/`: legacy Hotwire Native Android shell (reference only)
- `shared/path-configuration.json`: legacy route config (reference only)

## Scope

This migration targets customer-facing features only.

Included customer domains:
- Events discovery and detail
- Checkout/payment entry points
- Pass packages, tickets, payments, wallet credits
- Profile/settings, referrals, event history

Out of scope:
- Admin features (`/admin/*`)
- Tutor/tutoring features (`/tutoring*`, `/tutors*`, `tutors.*`)

## Native-Only Constraint

The Flutter app is native-only.

- No WebView fallback
- No in-app browser shell
- Unsupported backend mobile APIs are surfaced with native API-gap states

See `FEATURE_MIGRATION_MATRIX.md` for the route inventory and migration status.

## Run Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

Optional base URL override:

```bash
flutter run --dart-define=NURIO_BASE_URL=https://nurio.kr
```

## Android Build Note

The Flutter Android module pins `ndkVersion` to `27.0.12077973` in
`flutter_app/android/app/build.gradle.kts` to avoid local SDK installations
that have incomplete NDK metadata.

## Quality Checks

```bash
cd flutter_app
flutter analyze
flutter test
flutter build apk --debug
```

## Flutter Release Build

Use the Flutter-only release script:

```bash
./scripts/build-release-flutter.sh
```

Or via Task:

```bash
task flutter:release
```
