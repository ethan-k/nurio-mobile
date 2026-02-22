# Nurio Mobile

Flutter migration of the Nurio customer mobile app.

## Repository Structure

- `flutter_app/`: new Flutter app (active migration target)
- `android/`: legacy Hotwire Native Android shell (reference)
- `shared/path-configuration.json`: legacy route presentation config (reference)

## Scope

This migration supports customer-facing features from Nurio web routes (events, onboarding, profile/settings, orders, passes, payments).

Out of scope:
- Admin features (`/admin/*`)
- Tutor/tutoring features (`/tutoring*`, `/tutors*`, `tutors.*`)

See `FEATURE_MIGRATION_MATRIX.md` for the detailed route inventory and coverage.

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
```
