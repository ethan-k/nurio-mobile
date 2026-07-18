# Nurio Study push notifications

The Study iOS and Android apps use Firebase Cloud Messaging (FCM). Native clients request permission only after the signed-in Rails page connects the `register-device-token` bridge, then return the FCM token to the existing Rails device-token endpoint.

Both apps build without Firebase configuration. In that state registration returns `firebase_not_configured`; live delivery is intentionally unavailable.

## Firebase app registration

Use the existing Firebase project `nurio-prod` and register two distinct apps:

- Android package: `com.nurio.study.android`
- iOS bundle ID: `com.nurio.study.ios`

Do not copy a Firebase configuration from the main Nurio app. Its package or bundle ID is different, and each client rejects a mismatched configuration.

Download the new Study-specific configuration files into these local paths:

- `study-nurio-mobile/android/app/google-services.json`
- `study-nurio-mobile/ios/GoogleService-Info.plist`

These paths are ignored by Git. Confirm their identity without printing credential values:

```sh
jq -r '.project_info.project_id, (.client[].client_info.android_client_info.package_name)' \
  study-nurio-mobile/android/app/google-services.json

plutil -extract PROJECT_ID raw study-nurio-mobile/ios/GoogleService-Info.plist
plutil -extract BUNDLE_ID raw study-nurio-mobile/ios/GoogleService-Info.plist
```

Expected values are `nurio-prod`, `com.nurio.study.android`, and `com.nurio.study.ios` respectively.

## Apple and backend prerequisites

For iOS physical-device delivery:

1. Enable Push Notifications for the `com.nurio.study.ios` App ID in the Apple Developer portal.
2. Regenerate or refresh the development and distribution provisioning profiles.
3. Upload the production APNs authentication key to the `nurio-prod` Firebase project's Cloud Messaging settings. Confirm the key has access to the Study App ID.
4. Build with a signing team/profile that includes the `aps-environment` entitlement. Debug uses `development`; Release uses `production`.

The Rails application at `/Users/ws/es/business/nurioworkspace/nurio` must have working FCM HTTP v1 credentials for the same `nurio-prod` project. The native apps only register tokens and handle delivery; the Rails notification sender remains the source of outgoing messages.

## Payload and navigation contract

Messages may provide a relative `path` or an absolute `url`. Navigation accepts only HTTPS URLs on `study.nurio.kr` and rejects admin, tutor, encoded-path, user-info, fragment, and non-default-port destinations. Invalid or missing destinations open the Study root.

Use data fields for deterministic tap routing:

```json
{
  "path": "/study/example"
}
```

Do not log FCM registration tokens, APNs device tokens, Firebase credential contents, or full notification payloads.

## Build verification

Android:

```sh
cd study-nurio-mobile/android
./gradlew testDebugUnitTest assembleDebug
```

iOS simulator:

```sh
xcodebuild test -quiet \
  -derivedDataPath /tmp/nurio-study-push-derived-data \
  -project study-nurio-mobile/ios/NurioStudy.xcodeproj \
  -scheme NurioStudy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build -quiet \
  -derivedDataPath /tmp/nurio-study-push-build \
  -project study-nurio-mobile/ios/NurioStudy.xcodeproj \
  -scheme NurioStudy \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

## Physical-device acceptance checklist

Use signed-in Study accounts on one Android device and one iPhone:

- Permission is requested only after sign-in reaches a page containing the token bridge.
- Allowing permission registers an FCM token with Rails for the correct account and platform.
- Denying permission does not repeatedly prompt; enabling it later in system settings allows registration.
- A foreground notification is visible and tapping it opens the validated Study destination.
- A background notification opens the validated Study destination.
- A notification tapped from a terminated app is retained until native navigation is ready, then opens once.
- Invalid, cross-origin, encoded, admin, and tutor destinations fall back to `https://study.nurio.kr`.
- Signing out and signing into another account reassigns the device token through the existing Rails endpoint.
- Sending to a stale token causes the existing backend cleanup path to deactivate or remove it.

Live push delivery is not verified until the Study-specific Firebase files, APNs setup, backend credentials, and physical devices are available.

## Rollback

To disable registration without exposing another app's credentials, remove the two local Study Firebase configuration files and rebuild. Both clients remain usable and report `firebase_not_configured` to the bridge. For a store rollback, ship the last verified app version while keeping the backend token endpoint and existing token cleanup intact.
