# OAuth and Store Review Login

Nurio Study Leader uses the same working Hotwire Native login contract as the
learner Study app: the server renders a bridge-enabled provider link, the
native bridge dispatches to a provider-specific native SDK or the explicitly
documented system-auth fallback, Rails verifies the provider credential, and a
signed single-use handoff returns to the app.

The four public web OAuth providers are Google, Kakao, Naver, and Apple. Apple
uses the native sheet on iOS and the documented system-auth path on Android
when configured.

## End-to-End Contract

1. The leader login page renders a provider link with
   `data-controller="bridge--sign-in-with-oauth"` and a `startPath`.
2. In a supported Hotwire Native client, the Stimulus bridge prevents the
   WebView navigation and sends the allowlisted path to Swift or Kotlin.
3. Native code selects the provider flow:
   - iOS Google uses GoogleSignIn SDK.
   - iOS and Android Kakao use Kakao SDK.
   - iOS Apple uses AuthenticationServices.
   - iOS Naver uses `ASWebAuthenticationSession`.
   - Android Google, Naver, and Apple use a Chrome Custom Tab, matching the
     learner Study app until Android Google is migrated to Credential Manager.
4. Native Google and Kakao post their provider token to
   `/auth/google/native` or `/auth/kakao/native`. System-auth providers return
   to the matching HTTPS callback on `studyleaders.nurio.kr`.
5. Rails verifies the token or completes web OAuth and returns a signed,
   five-minute, single-use callback to `nurioleaders://auth-callback`.
6. The native app validates the callback and routes to
   `/auth/native/token_auth`, which establishes the leader-host web session.

The Google reversed-client-ID URL scheme and `nurioleaders://auth-callback`
serve different purposes. GoogleSignIn consumes the reversed-client-ID
callback internally; `nurioleaders` carries only the Rails one-time handoff.
Do not put Google, Kakao, Naver, or Apple server credentials in either native app.

## Provider Dashboard Setup

Configure the exact production HTTPS callbacks. Scheme, host, path, and
trailing slash must match exactly.

| Provider | Production callback | Rails configuration |
| --- | --- | --- |
| Google | `https://studyleaders.nurio.kr/auth/google_oauth2/callback` | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| Kakao | `https://studyleaders.nurio.kr/auth/kakao/callback` | `KAKAO_CLIENT_ID`, `KAKAO_CLIENT_SECRET` |
| Naver | `https://studyleaders.nurio.kr/auth/naver/callback` | `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` |
| Apple | `https://studyleaders.nurio.kr/auth/apple/callback` | `APPLE_LOGIN_ENABLED`, `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` |

### Google

1. Keep the existing Web application OAuth client as Rails
   `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`.
2. Add the exact Study Leader HTTPS callback for browser and Android login.
3. Create a separate iOS OAuth client in the same Google Cloud project:
   - Bundle ID: `com.nurio.studyleaders.ios`
   - `GOOGLE_IOS_CLIENT_ID`: the iOS client ID
   - `GOOGLE_REVERSED_CLIENT_ID`: the reversed iOS client ID URL scheme
   - `GOOGLE_SERVER_CLIENT_ID`: exactly the Web client ID used by Rails
4. Configure the consent screen, verified domains, support email, and test
   users while the application remains in testing mode.

Never substitute the iOS client ID for Rails `GOOGLE_CLIENT_ID`. Rails verifies
the native Google ID token against the Web/server client audience.

### Kakao

1. Enable Kakao Login for the production Kakao application.
2. Add the exact Study Leader callback under the REST API key redirect URIs.
3. Create a dedicated Study Leader Native app key. Do not reuse the main Nurio
   or learner Study native key because co-installed apps must not compete for
   the same Kakao callback scheme.
4. Register:
   - iOS bundle ID `com.nurio.studyleaders.ios`
   - Android package `com.nurio.studyleaders.android`
   - Android debug, upload/release, and Google Play App Signing key hashes
5. Confirm the `account_email` consent item is enabled; Rails rejects a native
   Kakao token that cannot provide an email.
6. Keep Rails `KAKAO_APP_ID` set to the numeric Kakao application audience. It
   is not the Native app key.

### Naver

1. Add the Study Leader service URL and exact callback in Naver Developers.
2. Confirm the requested profile fields match what Rails actually consumes.
3. Move the application from development to the production/service state
   before store submission.
4. Keep the client secret only in Rails credentials or deployment secrets.

### Apple

1. Keep the web Services ID and private-key credentials only in Rails.
2. For Android production/BVT login, set the Rails web client to
   `APPLE_CLIENT_ID=com.nurio.signin.web.production`.
3. Add the exact Study Leader HTTPS callback to that Services ID configuration.
4. Keep the iOS native App ID and its token audience separate from the web
   Services ID; Android uses the web authorization flow in a Custom Tab and
   does not embed or override the web client ID.
5. Confirm the successful Android callback returns through the signed,
   single-use `nurioleaders://auth-callback` handoff.

## Native Build Configuration

### iOS

Copy `ios/Config/NativeAuth.local.xcconfig.example` to the ignored
`ios/Config/NativeAuth.local.xcconfig`, or inject an equivalent protected
xcconfig in CI:

```text
KAKAO_NATIVE_APP_KEY = <dedicated Study Leader Native app key>
GOOGLE_IOS_CLIENT_ID = <Study Leader iOS OAuth client ID>
GOOGLE_SERVER_CLIENT_ID = <existing Web OAuth client ID>
GOOGLE_REVERSED_CLIENT_ID = <reversed Study Leader iOS client ID>
```

The project fails closed at runtime when provider configuration is missing.
Do not put provider values on a verbose `xcodebuild` command line or include the
local xcconfig in Copy Bundle Resources.

### Android

Provide the dedicated Kakao Native app key from the developer or CI environment:

```bash
export NURIO_STUDY_LEADER_KAKAO_NATIVE_APP_KEY='<native-app-key>'
cd leaders-nurio-mobile/android
./gradlew :app:testDebugUnitTest :app:assembleDebug :app:lintDebug
```

The build reads the same name as a Gradle property if needed. Do not commit the
value to `gradle.properties`. When it is absent, Kakao initialization and its
exported callback activity are disabled rather than falling back silently to
web Kakao.

## Store Review Login

App Store and Play reviewers do not need to complete provider 2FA. A separate,
credential-gated login signs in only one fictional approved Study Leader.

Configure either Rails credentials:

```yaml
study_leader_review_login:
  email: <store-review-email>
  password: <long-random-password>
```

or deployment secrets:

```text
STUDY_LEADER_REVIEW_LOGIN_EMAIL
STUDY_LEADER_REVIEW_LOGIN_PASSWORD
```

Then provision the account from the Rails repository:

```bash
mise exec -- bin/rails db:seed:leader_review_demo
```

This is a database mutation. Confirm the target database and schema before
running it. The provisioning task creates the verified, onboarded
`session_leader` identity only. Populate Today, Schedule, Notifications,
Sessions, and Earnings with fictional, non-sensitive sample records through
the normal admin/operations tools.

Reviewer instructions:

1. Open the Study Leader login screen.
2. Tap the Nurio Study Leader brand once.
3. Enter the review email and password supplied in the store console.
4. The app opens the populated leader Today workspace.

Security properties:

- The form is absent from the initial HTML and lazy-loads only after the
  gesture.
- The endpoint returns 404 when either review secret is missing.
- The endpoint can authenticate only the configured account and only when that
  account has the `session_leader` role.
- Responses are `noindex`, `nofollow`, `noarchive`, and `no-store`.
- POST attempts are rate-limited per IP.
- Credentials never belong in Git, screenshots, metadata, or review notes
  stored in a public repository.

Keep the credentials active throughout review and any appeal window. Rotate
them after a review cycle or immediately if they are exposed.

## Release Test Matrix

- Each provider link contains `platform=native` in an iOS and Android build.
- iOS Google opens GoogleSignIn, returns through the reversed client-ID scheme,
  posts the ID token to Rails, and establishes the Hotwire session.
- iOS and Android Kakao open KakaoTalk when available, exchange the access
  token with Rails, and establish the Hotwire session.
- Android Google, Naver, and Apple complete through the documented system-auth
  session.
- Cancellation returns safely without creating a partial session.
- A callback with a wrong scheme, host, duplicated token/state, path, port, or
  fragment is rejected.
- Replaying an already consumed callback fails.
- The single-tap review login works in TestFlight and an internal Play build.
- A non-leader account cannot use the review endpoint.
- Removing either review secret changes `/review_login` to 404.

## Official References

- [Hotwire Native Bridge Components](https://native.hotwired.dev/reference/bridge-components)
- [Apple ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [Android authentication with Custom Tabs](https://developer.android.com/work/guide#custom-tabs)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Google OAuth for web server applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Kakao iOS SDK setup](https://developers.kakao.com/docs/en/ios/getting-started)
- [Kakao Login for Android](https://developers.kakao.com/docs/en/kakaologin/android)
- [Naver Login](https://developers.naver.com/products/login/api)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
