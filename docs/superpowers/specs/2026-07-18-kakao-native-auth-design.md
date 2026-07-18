# Kakao Native Authentication Design

## Goal

Provide the same reliable Kakao login support in the main Nurio and Nurio Study Hotwire Native apps on iOS and Android while leaving browser Kakao OAuth unchanged.

This is the first slice of the broader social-login repair. Google and Apple native authentication will follow in separate implementation plans.

## Scope

This slice covers:

- main Nurio iOS;
- main Nurio Android;
- Nurio Study iOS;
- Nurio Study Android;
- the shared Rails `/auth/kakao/native` exchange and `/auth/native/token_auth` session handoff;
- build-time, file-based Kakao native-key configuration for all four clients.

This slice does not cover Flutter, Naver, Google, Apple, admin, or tutoring clients and routes.

## Credential Model

Main Nurio and Nurio Study use separate Kakao Native app keys created under the same Kakao Developers app. Because both keys belong to the same Kakao app:

- the existing browser REST API key and `/auth/kakao` OmniAuth flow remain unchanged;
- Rails continues to validate native access tokens against the single numeric `KAKAO_APP_ID`;
- the main key is registered to the main iOS bundle and Android package/signing key hashes;
- the Study key is registered to the Study iOS bundle and Android package/signing key hashes.

The native keys are embedded in app artifacts and are not server secrets, but the application must never print them or provider tokens in logs.

## Configuration Files

Each app owns local configuration so main and Study values cannot be confused.

### iOS

Create these tracked files for each target:

- `ios/Config/NativeAuth.xcconfig`
- `ios/Config/NativeAuth.local.xcconfig.example`
- `study-nurio-mobile/ios/Config/NativeAuth.xcconfig`
- `study-nurio-mobile/ios/Config/NativeAuth.local.xcconfig.example`

Each tracked `NativeAuth.xcconfig` defines an empty default and optionally includes the ignored local file:

```xcconfig
KAKAO_NATIVE_APP_KEY =
#include? "NativeAuth.local.xcconfig"
```

The example files document this local setting:

```xcconfig
KAKAO_NATIVE_APP_KEY = replace-with-native-app-key
```

Ignore both apps' `NativeAuth.local.xcconfig` files. Wire the tracked config into Debug and Release. `Info.plist` reads `$(KAKAO_NATIVE_APP_KEY)` for SDK initialization and the `kakao$(KAKAO_NATIVE_APP_KEY)` callback scheme. Command-line Xcode build-setting overrides remain available to CI.

The newly generated Study key goes in:

```text
study-nurio-mobile/ios/Config/NativeAuth.local.xcconfig
```

### Android

Create these tracked templates:

- `android/auth.properties.example`
- `study-nurio-mobile/android/auth.properties.example`

Ignore the corresponding `auth.properties` files. Each local file uses the same app-local property name:

```properties
KAKAO_NATIVE_APP_KEY=replace-with-native-app-key
```

Gradle resolves configuration in this order:

1. app-specific Gradle property;
2. app-specific CI environment variable;
3. the app's local `auth.properties`;
4. an empty value that disables native Kakao explicitly.

CI override names remain distinct:

- main: `NURIO_KAKAO_NATIVE_APP_KEY`;
- Study: `NURIO_STUDY_KAKAO_NATIVE_APP_KEY`.

The newly generated Study key also goes in:

```text
study-nurio-mobile/android/auth.properties
```

## Runtime Architecture

### Browser

Normal browsers continue to navigate through `/auth/kakao` and the existing Kakao REST OAuth callback. No browser credential, route, session, or provider-button behavior changes in this slice.

### Native clients

Both apps follow the same sequence:

1. Resolve `/auth/kakao` only when it is the expected same-origin provider route.
2. Dispatch Kakao to the native Kakao SDK from both Hotwire route decisions and bridge messages.
3. Prefer KakaoTalk login when available; otherwise use Kakao Account through the SDK-supported path.
4. Send the resulting access token over HTTPS to `/auth/kakao/native`.
5. Rails validates the token with Kakao, verifies its numeric app ID, fetches the Kakao user, and provisions or resolves the account.
6. Rails returns a five-minute, one-time `{token, state}` handoff.
7. The app validates and converts the callback to the same-origin `/auth/native/token_auth` URL.
8. The Hotwire WebView navigates to that URL, establishes the Rails session, sets persistent login state, and redirects to the correct main or Study destination.

Kakao cancellation is silent. Configuration, SDK, transport, exchange, and callback-validation failures show one recoverable sign-in error and never fall back to Kakao web OAuth inside the native app.

## Main Nurio Changes

### iOS

Replace the duplicated provider branching in the route handler and bridge component with the provider-route/coordinator pattern already proven in Study. Both entry paths must route Kakao to `NativeKakaoSignInCoordinator`; neither may reach `OAuthSessionCoordinator`.

Harden the existing native coordinator and handoff client to provide:

- explicit configured, cancelled, provider-failed, and handoff-failed results;
- exactly one active flow and completion;
- an ephemeral HTTPS session that rejects redirects;
- no response-body, key, access-token, handoff-token, or state logging;
- strict custom callback validation before WebView navigation.

### Android

Port the tested Study native Kakao architecture into the main app:

- Kakao SDK repository and user dependency;
- SDK initialization from `BuildConfig.KAKAO_NATIVE_APP_KEY`;
- manifest callback activity and scheme placeholders;
- same-origin `SocialAuthRoute` validation;
- `SocialAuthCoordinator` dispatch;
- lifecycle-safe `NativeKakaoSignInCoordinator`;
- bounded HTTPS `NativeAuthHandoffClient`;
- cold- and warm-start callback routing;
- unit tests for routing, cancellation, fallback, handoff, and lifecycle behavior.

## Nurio Study Changes

Study already has native Kakao coordinators on iOS and Android. Preserve those flows and migrate key configuration out of direct project/build settings into the files defined above.

Apply callback and logging hardening consistently so Study and main enforce the same contract. The current distinct Study key must remain distinct from the main key.

## Rails Changes

Keep the existing routes and one-app audience model:

- `/auth/kakao` for browser OAuth;
- `POST /auth/kakao/native` for native SDK token exchange;
- `/auth/native/token_auth` for one-time Rails session establishment.

Retain the numeric `KAKAO_APP_ID` audience check. Do not add a Study-specific Kakao app ID because both native keys belong to the same Kakao Developers app.

Harden structural diagnostics so failed Kakao API responses log only the stage, HTTP status, request ID, and hashed token identifier. Do not log raw provider bodies, access tokens, email, Kakao user IDs, or handoff credentials.

## Backward Compatibility

The native exchange and handoff URLs remain unchanged, so already-installed main and Study builds continue to work while new builds adopt file-based configuration and unified routing.

Browser OAuth remains available outside native shells. Native clients with missing Kakao configuration fail explicitly and do not silently switch to the browser flow.

## Testing

### Rails

- existing Kakao service, request, and native-session handoff specs;
- same-app audience acceptance and wrong-app rejection;
- missing email and unavailable Kakao API failures;
- structural logging that excludes raw response bodies and credentials;
- persistent login after handoff.

### iOS, both apps

- provider route accepts only same-origin `/auth/kakao`;
- route handler and bridge both dispatch Kakao natively;
- KakaoTalk availability chooses the correct SDK method;
- cancellation completes once without an alert;
- provider and handoff failures complete once with a recoverable error;
- callback parsing rejects malformed, duplicate, credential-bearing, port-bearing, path-bearing, and fragmented URLs;
- configuration normalization disables empty values;
- simulator builds for both Xcode projects.

### Android, both apps

- provider route and coordinator tests;
- KakaoTalk-to-account fallback and cancellation tests;
- handoff request, timeout, redirect rejection, and payload-validation tests;
- lifecycle invalidation and duplicate-start tests;
- manifest/build-config checks;
- `testDebugUnitTest`, `assembleDebug`, and `lintDebug` for both apps.

### Release verification

- configuration validation reports present, missing, consistent, and main-versus-Study-distinct status without printing values;
- Kakao console has the correct bundle/package and Android debug, release, and Play signing key hashes under each native key;
- real-device login, cancellation, relaunch persistence, and returning-user checks for main and Study on iOS and Android;
- browser Kakao login regression on main and Study domains.

## Rollout Order

1. Add configuration files and validation without changing browser behavior.
2. Harden the shared Rails native exchange diagnostics.
3. Unify and test main iOS Kakao routing.
4. Add and test main Android native Kakao.
5. Migrate and reverify Study configuration and parity.
6. Complete real-device and release-signing verification.
7. Begin the separate Google native-auth design and implementation slice.
