# Nurio Mobile Workspace

Mobile workspace for Nurio app shells and migration tracks.

## Repository Structure

- `ios/`: standalone Hotwire Native iOS shell for the customer app
- `flutter_app/`: native Flutter migration track for the customer app
- `android/`: legacy Hotwire Native Android shell for the customer app
- `tutors-nurio-mobile/android/`: standalone Hotwire Native Android shell for `https://tutors.nurio.kr`
- `tutors-nurio-mobile/ios/`: standalone Hotwire Native iOS shell for `https://tutors.nurio.kr`
- `study-nurio-mobile/`: sibling workspace for study product mobile shells
- `leaders-nurio-mobile/`: dedicated iOS and Android Hotwire Native shells for `https://studyleaders.nurio.kr`
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

Study Leader app entry point:
- `leaders-nurio-mobile/` for the leader operations workspace

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

## Customer launch identity

- The customer iOS and Android launcher icons use the compact blue `n` mark.
- `ios/nurio_splash.json` and `android/app/src/main/assets/animations/nurio_splash.json` share the 1.5-second Lottie reveal for the full lowercase `nurio` wordmark.
- The operating-system launch surface remains static white. iOS starts the Lottie overlay after its app window connects, while Android hands off from the system splash icon to the in-app animation.

This applies only to the top-level customer `ios/` and `android/` targets. Study, Study Leader, and Tutor retain their independent visual identities.

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

## Tutor iOS Hotwire Shell

The tutor-facing iOS Hotwire shell lives in `tutors-nurio-mobile/ios`.

- Start URL: `https://tutors.nurio.kr`
- OAuth callback: `nurio://auth-callback`
- Path configuration source: `tutors-nurio-mobile/ios/path-configuration.json`
- Submission guide: `tutors-nurio-mobile/ios/docs/SUBMISSION.md`

Build locally:

```bash
xcodebuild -project tutors-nurio-mobile/ios/NurioTutors.xcodeproj -scheme NurioTutors -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
xcodebuild -project tutors-nurio-mobile/ios/NurioTutors.xcodeproj -scheme NurioTutors -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test
```

## Study Leader Hotwire Shells

The Study Leader target is a separate app for approved and candidate leaders.

- Start URL: `https://studyleaders.nurio.kr`
- OAuth callback: `nurioleaders://auth-callback`
- iOS bundle identifier: `com.nurio.studyleader.ios`
- Android application identifier: `com.nurio.studyleader.android`
- Implementation and release plan: `leaders-nurio-mobile/docs/IMPLEMENTATION_PLAN.md`
- Launch gates: `leaders-nurio-mobile/docs/LAUNCH_CHECKLIST.md`
- Store metadata and screenshot plan: `leaders-nurio-mobile/docs/ASO.md`

Build and test:

```bash
xcodebuild -project leaders-nurio-mobile/ios/NurioStudyLeader.xcodeproj -scheme NurioStudyLeader -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project leaders-nurio-mobile/ios/NurioStudyLeader.xcodeproj -scheme NurioStudyLeader -destination 'platform=iOS Simulator,name=iPhone 17' test

cd leaders-nurio-mobile/android
./gradlew :app:testDebugUnitTest :app:assembleDebug :app:lintDebug
```

## Android Studio production emulator builds

Each Android shell exposes a debuggable `productionDebug` build variant for
one-click emulator runs against its live product host:

| App | Android project | Production host |
| --- | --- | --- |
| Customer Nurio | `android/` | `https://nurio.kr` |
| Study Nurio | `study-nurio-mobile/android/` | `https://study.nurio.kr` |
| Study Leader Nurio | `leaders-nurio-mobile/android/` | `https://studyleaders.nurio.kr` |

Open the relevant Android project in Android Studio, sync Gradle, then choose
`app: productionDebug` in **View > Tool Windows > Build Variants**. Select the
`app` Run configuration and click **Run** or **Debug**. These are local
debug-key emulator builds that use live production data; use a designated QA
account and avoid destructive actions.

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
