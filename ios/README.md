# Nurio iOS

Standalone Hotwire Native iOS shell for the Nurio customer web experience.

## Runtime

- Start URL: `https://nurio.kr/events`
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

## Submission

For the full App Store Connect and TestFlight workflow, see `docs/SUBMISSION.md`.
