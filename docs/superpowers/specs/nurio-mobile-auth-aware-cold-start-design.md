# Nurio Mobile Auth-Aware Cold Start Design

## Goal

When the main Nurio iOS or Android app starts without an incoming deep link:

- a signed-out member lands on the existing `/login` page;
- a signed-in member continues to land on `/events`.

This behavior applies only to the primary `nurio.kr` mobile apps. Study, tutors, browser navigation, notification destinations, and explicit deep links are out of scope.

## Root Cause

Both native clients currently configure the Hotwire navigator with `https://nurio.kr/events` as the cold-start location. Because `/events` is intentionally public, Rails has no reason to redirect a signed-out request to login.

Rails already implements the required session decision at `GET /`: native guests are redirected to `/login`, while signed-in native members are redirected to `/events`. The native shells bypass that existing gate by starting one route too deep.

## Design

Use the site root as the native cold-start location on both platforms and let Rails remain the source of truth for authentication state.

### iOS

- Give `AppEnvironment` an explicit cold-start URL that resolves to the configured base URL root.
- Configure `SceneController`'s `Navigator` with that cold-start URL.
- Keep invalid or blocked deep-link fallback behavior pointed at `/events`; changing the cold-start rule must not broaden the behavior change to deep-link handling.

### Android

- Define the cold-start location from `BuildConfig.BASE_URL`, normalized to the site root.
- Configure `MainActivity`'s `NavigatorConfiguration` with that root location.
- Preserve the existing `/events` fallbacks for invalid app-open URLs and disallowed notification URLs.

## Request Flow

1. A cold launch opens `GET https://nurio.kr/` in the platform's Hotwire session.
2. The WebView sends its existing Nurio native user agent and cookies.
3. Rails checks the existing Rodauth session in `PagesController#landing`.
4. Rails redirects a guest to `/login` or a signed-in member to `/events`.
5. Hotwire follows the redirect in the same navigator session.

No native cookie inspection, new API endpoint, or duplicated authentication state is introduced.

## Error and Edge-Case Behavior

- Explicit universal links, custom-scheme links, auth callbacks, payment callbacks, and notification paths continue routing to their requested destinations.
- Invalid or blocked customer deep links retain their current `/events` fallback.
- If an expired cookie is present, Rails treats it as signed out and redirects to `/login`.
- Browser requests to `/events` remain public.
- The existing iOS `401` fallback to `/auth/login` is unchanged because it handles failed protected visits, not ordinary cold starts.

## Verification

- Add an iOS unit test proving the cold-start URL is the base URL root and keep the existing deep-link fallback assertion for `/events`.
- Add an Android local unit test for root-location normalization and wire `MainActivity` to the tested helper.
- Run the focused iOS test target and Android local unit tests.
- Build the main iOS scheme and Android debug app to catch platform integration or compilation failures.
- Confirm the Rails request specs that already prove native `GET /` redirects guests to `/login` and signed-in members to `/events` still pass if Rails verification is needed; no Rails production code change is planned.

## Documentation

Update the main iOS submission notes that currently describe `/events` as the cold-start page. The notes will describe `/` as the native entry point and document its authentication-aware redirects.
