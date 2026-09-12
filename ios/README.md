# Nurio iOS

Standalone Hotwire Native iOS shell for the Nurio customer web experience.

## Hotwire Native dependency

The customer target pins Hotwire Native **1.3.1**. Its custom route handlers use
`VisitProposal` and `Navigating`; request failures use `HotwireNativeError`.
The upgrade preserves 401 sign-in routing, checkout session selection, and the
restriction against retrying an external gateway URL.

`RequestErrorPresentation` passes an optional retry handler directly to
Hotwire's error-view factory. This avoids the 1.3.1 default presenter's wrapping
of a nil handler, which would otherwise expose an ineffective Retry button.
Payment telemetry distinguishes missing Turbo, Turbo not ready, invalid
responses, HTTP errors, and wrapped URL-loading failures without retaining raw
error messages or URLs.

See the [1.3.1 release notes](https://github.com/hotwired/hotwire-native-ios/releases/tag/1.3.1)
and [1.3.0 API migration notes](https://github.com/hotwired/hotwire-native-ios/releases/tag/1.3.0).
An installed release still needs payment-app handoff/return and modal checkout
verification on a physical iPhone.

## Runtime

- Start URL: `https://nurio.kr/`; the server sends signed-out users to `/login` and signed-in users to `/events`
- Custom callback scheme: `nurio://auth-callback`
- Bundled path configuration: `../shared/configurations/ios_v1.json`
- OAuth paths intercepted natively:
  - `/auth/google_oauth2`
  - `/auth/kakao`
  - `/auth/naver`

## Scope

- Customer-facing web flows only
- Admin and tutor/tutoring URLs are never pushed into the in-app navigator
- Flutter migration work stays in `../flutter_app`

## Commands

```bash
open ios/Nurio.xcodeproj
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test
```

Optional runtime base URL override:

```bash
NURIO_BASE_URL=https://nurio.kr xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
```

Release archive command after signing is configured:

```bash
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -configuration Release -destination 'generic/platform=iOS' -archivePath build/Nurio.xcarchive archive
```

## Payments

The checkout → KG Inicis handoff has hard constraints (POST-only navigation,
single reused web view). Read `docs/PAYMENT_FLOW.md` before changing anything in
`Payments/` or checkout navigation.

## Submission

For the full App Store Connect and TestFlight workflow, see `docs/SUBMISSION.md`.
