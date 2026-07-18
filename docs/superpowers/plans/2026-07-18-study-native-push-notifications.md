# Nurio Study Native Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register Nurio Study iOS and Android installations with the existing Rails device-token API, display FCM notifications, and route notification taps safely inside the Study app.

**Architecture:** Each Study client adds a `register-device-token` Hotwire bridge backed by Firebase Messaging. Permission and token acquisition stay native; the existing signed-in Rails bridge persists the token. Notification data passes through a platform-specific pure destination resolver before the existing Study navigator sees it, and missing Firebase client configuration degrades to a stable bridge error instead of breaking local builds.

**Tech Stack:** Hotwire Native 1.2.6, Kotlin 2.3/JUnit 4, Android Firebase BoM and Firebase Messaging, UIKit/XCTest, Firebase iOS SDK through Swift Package Manager, APNs through FCM, existing Rails 8.1 device-token and FCM services.

---

## Repository and scope boundaries

Implementation is limited to `/Users/ws/es/business/nurioworkspace/nurio-mobile/study-nurio-mobile` plus Study push documentation. Do not modify Flutter, the main `android/` or `ios/` clients, tutor clients, Rails admin/tutor surfaces, or payment behavior.

The current mobile checkout has unrelated user changes. Before Task 1, invoke `superpowers:using-git-worktrees` and create an isolated mobile worktree. Commit only each task's named files. At the end, merge the verified implementation branch into local `main` without staging, restoring, or deleting existing dirty-worktree files.

Firebase Console config files are not available yet. Code and simulator/debug verification must work without them. Do not fabricate or copy the main Nurio config files because their application IDs do not match Study.

## File map

### Android

- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/NotificationDestination.kt`: validate and normalize notification routes.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/NotificationPayload.kt`: map FCM data fields to a safe destination.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/PendingNotificationRoute.kt`: retain one destination until the Hotwire navigator is ready.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/PushRegistrationResult.kt`: stable native bridge payload mapping.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/NotificationChannels.kt`: create the Study notification channel.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/StudyFirebaseMessagingService.kt`: display received messages and create explicit tap intents.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/bridge/RegisterDeviceTokenComponent.kt`: request permission/token and reply to Rails.
- Modify `StudyApplication.kt`: register the bridge and initialize the notification channel.
- Modify `MainActivity.kt`: request Android 13 permission on bridge demand and consume safe tap routes.
- Modify Android Gradle/plugin catalog and manifest files for Firebase and notifications.
- Create focused JUnit tests under `app/src/test/java/com/nurio/study/android/notifications/`.

### iOS

- Create `study-nurio-mobile/ios/NotificationDestination.swift`: validate and normalize notification routes.
- Create `study-nurio-mobile/ios/NativePushTokenStore.swift`: own the current FCM token and stable error payload.
- Create `study-nurio-mobile/ios/Bridge/RegisterDeviceTokenComponent.swift`: request authorization/APNs registration and return the FCM token.
- Modify `AppRouteCoordinator.swift`: queue safe notification routes until a navigator is installed.
- Modify `AppDelegate.swift`: conditionally configure Firebase, register APNs/FCM delegates, present foreground notifications, and route taps.
- Modify `SceneController.swift`: install the route handler through a coordinator method that flushes pending routes.
- Create `study-nurio-mobile/ios/NurioStudy.entitlements`: add `aps-environment`.
- Modify `NurioStudy.xcodeproj/project.pbxproj`: add Firebase packages, new sources, a conditional config-copy build phase, and entitlements.
- Extend `NurioStudyTests.swift` with destination, token payload, and pending-route tests.

### Documentation and verification

- Create `study-nurio-mobile/docs/PUSH_NOTIFICATIONS.md`: Firebase/APNs setup, config validation, server prerequisites, and physical-device acceptance.
- Add no Firebase service-account or APNs credential to the mobile repository.

## Task 1: Android safe notification destination and pending route

**Files:**
- Create: `study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/notifications/NotificationDestinationTest.kt`
- Create: `study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/notifications/PendingNotificationRouteTest.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/NotificationDestination.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/PendingNotificationRoute.kt`

- [ ] **Step 1: Write failing destination tests**

Create tests that assert:

```kotlin
assertEquals("https://study.nurio.kr/events/42", NotificationDestination.resolve("/events/42", null, baseUrl))
assertEquals("https://study.nurio.kr/messages", NotificationDestination.resolve(null, "https://study.nurio.kr/messages", baseUrl))
assertEquals(baseUrl, NotificationDestination.resolve("//evil.example/x", null, baseUrl))
assertEquals(baseUrl, NotificationDestination.resolve("/admin/events", null, baseUrl))
assertEquals(baseUrl, NotificationDestination.resolve(null, "https://evil.example/events", baseUrl))
assertEquals(baseUrl, NotificationDestination.resolve("/events/42#fragment", null, baseUrl))
```

Also test `/tutoring`, `/tutors`, credentials, non-HTTPS URLs, encoded path tricks, and that `path` takes precedence over `url` only when valid.

- [ ] **Step 2: Write the failing pending-route test**

Prove `PendingNotificationRoute.accept(url)` retains the most recent URL, `consume()` returns it once, and a second consume returns null.

- [ ] **Step 3: Run tests and verify RED**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest --tests 'com.nurio.study.android.notifications.*'
```

Expected: compilation fails because both production types are absent.

- [ ] **Step 4: Implement minimal pure Kotlin types**

`NotificationDestination.resolve(path, url, baseUrl)` must parse with `java.net.URI`, require a clean HTTPS base origin, reject user info/fragments/non-default ports/foreign hosts, require literal safe paths, call a shared blocked-prefix check, and return the normalized base root on rejection. `PendingNotificationRoute` stores one nullable string and clears it during `consume()`.

- [ ] **Step 5: Run focused and full Study Android unit tests**

```bash
./gradlew testDebugUnitTest --tests 'com.nurio.study.android.notifications.*'
./gradlew testDebugUnitTest
```

Expected: all tests pass.

- [ ] **Step 6: Commit Task 1**

```bash
git add study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/NotificationDestination.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/PendingNotificationRoute.kt study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/notifications/NotificationDestinationTest.kt study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/notifications/PendingNotificationRouteTest.kt
git commit -m "feat: validate Study Android push destinations"
```

## Task 2: Android registration result contract and Firebase bridge

**Files:**
- Create: `study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/notifications/PushRegistrationResultTest.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/PushRegistrationResult.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/bridge/RegisterDeviceTokenComponent.kt`
- Modify: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/StudyApplication.kt`
- Modify: `study-nurio-mobile/android/gradle/libs.versions.toml`
- Modify: `study-nurio-mobile/android/build.gradle.kts`
- Modify: `study-nurio-mobile/android/app/build.gradle.kts`

- [ ] **Step 1: Write the failing bridge-payload tests**

Define the desired contract with exact serialized JSON:

```kotlin
assertEquals(
    "{\"token\":\"fcm-token\",\"platform\":\"android\"}",
    PushRegistrationResult.success("fcm-token").json
)
assertEquals(
    "{\"platform\":\"android\",\"error\":\"firebase_not_configured\"}",
    PushRegistrationResult.failure(PushRegistrationError.FIREBASE_NOT_CONFIGURED).json
)
assertEquals(PushRegistrationError.TOKEN_UNAVAILABLE, PushRegistrationResult.fromToken(" ").error)
```

Cover every stable error category from the design and ensure exception messages never enter JSON.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest --tests '*PushRegistrationResultTest'
```

Expected: compilation fails because the contract types do not exist.

- [ ] **Step 3: Implement the pure result contract**

Create `PushRegistrationError` enum values with wire strings and a `PushRegistrationResult` that produces the exact bridge JSON through `kotlinx.serialization`. A success requires a trimmed nonblank token; failures contain platform plus stable error only.

- [ ] **Step 4: Run the contract test and verify GREEN**

Run the Step 2 command. Expected: pass.

- [ ] **Step 5: Add Firebase build dependencies with missing-config support**

Pin the Google Services plugin in `libs.versions.toml`, declare it `apply false` at the Android root, and add the Firebase BoM plus Messaging dependency to the app. Apply Google Services only when `app/google-services.json` exists; expose `BuildConfig.FIREBASE_CONFIGURED` from that same condition. This must leave config-less debug compilation working.

- [ ] **Step 6: Implement and register the bridge**

The component handles only `connect`. It asks a `NotificationPermissionHost` implemented by `MainActivity` for permission, checks `BuildConfig.FIREBASE_CONFIGURED`, calls `FirebaseMessaging.getInstance().token`, and replies exactly once with `PushRegistrationResult`. Register `BridgeComponentFactory("register-device-token", ::RegisterDeviceTokenComponent)` beside the OAuth bridge in `StudyApplication`.

- [ ] **Step 7: Verify compilation and tests without Firebase config**

```bash
./gradlew testDebugUnitTest
./gradlew assembleDebug
```

Expected: both commands exit 0 without `google-services.json`.

- [ ] **Step 8: Commit Task 2**

Commit only the files named in this task with subject `feat: register Study Android push tokens`.

## Task 3: Android permission, message display, and tap routing

**Files:**
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/NotificationPayload.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/NotificationChannels.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/notifications/StudyFirebaseMessagingService.kt`
- Create: `study-nurio-mobile/android/app/src/main/res/drawable/ic_notification.xml`
- Modify: `study-nurio-mobile/android/app/src/main/res/values/strings.xml`
- Modify: `study-nurio-mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/StudyApplication.kt`
- Modify: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/MainActivity.kt`

- [ ] **Step 1: Add a failing integration-contract test around intent data extraction**

Extend the pure destination tests to prove the exact FCM data map contract: `path`, `url`, and `tag` are optional; `path` and `url` feed the resolver; invalid values return the Study root. Run the focused tests and observe the new helper/type is absent.

- [ ] **Step 2: Implement notification channel and service**

Create channel ID `nurio_study_notifications` at high importance. The service derives title/body from `RemoteMessage.notification` with data fallback, resolves the destination, and creates an explicit immutable/update-current `PendingIntent` for `MainActivity` containing only `notification_destination`. Catch `SecurityException` when permission is absent. `onNewToken` logs the lifecycle event without logging the token; the signed-in bridge will fetch it on reconnect. Add a pure `NotificationPayload.destination(data, baseUrl)` helper so both service-built intents and SDK-built background launcher intents use the same contract.

- [ ] **Step 3: Implement runtime permission and navigator queue**

`MainActivity` implements `NotificationPermissionHost` using `ActivityResultContracts.RequestPermission`. Concurrent bridge requests share one in-flight permission result. `onCreate` and `onNewIntent` consume either `notification_destination` from the Study service or raw `path`/`url` extras from Firebase's background notification launcher intent, run them through the resolver, and store the result in `PendingNotificationRoute`. `onNavigatorReady` consumes and routes it after existing pending auth routing. Preserve all existing native-auth lifecycle behavior.

- [ ] **Step 4: Update manifest and application startup**

Declare `POST_NOTIFICATIONS`, the Firebase service, default Study icon/channel metadata, and call `NotificationChannels.ensureCreated(this)` in `StudyApplication.onCreate`.

- [ ] **Step 5: Verify Android**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest
./gradlew assembleDebug
```

Expected: all tests and the config-less debug build pass.

- [ ] **Step 6: Commit Task 3**

Commit only Task 3 files with subject `feat: handle Study Android push notifications`.

## Task 4: iOS destination resolution and queued routing

**Files:**
- Create: `study-nurio-mobile/ios/NotificationDestination.swift`
- Modify: `study-nurio-mobile/ios/AppRouteCoordinator.swift`
- Modify: `study-nurio-mobile/ios/SceneController.swift`
- Modify: `study-nurio-mobile/ios/Tests/NurioStudyTests.swift`
- Modify: `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing XCTest destination cases**

Add tests equivalent to Android for valid relative paths, valid same-origin HTTPS URLs, path precedence, foreign hosts, credentials, fragments, non-HTTPS URLs, scheme-relative paths, `/admin`, `/tutoring`, and `/tutors`.

- [ ] **Step 2: Write failing coordinator queue test**

With a `NavigationHandlerSpy`, prove `handleNotification(path:url:)` called before `installNavigationHandler` is delivered once after installation, while a later valid notification routes immediately.

- [ ] **Step 3: Run XCTest and verify RED**

```bash
xcodebuild test -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

If that simulator is unavailable, select an installed iPhone simulator from `xcrun simctl list devices available` and record the destination. Expected: compile failure for missing destination/coordinator APIs.

- [ ] **Step 4: Implement resolver and coordinator queue**

`NotificationDestination.resolve(path:url:baseURL:)` mirrors Android policy using `URLComponents` and returns the Study root on rejection. `AppRouteCoordinator` stores one pending notification URL, exposes `installNavigationHandler(_:)`, flushes once, and keeps existing auth-callback handling unchanged. Update `SceneController` to call the install method.

- [ ] **Step 5: Add the source to the Xcode project and verify GREEN**

Run the Step 3 command. Expected: all Study iOS tests pass.

- [ ] **Step 6: Commit Task 4**

Commit only Task 4 files with subject `feat: validate Study iOS push destinations`.

## Task 5: iOS token bridge, Firebase/APNs lifecycle, and notification responses

**Files:**
- Create: `study-nurio-mobile/ios/NativePushTokenStore.swift`
- Create: `study-nurio-mobile/ios/Bridge/RegisterDeviceTokenComponent.swift`
- Create: `study-nurio-mobile/ios/NurioStudy.entitlements`
- Modify: `study-nurio-mobile/ios/AppDelegate.swift`
- Modify: `study-nurio-mobile/ios/Tests/NurioStudyTests.swift`
- Modify: `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing token-store tests**

Test that a new store returns `{ token: nil, platform: "ios", error: "token_unavailable" }`, a nonblank update returns the token without an error, blank updates are ignored, and explicit stable errors never contain raw exception text.

- [ ] **Step 2: Run XCTest and verify RED**

Run the Task 4 XCTest command. Expected: compile failure because `NativePushTokenStore` is absent.

- [ ] **Step 3: Implement the token store and verify GREEN**

Use an `@MainActor` store with an injectable initializer for tests, a fixed `ios` platform, nonblank update validation, and an `Encodable` response containing only token/platform/stable error. Re-run XCTest.

- [ ] **Step 4: Add Firebase package products and conditional configuration**

Add the same pinned Firebase iOS SDK version used by the main app, selecting `FirebaseCore` and `FirebaseMessaging`. Add a build phase that copies `$SRCROOT/GoogleService-Info.plist` into the built app only when the file exists; do not add a mandatory resource reference and do not copy the main config. At launch, check `FirebaseOptions.defaultOptions()` before calling `FirebaseApp.configure(options:)`; when absent, retain `firebase_not_configured` and continue normal app startup.

- [ ] **Step 5: Implement APNs/FCM and the bridge**

`AppDelegate` sets Messaging and notification-center delegates only after successful Firebase setup, forwards APNs tokens, caches refreshed FCM tokens, presents banner/sound/badge in the foreground, and handles notification responses by passing `path`/`url` strings to `AppRouteCoordinator.handleNotification`. The bridge requests authorization on `connect`, accepts authorized/provisional/ephemeral states, registers for remote notifications on the main actor, fetches `Messaging.messaging().token`, and returns a stable error when denied, failed, unavailable, or unconfigured.

- [ ] **Step 6: Add push entitlement**

Create:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>$(APS_ENVIRONMENT)</string>
</dict>
</plist>
```

Reference it through `CODE_SIGN_ENTITLEMENTS` for the Study target. Set `APS_ENVIRONMENT = development` in Debug and `APS_ENVIRONMENT = production` in Release so the entitlement agrees with the matching provisioning profile; never hard-code APNs credentials.

- [ ] **Step 7: Verify config-less iOS tests and build**

```bash
xcodebuild test -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Expected: both commands exit 0 without a Study Firebase plist.

- [ ] **Step 8: Commit Task 5**

Commit only Task 5 files with subject `feat: handle Study iOS push notifications`.

## Task 6: Operational runbook and full verification

**Files:**
- Create: `study-nurio-mobile/docs/PUSH_NOTIFICATIONS.md`

- [ ] **Step 1: Write the runbook**

Document exact Firebase app registrations, config destinations, Android application ID, iOS bundle ID/capability/provisioning requirements, APNs key upload, Rails FCM environment prerequisite, safe token inspection, foreground/background/terminated test cases, account reassignment, permission denial, and rollback. Explicitly state that client config is not proof of server credential availability and that end-to-end delivery requires physical devices.

- [ ] **Step 2: Run secret-safe configuration checks**

Use `plutil`/`jq` to print only project ID and bundle/application ID. Use `rg` patterns only for any secret-leak check. Never print token values or credential payloads.

- [ ] **Step 3: Run fresh full verification**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest assembleDebug
cd ../../ios
xcodebuild test -project NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project NurioStudy.xcodeproj -scheme NurioStudy -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
cd ../..
git diff --check
```

Expected: Android tests/build and iOS tests/build exit 0; `git diff --check` is silent.

- [ ] **Step 4: Inspect requirement coverage**

Confirm the final diff contains both bridge registrations, both platform token paths, Android permission/service/channel, iOS APNs/FCM delegates and entitlement, tap routing through safe resolvers, config-less behavior, tests, and the runbook. Confirm no main-app, Flutter, admin, tutor, credential, or user-owned dirty files appear.

- [ ] **Step 5: Commit documentation**

```bash
git add study-nurio-mobile/docs/PUSH_NOTIFICATIONS.md
git commit -m "docs: add Study push notification runbook"
```

- [ ] **Step 6: Request code review and finish the branch**

Invoke `superpowers:requesting-code-review`, address confirmed findings, rerun the full verification commands, then invoke `superpowers:finishing-a-development-branch`. Merge the verified branch into local `main` while preserving the pre-existing dirty worktree.

## External acceptance checkpoint

Code completion and simulator/debug builds do not prove live push delivery. After implementation, the remaining external steps are:

1. Create `com.nurio.study.android` and `com.nurio.study.ios` inside `nurio-prod` Firebase.
2. Place the downloaded Study config files in their documented app locations.
3. Enable the Study iOS Push Notifications capability and regenerate the profile.
4. Upload the APNs authentication key to Firebase.
5. Confirm production Rails FCM HTTP v1 credentials target `nurio-prod`.
6. Run the physical-device acceptance matrix from the approved design.
