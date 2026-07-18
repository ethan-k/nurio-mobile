# Nurio Study Native Push Notifications Design

## Goal

Enable ordinary customer push notifications in both Nurio Study Hotwire Native apps and connect them to the existing Rails `DeviceToken` and FCM delivery pipeline.

The implementation targets:

- iOS bundle `com.nurio.study.ios` under `study-nurio-mobile/ios/`;
- Android package `com.nurio.study.android` under `study-nurio-mobile/android/`;
- the existing customer-facing token registration surface in `/Users/ws/es/business/nurioworkspace/nurio`.

Flutter, admin, tutor, VoIP calling, and the main Nurio mobile clients are outside this change. The apps will use Firebase Cloud Messaging for ordinary notifications; iOS delivery will use APNs through FCM.

## Current State

Rails already renders a hidden `bridge--register-device-token` controller for signed-in accounts. The controller requests a native token through the `register-device-token` Hotwire bridge and posts `{ token, platform }` to `POST /api/v1/device_tokens`. `Notifications::FcmSender` sends notification and navigation data to every registered native token and removes tokens that FCM reports as unregistered.

The main Nurio clients contain implementations of this bridge. The Study clients do not:

- Study Android has no Firebase plugin or Messaging dependency, notification permission, FCM service, channel, bridge component, or notification destination handling.
- Study iOS has no Firebase SDK products, APNs entitlement, notification registration, token store, bridge component, foreground presentation, or notification response handling.
- Firebase does not yet contain checked-in configuration files for the Study bundle IDs.

As a result, the backend is capable of delivery but no Study installation can register a token.

## Approaches Considered

### 1. Study-specific integration using the existing Hotwire bridge (selected)

Add focused Android and iOS implementations under `study-nurio-mobile`, modeled on the main clients while preserving Study scope rules. This reuses the authenticated Rails registration path and does not disturb released main-app code.

### 2. Extract a shared native push module

Shared source would reduce duplication, but the iOS and Android projects are independent application targets without an existing shared-module boundary. Introducing one would increase build-system and release risk beyond the feature.

### 3. Register tokens through direct native HTTP clients

Native API calls could bypass the bridge, but they would duplicate authentication, session, retry, and account-switch behavior already handled by the rendered Rails controller. This would create a second token-registration protocol without a product need.

## Firebase Project and App Registration

Production Study apps will be registered as separate apps inside the existing `nurio-prod` Firebase project:

- Android application ID: `com.nurio.study.android`;
- iOS bundle ID: `com.nurio.study.ios`.

Using the same Firebase project is required by the current Rails sender, which signs FCM HTTP v1 requests with one project credential. A separate Firebase project would require backend credential selection by token/application and is not part of this implementation.

The Firebase Console artifacts are application configuration, not service-account credentials:

- `study-nurio-mobile/android/app/google-services.json`;
- `study-nurio-mobile/ios/GoogleService-Info.plist`.

The apps must still compile when these files are absent so local contributors are not forced to carry production configuration. In that state, the bridge returns a sanitized `firebase_not_configured` error and no token is posted. A store or real-device build intended to receive notifications must include configuration whose project and bundle/application IDs match the Study app.

For iOS, the Study App ID must have the Push Notifications capability and its provisioning profile must contain `aps-environment`. The APNs authentication key must be uploaded to the `nurio-prod` Firebase project. No APNs key or Firebase service-account credential belongs in this repository.

## End-to-End Data Flow

1. A signed-in Study page renders the existing hidden `bridge--register-device-token` element.
2. The Rails Stimulus bridge sends a `connect` message to the Study native component.
3. Native verifies Firebase configuration and notification authorization.
4. Native asks FCM for the current registration token.
5. Native replies with `{ token, platform }` or a stable, sanitized error code.
6. The Rails controller posts the token to `/api/v1/device_tokens` in the signed-in session.
7. Rails assigns the globally unique token to the current account and stores its platform.
8. `Notifications::FcmSender` sends a title, body, `path`, `url`, and `tag` through the existing FCM project.
9. Native displays the notification and routes a user tap to an allowed Study destination.

FCM token refresh updates the native in-memory token state. Registration is requested again whenever the signed-in bridge reconnects; the existing Rails controller's 24-hour local cache prevents redundant posts. Account changes remain safe because that cache key includes the Rails account ID and the backend reassigns a globally unique token to the current account.

## Notification Permission UX

Permission is requested only after a signed-in page activates the token bridge. The apps do not display an OS notification prompt on first launch or on the sign-in screen.

- On Android 13 and newer, the bridge requests `POST_NOTIFICATIONS` from the active Study activity. Older supported Android versions do not require a runtime prompt.
- On iOS, the bridge requests alert, badge, and sound authorization, then registers for remote notifications only when permission is granted or already authorized.
- A denial is returned as `notification_permission_denied`. The apps do not repeatedly prompt after denial; users must re-enable notification access in system settings.
- Provisional or ephemeral iOS authorization is treated as usable.

The current Rails notification settings page remains the user-facing explanation and settings entry point. This design does not add a new native settings screen.

## Android Components

Study Android will add the Google Services plugin declaration, Firebase BoM, Firebase Messaging dependency, and conditional Google Services configuration. The manifest will add:

- `POST_NOTIFICATIONS` permission;
- a Study FCM service for `com.google.firebase.MESSAGING_EVENT`;
- the default notification channel ID and icon metadata.

`StudyApplication` will create the notification channel and register `RegisterDeviceTokenComponent` alongside the existing OAuth bridge.

The token component will separate permission/configuration state from token acquisition so local unit tests can cover response mapping. It will reply once per bridge request with either a nonblank Android token or a stable error code; raw Firebase exception messages will be logged only in debug-safe form and will not be sent to the web page.

The messaging service will display foreground/data messages using the Study notification channel. It will put a sanitized `path` on an explicit `MainActivity` intent. `MainActivity` will consume notification destinations on both cold launch and `onNewIntent`, queue them until the navigator is ready, and route them through the same Study scope policy used for incoming links.

## iOS Components

The Study iOS target will add the pinned Firebase iOS SDK package and `FirebaseCore` plus `FirebaseMessaging` products. It will include a Study push entitlement file referenced by both build configurations.

`AppDelegate` will conditionally configure Firebase from `GoogleService-Info.plist`, install Messaging and `UNUserNotificationCenter` delegates only when configuration is valid, pass APNs tokens to FCM, receive refreshed FCM tokens, show foreground banners, and forward notification responses to the Study route coordinator.

`NativePushTokenStore` will own the latest nonblank FCM token and stable bridge response data. `RegisterDeviceTokenComponent` will request authorization, register for APNs, and resolve the FCM token before replying to Rails. It will not expose raw Firebase or APNs errors.

Notification taps will resolve `path` first and then same-origin `url`. The resulting URL will be handed to `AppRouteCoordinator`, which already applies Study scope and native navigation handling. Cold-launch responses will be retained until `SceneController` installs the navigator handler.

## Destination Safety

Notification data is untrusted input even though it is sent by the Nurio backend. Both clients will use a small, testable destination resolver with these rules:

- accept only relative paths beginning with exactly one `/`, or absolute HTTPS URLs whose host equals the configured Study host;
- reject scheme-relative paths, embedded credentials, fragments used as a substitute for a path, non-HTTPS absolute URLs, and foreign hosts;
- normalize accepted same-origin absolute URLs to the configured Study origin;
- reject `/admin`, `/tutoring`, `/tutors`, and other paths already blocked by the Study scope policy;
- fall back to the Study root when notification data is absent or invalid.

This resolver is used for notification taps only. It does not loosen existing universal-link, OAuth, or in-app navigation policies.

## Error Handling and Observability

Native-to-web errors use stable categories:

- `firebase_not_configured`;
- `notification_permission_denied`;
- `notification_permission_failed`;
- `token_unavailable`.

Native logs may include the category and platform lifecycle phase. They must not include FCM tokens, APNs device tokens, Firebase configuration payloads, notification bodies, signed authentication callbacks, or service credentials.

If Firebase initialization fails, the rest of the Study app continues to work. If notification display permission is absent, incoming data is not promoted to a local notification. If a tap contains an invalid destination, the app routes to the Study root rather than opening an external browser or blocked area.

The existing backend behavior remains authoritative: missing FCM server configuration causes delivery to be skipped and logged, while FCM `UNREGISTERED` responses remove stale device-token rows.

## Testing

### Android

- Unit tests cover permission-state mapping, token success/error response mapping, and notification destination acceptance/rejection.
- Unit tests cover notification intent extraction and navigator queue behavior without depending on live Firebase.
- The Study unit-test suite and debug APK build must pass without a Firebase config file.
- A config-validation task verifies that a supplied `google-services.json` matches `nurio-prod` and `com.nurio.study.android` before a release artifact is produced.

### iOS

- Unit tests cover token-store response mapping and notification destination acceptance/rejection.
- Unit tests cover cold-launch notification queuing and delivery once a navigator is installed.
- The `NurioStudy` scheme builds and tests for an iOS Simulator without Firebase configuration or code signing.
- A config-validation build phase or script verifies a supplied plist matches `nurio-prod` and `com.nurio.study.ios` before archive use.

### Rails

No Rails behavior change is expected. Existing request and service specs for `/api/v1/device_tokens`, the native registration Stimulus controller, and `Notifications::FcmSender` are the regression boundary. If current Study-host rendering does not include the hidden bridge for a signed-in account, a narrowly scoped Rails fix and request spec may be added; otherwise the backend remains untouched.

### Physical-device acceptance

For each platform:

1. Install a build containing the matching Study Firebase configuration.
2. Sign in and accept notification permission.
3. Confirm Rails stores one token with the correct account and platform without exposing the token in UI or logs.
4. Send a foreground notification and confirm visible presentation.
5. Send a background notification and confirm visible presentation.
6. Terminate the app, send a notification, tap it, and confirm the requested Study page opens.
7. Send invalid and blocked destinations and confirm they open the Study root.
8. Sign out, sign in as another account, and confirm the token is reassigned to the current account.
9. Disable permission in system settings and confirm the app remains usable without repeated prompts.

## Rollout and Operational Requirements

Before physical-device verification or store release:

1. Create both Study app records inside `nurio-prod` Firebase.
2. Add the correct Android signing fingerprints if required by Firebase services.
3. Add the Study iOS Push Notifications capability and regenerate provisioning profiles.
4. Upload the APNs authentication key to Firebase.
5. Supply the two matching client configuration files through the release environment.
6. Confirm the Rails production environment has working FCM HTTP v1 credentials for `nurio-prod`.
7. Test token creation and delivery on one physical Android device and one physical iOS device.

Code-level completion can be verified without production Firebase files. End-to-end delivery cannot be claimed until the external console configuration, server credentials, signed builds, and physical devices have all been exercised.
