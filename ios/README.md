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

## Server configurations and Xcode schemes

Choose a scheme beside the Run button in Xcode:

| Scheme | Run configuration | Embedded server | Debugger |
| --- | --- | --- | --- |
| `Nurio Local` | Local | `http://localhost:3000` by default | Yes |
| `Nurio Production Debug` | Debug | `https://nurio.kr` | Yes |
| `Nurio Release` | Release | `https://nurio.kr` | No |

The original `Nurio` scheme remains compatible with existing scripts: Run/Test use
production Debug, and Archive uses Release. All schemes archive using Release.
The Release scheme runs and profiles optimized code; its unit tests use Debug
so the test target can access internal app types.

`Config/Local.xcconfig` or `Config/ProductionDebug.xcconfig` / `Config/Production.xcconfig`
sets `NURIO_BASE_URL`. Xcode expands it into `NurioBaseURL` in the app's `Info.plist`.
`AppEnvironment.swift` reads and validates that embedded value. It survives fresh
launches from the Home Screen, unlike a launch-only environment variable.

Only Local includes the optional, Git-ignored `Config/LocalOverrides.xcconfig`.
Copy `Config/LocalOverrides.xcconfig.example` to that filename to set your Mac's
LAN host for a physical iPhone. `localhost` on an iPhone means the iPhone itself;
Simulator can use the Mac's localhost. Start Rails listening on `0.0.0.0` and use
a reachable `.local` hostname on the same network. Local's preprocessed Info.plist
enables local-network HTTP and supplies the local-network permission description;
production builds omit these additions. Keep the `:/$()/` URL spelling in xcconfig
files because a literal double slash starts a comment.

For a one-launch exception, Debug/Local builds also accept `NURIO_BASE_URL` in
**Edit Scheme → Run → Arguments → Environment Variables**, or via `devicectl`'s
`--environment-variables`. Release ignores launch overrides. Setting a shell
variable before `xcodebuild build` does not pass it to a future app process.

## Commands

```bash
open ios/Nurio.xcodeproj
xcodebuild -project ios/Nurio.xcodeproj -scheme 'Nurio Production Debug' -destination 'generic/platform=iOS' build
xcodebuild -project ios/Nurio.xcodeproj -scheme 'Nurio Local' -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
xcodebuild -project ios/Nurio.xcodeproj -scheme 'Nurio Release' -destination 'generic/platform=iOS' -archivePath build/Nurio.xcarchive archive
```

Production Debug uses the existing bundle identifier and replaces the installed
customer app when installed on your device. It is intended for debugging against
the live service; it does not change the store version or publish a release.

## Payments

The checkout → KG Inicis handoff has hard constraints (POST-only navigation,
single reused web view). Read `docs/PAYMENT_FLOW.md` before changing anything in
`Payments/` or checkout navigation.

## Submission

For the full App Store Connect and TestFlight workflow, see `docs/SUBMISSION.md`.
