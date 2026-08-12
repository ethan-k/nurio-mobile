# Nurio Study Leader Android

Hotwire Native Android shell for `https://studyleaders.nurio.kr`.

## Identity

- Package: `com.nurio.studyleaders.android`
- Callback: `nurioleaders://auth-callback`
- Minimum SDK: 28
- Target/compile SDK: 36
- Version: `1.0.0` (`versionCode = 1`)

## Build

```bash
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew \
  :app:testDebugUnitTest \
  :app:assembleDebug \
  :app:lintDebug
```

For release signing, copy `keystore.properties.example` to the ignored `keystore.properties` file and use the Play upload key. Never commit the keystore or passwords.

For local emulator QA, keep the production default unchanged and override the
debug build explicitly. The `adb reverse` mapping preserves the
`studyleaders.lvh.me` host so Rails uses the Study Leader route constraint:

```bash
adb reverse tcp:3000 tcp:3000
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew \
  :app:assembleDebug \
  -PNURIO_BASE_URL=http://studyleaders.lvh.me:3000
```

## Runtime Contract

- Only the exact configured leader origin remains in the Hotwire navigator.
- `/admin` and every other host open in Chrome Custom Tabs.
- The web `sign-in-with-oauth` bridge must provide the provider `startPath`;
  native code rejects non-provider paths and foreign origins before dispatch.
- Kakao uses the native Kakao SDK and exchanges its access token with Rails.
  Google, Naver, and Apple use a secure Custom Tab, matching the learner Study
  Android app, and all successful flows return through the strict callback
  parser.
- For Android production/BVT Apple login, Rails must use the web Services ID
  `APPLE_CLIENT_ID=com.nurio.signin.web.production`. Android opens the Rails
  Apple route in the Custom Tab; this identifier is not embedded in the APK.
- Inject `NURIO_STUDY_LEADER_KAKAO_NATIVE_APP_KEY` from the developer or CI
  environment; never commit it to `gradle.properties`.
- The Material action bar and Hotwire toolbar remain hidden; web navigation owns the visible chrome.

Provider dashboard callbacks and the hidden Play-review login are documented in
[`../docs/OAUTH_AND_REVIEW_LOGIN.md`](../docs/OAUTH_AND_REVIEW_LOGIN.md).
