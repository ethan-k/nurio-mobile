# Nurio Tutors iOS

Standalone Hotwire Native iOS shell for the Nurio tutor web experience.

## Runtime

- Start URL: `https://tutors.nurio.kr`
- Custom callback scheme: `nurio://auth-callback`
- Bundled path configuration: `path-configuration.json`
- OAuth paths intercepted natively:
  - `/auth/google_oauth2`
  - `/auth/kakao`
  - `/auth/naver`

## Scope

- Tutor-facing web flows only
- Admin URLs are never pushed into the in-app navigator
- Customer Flutter migration work stays in `../../flutter_app`

## Commands

```bash
open ios/NurioTutors.xcodeproj
xcodebuild -project ios/NurioTutors.xcodeproj -scheme NurioTutors -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
xcodebuild -project ios/NurioTutors.xcodeproj -scheme NurioTutors -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test
```

Optional runtime base URL override:

```bash
NURIO_BASE_URL=https://tutors.nurio.kr xcodebuild -project ios/NurioTutors.xcodeproj -scheme NurioTutors -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
```

Release archive command after signing is configured:

```bash
xcodebuild -project ios/NurioTutors.xcodeproj -scheme NurioTutors -configuration Release -destination 'generic/platform=iOS' -archivePath build/NurioTutors.xcarchive archive
```

## Submission

For the full App Store Connect and TestFlight workflow, see `docs/SUBMISSION.md`.
