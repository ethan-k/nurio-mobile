# Nurio Study Leader Mobile

Hotwire Native iOS and Android clients for the approved-leader workspace at `https://studyleaders.nurio.kr`.

## App Identity

| Item | iOS | Android |
| --- | --- | --- |
| Product | Nurio Study Leader | Nurio Study Leader |
| Identifier | `com.nurio.studyleader.ios` | `com.nurio.studyleader.android` |
| OAuth callback | `nurioleaders://auth-callback` | `nurioleaders://auth-callback` |
| Version | `1.0.0` (build 1) | `1.0.0` (code 1) |
| Start URL | `https://studyleaders.nurio.kr` | `https://studyleaders.nurio.kr` |

The app keeps leader routes in-app and opens other hosts or `/admin/*` in the system browser. The native top navigation is hidden because the responsive leader portal already provides six destinations: Today, Schedule, Notifications, Sessions, Earnings, and Settings.

## Local Checks

### iOS

```bash
xcodebuild \
  -project ios/NurioStudyLeader.xcodeproj \
  -scheme NurioStudyLeader \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  build

xcodebuild \
  -project ios/NurioStudyLeader.xcodeproj \
  -scheme NurioStudyLeader \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  test
```

Override the server only for local QA:

```bash
NURIO_BASE_URL=http://studyleaders.lvh.me:3000 xcodebuild ...
```

### Android

```bash
cd android
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew \
  :app:testDebugUnitTest \
  :app:assembleDebug \
  :app:lintDebug
```

## Documentation

- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [OAuth and store review login](docs/OAUTH_AND_REVIEW_LOGIN.md)
- [Launch checklist](docs/LAUNCH_CHECKLIST.md)
- [ASO and store assets](docs/ASO.md)
- [iOS submission](ios/docs/SUBMISSION.md)
- [Android setup](android/README.md)

Generated marketing screenshots and store graphics are intentionally kept outside the source repository. The launch bundle lives under `/Users/ws/es/business/nurioworkspace/nurio_appstore/nurio-study-leader/`.
