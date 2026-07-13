# Nurio Study iOS

Standalone Hotwire Native iOS shell for the Nurio Study web experience.

## Runtime

- Start URL: `https://study.nurio.kr`
- Custom callback scheme: `nurio://auth-callback`
- Bundled path configuration: `path-configuration.json`
- OAuth paths intercepted natively:
  - `/auth/google_oauth2`
  - `/auth/kakao`
  - `/auth/naver`

## Scope

- Study-facing web flows only
- Admin and tutor/tutoring URLs are never pushed into the in-app navigator
- Android parity source stays in `android/`

## Commands

```bash
open ios/NurioStudy.xcodeproj
xcodebuild -project ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
xcodebuild -project ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test
```

Optional runtime base URL override:

```bash
NURIO_BASE_URL=https://study.nurio.kr xcodebuild -project ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
```

Release archive command after signing is configured:

```bash
xcodebuild -project ios/NurioStudy.xcodeproj -scheme NurioStudy -configuration Release -destination 'generic/platform=iOS' -archivePath build/NurioStudy.xcarchive archive
```

## Submission

For the full App Store Connect and TestFlight workflow, see `docs/SUBMISSION.md`.
