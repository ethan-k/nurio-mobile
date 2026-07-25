# AGENTS.md

## Product Scope (Required)
- The primary customer mobile apps in this repository are the Hotwire Native iOS and Android apps.
- `leaders-nurio-mobile/` is the separate Nurio Study Leader Hotwire Native product for `studyleaders.nurio.kr`; keep its identity, route boundary, OAuth callback, and store records separate from the customer and learner apps.
- `flutter_app/` exists in the repo, but it is not the main app surface and should be treated as out of scope unless the user explicitly asks to work on Flutter.
- Default mobile work should target the named Hotwire Native product and the Rails/Hotwire surface that powers it. If no product is named, default to the customer app.
- Within the customer app targets, implement and maintain customer-facing features only; Study Leader work stays inside `leaders-nurio-mobile/`.
- Do not build, expose, or migrate admin features (`/admin/*`).
- Do not build, expose, or migrate tutor features (`/tutoring*`, `/tutors*`, `tutors.<domain>`).
- In the Study Leader app, handle only `studyleaders.nurio.kr` in-app and open learner, tutor, admin, support, and arbitrary external URLs in the system browser.

## Native-Only Rule (Required)
- Flutter implementation must be native-only.
- Do not add or reintroduce WebView fallback flows.
- Do not route customer features through in-app browser shells.

## Source of Truth
- Customer feature inventory is defined from `/Users/ws/es/business/nurioworkspace/nurio/config/routes.rb`.
- Study Leader product behavior is documented in `/Users/ws/es/business/nurioworkspace/nurio/docs/features/study-leader-portal.md` and implemented by the `studyleaders` route constraint in the same Rails application.
- Payment behavior is defined by:
  - `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/orders_controller.rb`
  - `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/payments/portone_controller.rb`
  - `/Users/ws/es/business/nurioworkspace/nurio/app/javascript/controllers/portone_payment_controller.js`

## Store Release Versioning
- Before building an Android artifact for Play Store submission, bump both `android/app/build.gradle.kts` values: `versionName` to the public release version and `versionCode` to a strictly higher integer than the last Play Store upload.
- For the current Nurio Android store submission, use `versionName = "1.0.5"` and `versionCode = 6`.
- The first Study Leader store release starts at iOS `1.0.0 (1)` and Android `versionName = "1.0.0"`, `versionCode = 1`; increment the build/code before every subsequent upload.

## Architecture Rules
- Keep customer scope boundaries explicit in native navigation and API integration.
- Keep Study Leader scope boundaries explicit and preserve `nurioleaders://auth-callback` on both platforms.
- Never add admin/tutor routes to Flutter feature navigation.
- When backend mobile APIs are missing, keep UX native and show explicit API-gap states.

## Validation Checklist
- `cd flutter_app && flutter analyze`
- `cd flutter_app && flutter test`
- `cd flutter_app && flutter build apk --debug`
- Verify event browse -> event detail -> native checkout page and payment actions remain native-only.
- `xcodebuild -project leaders-nurio-mobile/ios/NurioStudyLeader.xcodeproj -scheme NurioStudyLeader -destination 'platform=iOS Simulator,name=iPhone 17' test`
- `cd leaders-nurio-mobile/android && ./gradlew :app:testDebugUnitTest :app:assembleDebug :app:lintDebug`
- Verify signed-out OAuth handoff, all six leader destinations, external-link escape, EN/KO, and in-app account deletion before store submission.
