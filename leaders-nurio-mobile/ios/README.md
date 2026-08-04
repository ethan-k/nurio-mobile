# Nurio Study Leader iOS

Hotwire Native iPhone shell for `https://studyleaders.nurio.kr`.

## Identity

- Project/scheme: `NurioStudyLeader`
- Bundle ID: `com.nurio.studyleaders.ios`
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

The `sign-in-with-oauth` bridge dispatches Google and Kakao to their native iOS
SDKs. Configure the dedicated Kakao Native app key, Study Leader Google iOS
client ID, existing Web/server client ID, and Google reversed client ID through
the protected native-auth xcconfig described in
[`../docs/OAUTH_AND_REVIEW_LOGIN.md`](../docs/OAUTH_AND_REVIEW_LOGIN.md).
Naver remains in `ASWebAuthenticationSession`.
