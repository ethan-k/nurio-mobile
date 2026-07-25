# Nurio Study Leader iOS

Hotwire Native iPhone shell for `https://studyleaders.nurio.kr`.

## Identity

- Project/scheme: `NurioStudyLeader`
- Bundle ID: `com.nurio.studyleader.ios`
- Callback: `nurioleaders://auth-callback`
- Minimum iOS: 15.6
- Version/build: `1.0.0` / `1`

## Build and Test

```bash
xcodebuild \
  -project NurioStudyLeader.xcodeproj \
  -scheme NurioStudyLeader \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  build

xcodebuild \
  -project NurioStudyLeader.xcodeproj \
  -scheme NurioStudyLeader \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  test
```

The app is iPhone-only for 1.0. Native navigation bars remain hidden on every Hotwire visit, while external hosts and `/admin` open outside the app.
