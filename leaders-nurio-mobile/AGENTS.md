# Nurio Study Leader Mobile Guidance

## Scope

- This folder owns the Hotwire Native iOS and Android apps for `https://studyleaders.nurio.kr`.
- The product name is **Nurio Study Leader**.
- Keep iOS and Android behavior at parity unless a platform policy requires a documented difference.
- Do not navigate `/admin`, `nurio.kr`, `study.nurio.kr`, or `tutors.nurio.kr` inside the app. Open out-of-scope web links in the system browser.

## Architecture

- Rails/Hotwire remains the source of UI and business behavior.
- Native code owns the app lifecycle, OAuth handoff, URL/deep-link policy, platform navigation, and future push/bridge features.
- The native top bar stays hidden because the leader portal already supplies its own responsive navigation.
- Use `nurioleaders://auth-callback` only for the signed, single-use native OAuth handoff.

## Verification

- iOS: build and test `ios/NurioStudyLeader.xcodeproj`, scheme `NurioStudyLeader`.
- Android: run `./gradlew :app:testDebugUnitTest :app:assembleDebug :app:lintDebug`.
- Verify signed-out login, approved-leader Today/Schedule/Sessions/Earnings/Settings, EN/KO switching, external-link handling, and account deletion.
- Store screenshots must be simulator/device captures of the shipped app. Do not substitute generated UI.

## Store Asset Location

- Always save the complete logo and ASO delivery bundle under `/Users/ws/es/business/nurioworkspace/nurio_appstore/nurio-study-leader/`.
- This includes editable logo sources, Apple and Google store icons, feature graphics, real-device screenshots, preview media, localized metadata exports, and upload bundles.
- Keep only runtime icon resources and source files required by the native build in this repository. Do not commit generated marketing screenshots or other store promotional binaries.
