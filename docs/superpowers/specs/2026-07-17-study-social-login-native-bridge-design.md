# Nurio Study Native Social Login Bridge Design

## Goal

Make KakaoTalk, Google, and Naver sign-in reliable in the dedicated Nurio Study Hotwire Native apps while keeping the authenticated web session on `https://study.nurio.kr`.

The implementation targets:

- iOS bundle `com.nurio.study.ios` under `study-nurio-mobile/ios/`
- Android package `com.nurio.study.android` under `study-nurio-mobile/android/`
- the customer-facing Rails authentication surfaces in `/Users/ws/es/business/nurioworkspace/nurio`

Flutter, admin, tutor, and the main Nurio mobile clients are outside this change. Existing browser OAuth behavior must remain unchanged.

## Current State

The Rails app already provides the secure Kakao native adapter:

1. `POST /auth/kakao/native` accepts a Kakao access token.
2. `Kakao::NativeSignInService` validates the token and its Kakao App ID audience, retrieves the user, and provisions or resolves the shared Nurio account.
3. `NativeSignIn::Handoff` issues a five-minute signed token and one-time state.
4. `/auth/native/token_auth` consumes the handoff and establishes a remembered Rails session.

The main Nurio iOS client already uses KakaoSDK and this backend exchange. The Study iOS and Android clients do not. Both Study clients currently send Kakao, Google, and Naver through an external system authentication session. That flow is acceptable for Google and Naver, but KakaoTalk app switching must use KakaoSDK.

The Study clients also share the `nurio://auth-callback` scheme with the main Nurio apps. Two installed apps claiming the same scheme can receive the wrong callback, so the Study flow needs its own callback scheme.

## Approaches Considered

### 1. Hybrid provider bridge using the existing Rails handoff (selected)

- Kakao uses the provider SDK on both Study clients.
- Google and Naver continue through `ASWebAuthenticationSession` on iOS and Custom Tabs on Android.
- Every provider finishes through a Study-specific custom callback and `/auth/native/token_auth` on `study.nurio.kr`.

This reuses the working security model, fixes the provider-specific Kakao failure, and keeps the change narrow.

### 2. Provider SDKs for Kakao, Google, and Naver

This would provide SDK-native UI for every provider, but it would add two new backend token-verification adapters, more console registrations, and more client dependencies without solving a current Google or Naver failure. It is not required for this release.

### 3. External browser authentication for all providers

This is the current Study implementation. It has the smallest code footprint but is not acceptable for Kakao because the KakaoTalk round trip can invalidate the web login session.

## Architecture

### Shared provider routing

Each Study client will have one provider router used by both Hotwire entry points:

- the `sign-in-with-oauth` bridge component, for explicit bridge-enabled Rails links;
- the OAuth route decision handler, as a fallback for ordinary links to supported OAuth paths.

The router accepts only HTTP or HTTPS URLs whose host equals `study.nurio.kr` (or the configured `NURIO_BASE_URL` host in a debug build) and whose path is one of:

- `/auth/kakao`
- `/auth/google_oauth2`
- `/auth/naver`

Kakao is dispatched to the native Kakao coordinator. Google and Naver are dispatched to the existing system authentication coordinator. Unsupported providers, hosts, and paths are rejected instead of opening an arbitrary URL.

The Study welcome screen will mark its three social-login links with the existing `bridge--sign-in-with-oauth` Stimulus controller. The route decision handler remains necessary because login links can also be rendered by shared customer-facing Rails views.

### Kakao token exchange

Both native coordinators follow the same flow:

1. Start KakaoTalk login when the KakaoTalk app is available.
2. Fall back to Kakao Account login through the Kakao SDK when it is not.
3. Receive the SDK access token.
4. POST `{ "access_token": "..." }` to `https://study.nurio.kr/auth/kakao/native`.
5. Receive `{ "token": "...", "state": "..." }` from the existing Rails adapter.
6. Build `nuriostudy://auth-callback?token=...&state=...`.
7. Route the callback to `https://study.nurio.kr/auth/native/token_auth` inside the Study Hotwire navigator.

The clients never trust Kakao profile data directly. Rails remains responsible for token audience validation, email requirements, identity linking, account creation, and handoff issuance.

### iOS components

The Study iOS target will add the same pinned KakaoSDK products used by the main Nurio iOS target: `KakaoSDKCommon`, `KakaoSDKAuth`, and `KakaoSDKUser`.

The implementation will add:

- `NativeKakaoSignInCoordinator.swift`, adapted from the main client and pointed at the Study base URL;
- KakaoSDK initialization in `AppDelegate`;
- Kakao callback handling in `SceneController` for cold and warm launches;
- a Study Kakao native app key and matching `kakao<KEY>` URL scheme in `Info.plist`;
- `kakaokompassauth` and `kakaolink` query schemes;
- the unique `nuriostudy` authentication callback scheme.

The coordinator will use a small provider-agnostic handoff HTTP client so encoding, response parsing, host selection, and error mapping can be unit-tested without invoking KakaoSDK.

### Android components

The Study Android target will add Kakao's Android user SDK and initialize it from `StudyApplication`. Its native Kakao coordinator will:

- choose KakaoTalk or Kakao Account login;
- send the access token to the existing Rails endpoint;
- parse the handoff response;
- deliver the Study callback to `MainActivity`.

The Android manifest will register Kakao's SDK callback activity and `kakao<KEY>://oauth`, plus the unique `nuriostudy://auth-callback` intent filter. The native app key will come from a Gradle property/build configuration value rather than being logged or copied into error messages.

Pure Kotlin URL policy, handoff response parsing, and callback construction will be separated from Android UI classes so they can be covered by local unit tests.

### Rails host and callback behavior

Rails must explicitly recognize these user-agent prefixes as native clients:

- `Nurio Study iOS`
- `Nurio Study Android`

This ensures `native_oauth_request_path` adds `platform=native` for Google and Naver.

For native OAuth started on `study.nurio.kr`, Rodauth will return to `nuriostudy://auth-callback`. Existing native OAuth on the main Nurio host will continue to use `nurio://auth-callback`. Browser OAuth will continue to use its ordinary HTTP redirect.

After `/auth/native/token_auth` establishes the session, completed Study accounts will use `AuthRedirectPathResolver` with the request host so the destination is `/` on `study.nurio.kr`, not `/home`. Existing onboarding behavior for incomplete accounts remains unchanged.

## Security Boundaries

- Do not remove or weaken the Kakao `app_id` audience check.
- Do not accept a Kakao user ID or email supplied by the native client.
- Do not place provider client secrets in either mobile app.
- Do not log access tokens, signed handoff tokens, or full callback URLs.
- Accept native OAuth start URLs only from the configured Study host and provider-path allowlist.
- Require both the signed handoff token and its one-time state; keep the five-minute expiry and replay protection.
- Keep browser OAuth separate from native Kakao login.
- Preserve main Nurio app callback behavior and all admin/tutor scope restrictions.

## External Provider Configuration

Kakao configuration stays under the existing Nurio Kakao application, App ID `1352984`, so the Rails audience check remains valid. A separate Study native platform key is required to avoid URL-scheme collisions with the main app. Register:

- iOS bundle ID `com.nurio.study.ios`;
- Android package `com.nurio.study.android` and its debug/release signing key hashes;
- required account email consent;
- the Study iOS and Android callback schemes generated from the Study native key.

The implementation will compile without a production key and report an explicit configuration error at runtime. A real-device login test requires the Study native key and console registrations.

Google and Naver continue using the existing Rails OAuth applications and secrets. Their web callback registrations must allow the production Study host. No provider client secret is added to a mobile target.

## Error Handling

User cancellation is treated as cancellation and does not display a failure alert.

Configuration errors, provider errors, network failures, malformed backend responses, and rejected handoffs produce a short provider-specific alert with a retry action. Raw provider payloads and tokens are never shown. Native logs include only the provider, phase, HTTP status, and sanitized error category.

If the Kakao key is absent, the Kakao button remains visible but tapping it shows an explicit unavailable/configuration message. The app must not fall back to Kakao web OAuth.

Google and Naver retain their existing system-auth cancellation and error behavior. Their callbacks are accepted only through the Study callback scheme and routed to the Study base URL.

## Testing and Verification

### Rails

- Request/helper specs prove both Study user agents receive `platform=native`.
- Rodauth/request specs prove native Study Google and Naver login redirects use `nuriostudy://auth-callback` while main-app native redirects still use `nurio://auth-callback`.
- Native-auth request specs prove a completed account on the Study host redirects to the Study root.
- Existing Kakao service and request specs remain green, including audience mismatch, missing email, expiry, and replay coverage.

### iOS

- Unit tests cover provider routing, rejected foreign hosts, callback construction, missing token/state, and handoff response parsing.
- Existing Study scope-policy tests remain green.
- Build and test the `NurioStudy` scheme for a generic iOS Simulator with code signing disabled.
- On a real registered device, verify KakaoTalk app switch and Kakao Account fallback.

### Android

- Local unit tests cover provider routing, rejected foreign hosts, callback construction, and handoff response parsing.
- Build the Study debug APK and run unit tests.
- On a registered emulator/device, verify Kakao Account fallback and KakaoTalk app switch.

### End-to-end acceptance

For each provider on both platforms:

1. Start from the Study welcome screen.
2. Complete or cancel authentication.
3. Confirm successful authentication returns to the Study app, not the main Nurio app or a browser.
4. Confirm the Rails session survives app relaunch.
5. Confirm the final host is `study.nurio.kr`.
6. Confirm admin and tutor routes remain blocked.

## Rollout

Deploy the Rails compatibility changes before distributing mobile builds so the Study callback scheme and user agents are recognized. Then release internal iOS and Android builds configured with the registered Study Kakao native key. Validate all three providers in internal testing before store submission.

If a mobile release must be rolled back, the existing browser OAuth flows remain available on the website. The apps must not silently re-enable Kakao web OAuth as a mobile fallback.
