# OAuth and Store Review Login

Nurio Study Leader uses the same working Hotwire Native login contract as the
learner Study app: the server renders a bridge-enabled provider link, the
native bridge opens a secure system authentication session, Rails finishes the
provider callback, and a signed single-use handoff returns to the app.

The three public web OAuth providers are Google, Kakao, and Naver. Apple login
remains available on iOS when configured because App Review Guideline 4.8 may
require it when third-party social login is offered.

## End-to-End Contract

1. The leader login page renders a provider link with
   `data-controller="bridge--sign-in-with-oauth"` and a `startPath`.
2. In a supported Hotwire Native client, the Stimulus bridge prevents the
   WebView navigation and sends the allowlisted path to Swift or Kotlin.
3. iOS opens `ASWebAuthenticationSession`; Android opens a browser Custom Tab.
   Provider credentials are never entered into or inspected by the WebView.
4. The provider returns to the matching HTTPS callback on
   `studyleaders.nurio.kr`.
5. Rails completes OAuth and returns a signed, five-minute, single-use callback
   to `nurioleaders://auth-callback`.
6. The native app validates the callback and routes to
   `/auth/native/token_auth`, which establishes the leader-host web session.

Do not put provider client secrets in either native app. The native apps need
only the base URL, allowlisted provider paths, and callback scheme.

## Provider Dashboard Setup

Configure the exact production HTTPS callbacks. Scheme, host, path, and
trailing slash must match exactly.

| Provider | Production callback | Rails configuration |
| --- | --- | --- |
| Google | `https://studyleaders.nurio.kr/auth/google_oauth2/callback` | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| Kakao | `https://studyleaders.nurio.kr/auth/kakao/callback` | `KAKAO_CLIENT_ID`, `KAKAO_CLIENT_SECRET` |
| Naver | `https://studyleaders.nurio.kr/auth/naver/callback` | `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` |

### Google

1. Use a Web application OAuth client in Google Cloud.
2. Add the exact Study Leader callback to Authorized redirect URIs.
3. Configure the consent screen, verified domains, support email, and required
   test users while the app remains in testing mode.
4. Keep the client secret only in Rails credentials or the deployment secret
   environment.

### Kakao

1. Enable Kakao Login for the production Kakao application.
2. Add the exact Study Leader callback under the REST API key redirect URIs.
3. Confirm required consent items and business verification before production.
4. The current Study Leader release uses browser OAuth, so it does not require
   the Kakao native SDK app key in the binary.

### Naver

1. Add the Study Leader service URL and exact callback in Naver Developers.
2. Confirm the requested profile fields match what Rails actually consumes.
3. Move the application from development to the production/service state
   before store submission.
4. Keep the client secret only in Rails credentials or deployment secrets.

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
2. Tap the Nurio Study Leader brand five times within four seconds.
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
- Google, Kakao, and Naver complete from a signed-out cold launch.
- Cancellation returns safely without creating a partial session.
- A callback with a wrong scheme, host, duplicated token/state, path, port, or
  fragment is rejected.
- Replaying an already consumed callback fails.
- The five-tap review login works in TestFlight and an internal Play build.
- A non-leader account cannot use the review endpoint.
- Removing either review secret changes `/review_login` to 404.

## Official References

- [Hotwire Native Bridge Components](https://native.hotwired.dev/reference/bridge-components)
- [Apple ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [Android authentication with Custom Tabs](https://developer.android.com/work/guide#custom-tabs)
- [Google OAuth for web server applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Kakao Login prerequisites](https://developers.kakao.com/docs/en/kakaologin/prerequisite)
- [Naver Login](https://developers.naver.com/products/login/api)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
