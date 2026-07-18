# Nurio Study Production Push for Local Builds

## Goal

Make push notifications available in every locally built Nurio Study Android and iOS app while the app uses the production Rails origin, `https://study.nurio.kr`. Debug and Release builds use the same production Firebase project and Study app registrations without an opt-in flag.

## Configuration source

The workspace-level source files are:

- Android: `/Users/ws/es/business/nurioworkspace/nurio_study/mobile_certs/nurio-study-google-services.json`
- iOS: `/Users/ws/es/business/nurioworkspace/nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist`

Both files target Firebase project `nurio-prod`. The Android JSON contains a client for `com.nurio.study.android`; the iOS plist targets `com.nurio.study.ios`. These Firebase client configuration files remain outside the mobile repository and are not copied into Git history.

The existing root mobile Firebase files belong to other application IDs and must not be used by the Study clients.

## Build behavior

### Android

The Study app Gradle configuration treats the workspace Android file as required input for Debug and Release app builds. It validates the project ID and confirms that the Study package is present before applying Google Services processing.

A Gradle preparation task copies and renames that source file to the Google Services plugin's required ignored location, `study-nurio-mobile/android/app/google-services.json`, before each variant's Google Services task. The generated copy is not a second source of truth and remains ignored by Git.

Both Debug and Release keep `BuildConfig.BASE_URL = "https://study.nurio.kr"` and set `FIREBASE_CONFIGURED = true`. A missing, malformed, or mismatched source config fails the build with a stable message that does not print API keys or file contents.

### iOS

The Study target's Firebase copy phase reads the workspace iOS plist directly. The phase requires the file for both Debug and Release, validates `PROJECT_ID` and `BUNDLE_ID`, and copies it to the built app as `GoogleService-Info.plist`.

The app default remains `https://study.nurio.kr`. Debug uses the `development` APNs entitlement for locally signed device builds; Release uses `production`. Both entitlements still register FCM tokens with the same production Rails server and Firebase project.

A missing, malformed, or mismatched source plist fails the build before an app is produced. The runtime Firebase guard remains as defense in depth.

## Verification

A repository script provides one production-shaped local verification entry point. It performs only identifier-safe checks and then runs:

- Android unit tests, Debug APK assembly, and unsigned Release APK assembly;
- iOS unit tests in Debug configuration;
- iOS Debug and Release simulator builds without code signing;
- checks that built Android and iOS artifacts contain production Firebase configuration for the Study application IDs;
- checks that the default app origin remains `https://study.nurio.kr`.

Tests must prove that missing or mismatched Firebase configuration is rejected and that valid production configuration enables Firebase in both build types. Test fixtures may contain synthetic non-secret identifiers, but production configuration values and registration tokens must never be printed.

## Physical-device boundary

Build verification proves packaging and native integration, not network delivery. End-to-end acceptance still requires:

- an Android device or emulator with Google Play services;
- a locally signed physical iPhone with the Study provisioning profile and Push Notifications capability;
- APNs authentication configured for the Study iOS app in `nurio-prod`;
- a signed-in production account so the existing Rails bridge registers the device token;
- foreground, background, terminated-app, invalid-route, permission-denial, and account-reassignment checks from the push runbook.

Local devices intentionally create real production device-token rows and may contribute production Firebase analytics because the user selected always-on production behavior.

## Scope and safety

This change affects only the Hotwire Native Study Android and iOS build paths, focused tests, and push documentation. It does not modify Flutter, the main Nurio clients, Rails, admin/tutor surfaces, or store version numbers. Existing user-owned signing and Xcode project edits must be preserved.
