# Nurio Mobile Workspace

Mobile workspace for Nurio app shells and migration tracks.

## Repository Structure

- `ios/`: standalone Hotwire Native iOS shell for the customer app
- `flutter_app/`: native Flutter migration track for the customer app
- `android/`: legacy Hotwire Native Android shell for the customer app
- `tutors-nurio-mobile/android/`: standalone Hotwire Native Android shell for `https://tutors.nurio.kr`
- `study-nurio-mobile/`: sibling workspace for study product mobile shells
- `shared/`: cross-app configuration assets

## Scope

This workspace contains multiple Nurio product tracks.

Customer app domains:
- Events discovery and detail
- Checkout/payment entry points
- Pass packages, tickets, payments, wallet credits
- Profile/settings, referrals, event history

Tutor app entry point:
- `tutors-nurio-mobile/android/` for the tutor-facing Hotwire Android shell

Study app entry point:
- `study-nurio-mobile/` for the study-facing mobile workspace

## iOS Hotwire Shell

The top-level `ios/` project is a standalone Hotwire Native shell.

- Start URL: `https://nurio.kr/events`
- OAuth callback: `nurio://auth-callback`
- Path configuration source: `shared/configurations/ios_v1.json`
- Customer scope is explicit: admin and tutor URLs are not handled in-app
- Submission guide: `ios/docs/SUBMISSION.md`

Open and run:

```bash
open ios/Nurio.xcodeproj
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test
```

Optional base URL override at runtime:

```bash
NURIO_BASE_URL=https://nurio.kr xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
```

Archive for release after signing is configured:

```bash
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -configuration Release -destination 'generic/platform=iOS' -archivePath build/Nurio.xcarchive archive
```

## Tutor Android Hotwire Shell

The tutor-facing Android Hotwire shell lives in `tutors-nurio-mobile/android`.

- Start URL: `https://tutors.nurio.kr`
- OAuth callback: `nurio://auth-callback`
- Build config: `tutors-nurio-mobile/android/app/build.gradle.kts`
- Local signing config: `tutors-nurio-mobile/android/keystore.properties`

Build locally:

```bash
cd tutors-nurio-mobile/android
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew :app:assembleDebug
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew :app:lintDebug
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew :app:assembleRelease
```

## Flutter Constraint

The Flutter app remains native-only.

- No WebView fallback
- No in-app browser shell
- Unsupported backend mobile APIs are surfaced with native API-gap states

See `FEATURE_MIGRATION_MATRIX.md` for the Flutter route inventory and migration status.

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
open ios/Nurio.xcodeproj
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test

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
