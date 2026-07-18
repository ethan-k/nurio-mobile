# Nurio Study social login

This runbook covers social login for the customer-facing Hotwire Native iOS and Android apps at `https://study.nurio.kr`. It does not apply to the main Nurio app, Flutter, admin, or tutor surfaces.

## Runtime design

| Provider | Native behavior | Rails entry/callback |
| --- | --- | --- |
| Kakao | Kakao SDK opens KakaoTalk when available. Both apps use Kakao Account when KakaoTalk is unavailable; Android also falls back after a non-cancellation KakaoTalk failure, while iOS reports that provider failure so the user can retry. | The app exchanges the Kakao access token at `POST /auth/kakao/native`. |
| Google | iOS uses GoogleSignIn SDK and exchanges the Google ID token with Rails. Android currently keeps the system authentication session. Browser Google login is unchanged. | iOS posts to `POST /auth/google/native`; Android/browser keep `/auth/google_oauth2` and its HTTPS callback. |
| Naver | A system authentication session opens the Rails OmniAuth flow. | `/auth/naver` returns through `https://study.nurio.kr/auth/naver/callback`. |

Do not enable or embed Kakao web **Simple Login** inside the native authentication sheet. The Study Kakao button is owned by the native bridge and must use the Kakao SDK. On iOS, the Study Google button is also owned by the native bridge and must use GoogleSignIn SDK; Naver still uses `ASWebAuthenticationSession`. Android Google and Naver currently use Custom Tabs.

After a native provider succeeds, Rails issues a short-lived, one-time token and state. Study creates an in-memory `nuriostudy://auth-callback`, converts it to an HTTPS request to `/auth/native/token_auth`, and lets the Rails session cookie persist in the Hotwire web view. The Google SDK's own reversed-client-ID callback is handled directly by the SDK; it is not the Rails handoff callback. The main Nurio app keeps its separate `nurio://auth-callback` handoff.

## Kakao console configuration

The Rails audience remains the existing Kakao application ID:

```text
KAKAO_APP_ID=1352984
```

`KAKAO_APP_ID` is the numeric audience checked against Kakao's access-token information. It is not the Kakao Native app key. The Rails web flow also retains its existing `KAKAO_CLIENT_ID` and `KAKAO_CLIENT_SECRET` credentials.

Create or select an **additional Kakao Native app key** dedicated to Nurio Study under the existing Kakao application whose ID is `1352984`. Do not reuse the main Nurio app's Native app key: co-installed apps must not register the same `kakao<NativeAppKey>://oauth` callback scheme. Treat the Study key as a user-managed secret and never commit it, paste it into documentation, or print it in build logs.

In Kakao Developers, verify all of the following under the Kakao application whose numeric app ID is `1352984`:

- Register the iOS platform with bundle ID `com.nurio.study.ios`.
- Register the Android platform with package name `com.nurio.study.android` and every signing-certificate key hash that can sign an installed build: debug, upload/release, and Google Play App Signing.
- Enable the Kakao Login consent item `account_email`. Rails rejects native Kakao login when the granted profile has no email.
- Keep the Study Native app key distinct from both the main Nurio Native app key and the REST API key used by server-side/web OAuth configuration.

Generate the Android debug key hash locally:

```bash
keytool -exportcert \
  -alias androiddebugkey \
  -keystore "$HOME/.android/debug.keystore" \
  -storepass android \
  | openssl sha1 -binary \
  | openssl base64
```

Generate the upload/release hash from the actual upload keystore. Let `keytool` prompt for the password; do not put the password on the command line or in the repository:

```bash
keytool -exportcert \
  -alias "$NURIO_STUDY_RELEASE_KEY_ALIAS" \
  -keystore "$NURIO_STUDY_RELEASE_KEYSTORE" \
  | openssl sha1 -binary \
  | openssl base64
```

Google Play re-signs distributed builds with the Play App Signing certificate, so the upload-keystore hash is not sufficient for production. In Play Console, open **App integrity**, copy the SHA-1 fingerprint under **App signing key certificate** (not the upload certificate), convert that hexadecimal SHA-1 digest to Kakao's Base64 key-hash format, and register the result for `com.nurio.study.android`:

```bash
nurio_play_app_signing_sha1='<SHA-1 from the Play App Signing key certificate>'
printf '%s' "$nurio_play_app_signing_sha1" \
  | tr -d ':' \
  | xxd -r -p \
  | openssl base64
unset nurio_play_app_signing_sha1
```

Register the debug, upload/release, and Play App Signing hashes that apply to distributed builds in Kakao Developers without committing them to this repository.

## Injecting the Native app key

Keep the source secret in the user or CI secret store as `NURIO_STUDY_KAKAO_NATIVE_APP_KEY`. Do not use shell tracing (`set -x`), `echo`, command-line values, or build-setting dumps while handling it.

### iOS

Create a protected `.xcconfig` outside the repository with the provider settings below. For local development, restrict the file to the current user; in CI, use the platform's protected secret-file mount. Set `NURIO_STUDY_XCCONFIG_PATH` to that file's path, not to any individual value.

```text
KAKAO_NATIVE_APP_KEY = <Study Native app key>
GOOGLE_IOS_CLIENT_ID = <iOS OAuth client ID>
GOOGLE_SERVER_CLIENT_ID = <existing Web OAuth client ID>
GOOGLE_REVERSED_CLIENT_ID = <reversed iOS OAuth client ID>
```

Pass only the protected file path to Xcode. Do not put `KAKAO_NATIVE_APP_KEY=<value>` on the `xcodebuild` command line because Xcode can print command-line build settings:

```bash
test -f "$NURIO_STUDY_XCCONFIG_PATH"

xcodebuild \
  -project study-nurio-mobile/ios/NurioStudy.xcodeproj \
  -scheme NurioStudy \
  -destination 'generic/platform=iOS Simulator' \
  -xcconfig "$NURIO_STUDY_XCCONFIG_PATH" \
  build
```

Use the same protected `.xcconfig` path in the signed archive job. Never add the local config to the Copy Bundle Resources phase, place it in an artifact, or print its values in logs. The committed Debug and Release defaults are intentionally empty; with missing Google settings, native Google login fails closed as unconfigured instead of falling back to the fragile web callback.

### Android

The Android build accepts `NURIO_STUDY_KAKAO_NATIVE_APP_KEY` as either a Gradle property or an environment variable. Prefer the CI/user environment so the key is not written to a tracked file:

```bash
test -n "$NURIO_STUDY_KAKAO_NATIVE_APP_KEY"

cd study-nurio-mobile/android
./gradlew :app:assembleDebug
```

If a local Gradle property is required, place it only in an ignored user-level Gradle properties file and never commit it. With no value, `BuildConfig.KAKAO_NATIVE_APP_KEY` remains empty and the exported Kakao callback activity is disabled with a non-secret placeholder scheme.

## Google and Naver consoles

The existing Google Web OAuth client remains the server audience and browser credential. Keep these production callbacks registered for browser, Android system-session, and Naver login:

```text
Google: https://study.nurio.kr/auth/google_oauth2/callback
Naver:  https://study.nurio.kr/auth/naver/callback
```

For native iOS Google login, create an additional **iOS OAuth client** in the same Google Cloud project:

- Bundle ID: `com.nurio.study.ios`
- `GOOGLE_IOS_CLIENT_ID`: that iOS client's `*.apps.googleusercontent.com` client ID
- `GOOGLE_REVERSED_CLIENT_ID`: the iOS client ID with its segments reversed, as provided by Google's iOS configuration
- `GOOGLE_SERVER_CLIENT_ID`: the existing Web OAuth client ID, exactly matching Rails `GOOGLE_CLIENT_ID`

Do not substitute the iOS client ID for Rails `GOOGLE_CLIENT_ID`. Rails verifies the native ID token against the Web OAuth client audience, while the iOS client ID and reversed client ID identify the installed app to GoogleSignIn SDK.

On the Rails deployment side, keep the provider names in both `config/deploy.yml` and `config/deploy.quiz.yml`, and keep their environment mappings in `.kamal/secrets`:

- `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`
- `KAKAO_CLIENT_ID`, `KAKAO_CLIENT_SECRET`, and `KAKAO_APP_ID`
- `NAVER_CLIENT_ID` and `NAVER_CLIENT_SECRET`

Never put the Study Native app key in Rails logs or substitute it for `KAKAO_APP_ID`.

## Safe verification

These checks validate configuration shape while `-o` prints only the matched configuration names, not their full source lines or values:

```bash
# Mobile source configuration
rg -n -o 'nuriostudy|KAKAO_NATIVE_APP_KEY|GOOGLE_(IOS|SERVER|REVERSED)_CLIENT_ID|com\.nurio\.study\.(ios|android)' \
  study-nurio-mobile/ios \
  study-nurio-mobile/android/app \
  --glob '!**/build/**'

# Rails provider and deployment variable names (run from the Rails repository)
rg -n -o 'GOOGLE_CLIENT_(ID|SECRET)|KAKAO_(CLIENT_ID|CLIENT_SECRET|APP_ID)|NAVER_CLIENT_(ID|SECRET)' \
  config/deploy.yml config/deploy.quiz.yml .kamal/secrets

# Android unit tests, build, and lint
cd study-nurio-mobile/android
./gradlew testDebugUnitTest assembleDebug lintDebug
```

For iOS, use a simulator test destination installed on the development machine:

```bash
xcodebuild \
  -project study-nurio-mobile/ios/NurioStudy.xcodeproj \
  -scheme NurioStudy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' \
  test
```

Do not verify a configured key with `xcodebuild -showBuildSettings`, merged-manifest dumps, or commands that print URL schemes: those outputs can expose the Native app key.

## Real-device acceptance checklist

Use a non-production test account where possible. Exercise the signed iOS and Android builds against `https://study.nurio.kr`:

- [ ] KakaoTalk installed: the Kakao button opens KakaoTalk, returns to Study, and signs in.
- [ ] KakaoTalk absent: Kakao Account fallback completes and signs in.
- [ ] Kakao cancellation: cancellation returns safely, creates no session, and a later attempt still works.
- [ ] iOS Google opens the native GoogleSignIn SDK flow, returns to Study, and creates the WebView Rails session.
- [ ] Android Google completes through the system authentication session and returns to Study.
- [ ] Naver completes through the system authentication session and returns to Study.
- [ ] Relaunch after each successful provider login preserves the Rails session.
- [ ] Main Nurio and Nurio Study installed together: Study callbacks return only to Study and main-app callbacks still return only to main Nurio.
- [ ] No provider flow opens an embedded Kakao web Simple Login page.

## Troubleshooting

- **Kakao reports an audience mismatch:** the Native app key produced a token for a Kakao application whose numeric app ID does not match Rails `KAKAO_APP_ID=1352984`. Correct the Kakao application/platform/key selection. Do not change the Rails audience just to silence the error.
- **Kakao reports that email consent is required:** enable `account_email` in Kakao Developers and confirm the test account granted it. A user may need to disconnect/re-authorize after a consent configuration change.
- **KakaoTalk does not return to iOS:** confirm bundle ID `com.nurio.study.ios`, the injected Native app key, and the generated `kakao<NativeAppKey>://oauth` registration without printing the key in logs.
- **KakaoTalk does not return to Android:** confirm package `com.nurio.study.android`, the correct build-variant key hash, and that the signed build received the Native app key.
- **iOS Google reports that sign-in is not configured:** confirm all three Google build settings are present in the protected `.xcconfig`, and that `GOOGLE_SERVER_CLIENT_ID` exactly matches Rails `GOOGLE_CLIENT_ID`.
- **iOS Google returns an audience error from Rails:** the SDK was configured with the wrong server client ID. Use the existing Web OAuth client ID as `GOOGLE_SERVER_CLIENT_ID`; keep the iOS client ID only in `GOOGLE_IOS_CLIENT_ID` and the reversed URL scheme.
- **Google or Naver reports a redirect mismatch:** compare the provider console value character-for-character with the HTTPS callback above, including `study.nurio.kr`, provider name, and `/callback`.
- **The wrong Nurio app opens:** Study must use `nuriostudy://auth-callback`; `nurio://auth-callback` belongs to the main app. Recheck the signed app's callback registration with both apps installed.
- **Login succeeds but relaunch is signed out:** confirm the callback reached `/auth/native/token_auth` inside the Study Hotwire session and that cookies were not cleared. Do not log the handoff token, state, provider access token, cookies, or full callback URL while diagnosing.
