# Nurio Study Leader Android

Hotwire Native Android shell for `https://studyleaders.nurio.kr`.

## Identity

- Package: `com.nurio.studyleader.android`
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

## Runtime Contract

- Only the exact configured leader origin remains in the Hotwire navigator.
- `/admin` and every other host open in Chrome Custom Tabs.
- OAuth provider URLs open in a secure browser session and return through the strict callback parser.
- The web `sign-in-with-oauth` bridge must provide the provider `startPath`; native code rejects non-provider paths and foreign origins before opening the Custom Tab.
- The Material action bar and Hotwire toolbar remain hidden; web navigation owns the visible chrome.

Provider dashboard callbacks and the hidden Play-review login are documented in
[`../docs/OAUTH_AND_REVIEW_LOGIN.md`](../docs/OAUTH_AND_REVIEW_LOGIN.md).
