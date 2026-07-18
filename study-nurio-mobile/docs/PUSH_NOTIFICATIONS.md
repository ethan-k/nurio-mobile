# Nurio Study push notifications

The Study iOS and Android apps use Firebase Cloud Messaging (FCM). Native clients request permission only after the signed-in Rails page connects the `register-device-token` bridge, then return the FCM token to the existing production Rails device-token endpoint.

Every Debug and Release build requires the Study production Firebase configuration and uses `https://study.nurio.kr`. Local devices therefore register real production tokens.

## Firebase app registration

Use the existing Firebase project `nurio-prod` and register two distinct apps:

- Android package: `com.nurio.study.android`
- iOS bundle ID: `com.nurio.study.ios`

Do not copy a Firebase configuration from the main Nurio app. Its package or bundle ID is different, and each client rejects a mismatched configuration.

The Study-specific production configuration source files are:

- `/Users/ws/es/business/nurioworkspace/nurio_study/mobile_certs/nurio-study-google-services.json`
- `/Users/ws/es/business/nurioworkspace/nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist`

Android stages its source into the ignored `study-nurio-mobile/android/app/google-services.json` plugin location during the build. iOS copies its source directly into the built app. Neither source file is committed to this repository.

Confirm their identity without printing credential values:

```sh
jq -r '.project_info.project_id, (.client[].client_info.android_client_info.package_name)' \
  /Users/ws/es/business/nurioworkspace/nurio_study/mobile_certs/nurio-study-google-services.json

plutil -extract PROJECT_ID raw \
  /Users/ws/es/business/nurioworkspace/nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist
plutil -extract BUNDLE_ID raw \
  /Users/ws/es/business/nurioworkspace/nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist
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

Run the production-shaped Debug and Release verification from the mobile repository root:

```sh
bash study-nurio-mobile/scripts/verify_production_push_builds.sh
```

This validates only project/application identifiers, then runs Android unit tests and Debug/Release assembly, iOS Debug/Release simulator packaging, and the full iOS XCTest suite. It never prints Firebase API keys or registration tokens.

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

Build verification proves that production Firebase is packaged correctly. Live delivery is not verified until APNs setup, backend credentials, and physical devices are exercised.

## Rollback

The production Firebase files are mandatory, so removing either source intentionally stops new builds with a stable configuration error. For a store rollback, ship the last verified app version while keeping the backend token endpoint and existing token cleanup intact. To revert the always-production build policy, revert the dedicated Android and iOS build-wiring commits rather than substituting another app's Firebase files.
