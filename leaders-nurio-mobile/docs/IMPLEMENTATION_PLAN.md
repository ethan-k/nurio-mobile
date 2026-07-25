# Nurio Study Leader Mobile Implementation Plan

## Goal and Success Criteria

Ship an iPhone and Android phone app that gives approved Study leaders a focused, reliable workspace for daily session operations. The first release succeeds when:

- OAuth completes through `nurioleaders://auth-callback` and creates the authenticated leader-host session.
- Only `studyleaders.nurio.kr` routes render in-app; admin, learner, tutoring, support, and arbitrary external hosts leave the app.
- Today, Schedule, Notifications, Sessions, Earnings, Settings, candidate onboarding, and account deletion work in Korean and English.
- Native chrome does not duplicate the portal navigation.
- Both apps build from clean checkouts and pass route/callback tests.
- App Review and Play review can sign in with a stable approved-leader demo account containing representative, non-sensitive data.

## Delivery Phases

### 1. Foundation — implemented in this scaffold

- Add separate iOS and Android targets with unique identifiers, callback scheme, icons, and production start URL.
- Load a bundled Hotwire path configuration and disable pull-to-refresh on authentication and interactive schedule routes.
- Add strict OAuth callback parsing, native browser authentication, same-origin route policy, and hidden native navigation bars.
- Add unit coverage for callback validation and scope isolation.

### 2. Rails/native contract — required before TestFlight or internal Play testing

- Map `studyleaders.*` OAuth callbacks to `nurioleaders://auth-callback`.
- Recognize stable `Nurio Study Leader iOS/Android` user-agent prefixes as native requests.
- Expose the existing account-deletion flow on the leader host and link it from Settings.
- Keep Sign in with Apple enabled whenever Google, Kakao, or Naver login is offered to the public iOS build.
- Add request coverage for native OAuth parameters, callback host mapping, account deletion access, and leader-host isolation.

### 3. Release hardening

- Add a review/demo leader with populated Today, Schedule, Sessions, Notifications, and Earnings states.
- Run authenticated device QA for safe areas, keyboard/forms, Turbo navigation, file uploads, calendar editing, logout, and cold-start deep links.
- Add leader-scoped push registration only after dedicated Apple/FCM credentials and token-routing policy are ready; do not reuse the learner app package configuration.
- Capture final native screenshots from the production-signed candidates, then complete privacy/data-safety declarations from actual runtime behavior.

## Interfaces and Invariants

- `AppEnvironment.baseURL`: defaults to `https://studyleaders.nurio.kr`; a local override is allowed only through `NURIO_BASE_URL`.
- Native callback: exactly one nonblank `token` and one nonblank `state`, no user info, port, path, or fragment.
- OAuth providers: Google, Kakao, Naver, and Apple paths on the exact configured leader origin.
- In-app origin: exact scheme, host, and effective port match. `/admin` is always external.
- No consumer, tutor, or admin feature is copied into native code. Rails remains the product source of truth.

## Verification Matrix

| Scenario | iOS | Android | Rails |
| --- | --- | --- | --- |
| Valid/invalid OAuth callback | XCTest | JUnit | service/request spec |
| Leader-host route stays in app | XCTest | JUnit | request spec |
| Other host/admin opens externally | XCTest | JUnit | host-isolation spec |
| Login/candidate/approved leader | simulator | emulator | request spec |
| EN/KO navigation and forms | simulator | emulator | request spec |
| Account deletion initiation | simulator | emulator | request spec |
| Store screenshots match release | 6.9-inch capture | 9:16 capture | seeded demo state |

## Explicit Non-goals for 1.0

- Offline session mutation or native data replication.
- Native reimplementation of Rails screens.
- Payments or digital-goods purchase flows.
- iPad, tablet, watch, TV, or desktop distribution.
- Sharing session cookies across Nurio subdomains.
