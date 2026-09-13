# Checkout Payment Flow (PortOne / KG Inicis)

How card payments work in the Hotwire Native iOS app, the constraints that shaped
the design, and the failure modes we hit while getting there. Read this **before
touching anything** in `ios/Payments/` or the checkout navigation.

## How a payment flows

1. Ticket selection, payment selection/summary, and pass-purchase pages are
   full-screen Turbo pages in the **main session's web view**.
   On the first HTTPS Inicis navigation, `PaymentGatewayPresentation` presents
   the existing checkout `VisitableView` inside a native sheet. It keeps the same
   WKWebView, document, request and cookies; it never cancels/replays the POST.
2. Tapping **pay by card** runs the PortOne browser SDK, which submits a
   **form POST** to KG Inicis (`mobile.inicis.com` → `ksmobile.inicis.com`)
   *inside the same checkout web view*. The init parameters (`P_INIT_PAYMENT`)
   travel in the POST body.
3. The Inicis flow may bounce out to card/bank apps via custom URL schemes and
   back. The bare `nurio://` return only resumes the existing gateway document.
   It is not a page destination. Unknown URLs using Nurio's own scheme are also
   ignored, preventing the system navigator from repeatedly reopening the app.
4. On completion (success or failure), the gateway redirects through PortOne
   (`checkout-service.prod.iamport.co`) to **`nurio://payment-complete?paymentId=…`**.
   The server advertises this capability via the `NurioPaymentReturn/1` user-agent
   token; the app catches the scheme (`AppRouteCoordinator` →
   `NativePaymentCallback`) and routes to `/payments/portone/complete`, which
   verifies, fulfills, and redirects. The gateway sheet restores the checkout
   view before routing. If the destination session is still on the gateway,
   only the merchant completion URL is cold-booted. The callback never reloads
   the Inicis URL. An HTTPS completion redirect uses the same return path.

## Hard constraints (learned the expensive way)

### 1. Never intercept or re-load the outbound gateway navigation

WebKit does **not** expose a navigation's POST body to native code. Any approach
that cancels the checkout → Inicis navigation and re-issues it (dedicated
payment web view, `loadRequest` of the captured URL, etc.) sends a **bodyless
GET**, which Inicis rejects:

- `잘못된 P_INIT_PAYMENT 입니다` — re-issued init request
- `payError.ini` / `비정상적인 접근입니다` (result code 01) — GET of the payment URL

A "host the PG in its own native modal" architecture is therefore **impossible
for this gateway**. It was built and reverted (`01fda92` … reverted in `f9d657d`).

### 2. Never `reload()` / `markContentAsStale()` while the checkout visitable is on the gateway

After step 2 above, the checkout screen's *visitable URL becomes the Inicis URL*.
`Session.reload()` (which `markContentAsStale()` triggers on next appear)
re-visits the **topmost visitable** — i.e. cold-boots the Inicis URL as a GET →
constraint 1 fires → PortOne relays `FAILURE_TYPE_PG` → the server marks the
order failed and redirects to the event page. The user experiences a "random
page" bounce. This was the rapid-retry bug (fixed in `a5df54b`).

### 3. A JavaScript visit cannot run on a gateway page

Hotwire reuses one web view per session. If the user abandons Inicis (Done
button) and re-enters checkout, the session is still `initialized`, so the
framework attempts a **JavaScript visit** — but Turbo's runtime doesn't exist on
the Inicis page (`window.turboNative.cancelVisitWithIdentifier` TypeError). The
visit collapses and the stale gateway page is re-shown. This was the original
stuck-blank-page bug.

### 4. A stale Inicis browser session poisons the retry

Even with a fresh `merchant_uid` (the server rotates it per attempt via
`refresh_payment_attempt`), Inicis rejects a retry that carries the previous
attempt's cookies with result code 01. Signature: happy path works, rapid
abandon-retry fails, app relaunch (fresh web view) recovers.

## The working design

`CheckoutVisitRecovery` runs at `SceneController`'s navigator proposal boundary,
so Turbo link visits, non-Turbo links, and native callbacks share recovery.
For a merchant checkout entry or `/payments/portone/complete`, it inspects the
destination session. When that session is still on a foreign gateway page, it
creates the destination controller, waits until that exact controller is attached,
clears only the abandoned gateway's website data, and cold-boots the merchant URL.
It rechecks controller/session identity after the asynchronous cleanup.

`PaymentGatewayPresentation` restores and dismisses the gateway sheet before
routing a return. It leaves checkout/completion recovery to `CheckoutVisitRecovery`
and cold-boots other merchant return pages when closing a direct event-page
checkout. Neither path reloads the gateway URL. The completion web-policy handler
allows the resulting merchant request through instead of intercepting it again.

Outbound gateway POSTs are always allowed unchanged. Cookie cleanup occurs only
when abandoning/recovering the old gateway, never when presenting its live view.

### Payment return and result navigation

PortOne separates `appScheme` (return from KakaoPay/card-app authentication) from
`redirectUrl` (the final payment result). See the [mobile integration guide](https://developers.portone.io/opi/ko/extra/mobile-payment/readme-v2?v=v2)
and [official iOS implementation](https://github.com/portone-io/ios-sdk/blob/a88175c/Sources/PortOneSdk/PaymentWebView.swift).
A bare `nurio://` must leave the current gateway alive. The web-view policy consumes
Nurio scheme URLs directly through `AppRouteCoordinator`, including callbacks from
frames/popups; it must not send payment results through another OS app-open cycle.

The custom sheet is outside Hotwire's modal navigation stack. Therefore merchant
result proposals also pass through `interceptMerchantVisit` in `SceneController`
**before** Hotwire activates a new visitable. Without this boundary, the result
can load underneath while Hotwire removes the borrowed web view from the sheet,
leaving an empty Payment modal even after successful server processing. The
intercept rejects the initial proposal, dismisses/restores the sheet, then routes
the merchant destination. It does not infer payment success from the app return.

Regression tests cover the actual Navigator with a presented sheet: bare app
resume retains it, both web-view callbacks and direct Hotwire result proposals
dismiss it before the merchant request, and gateway POST/document state survives
presentation. The direct-result test fails with the dismissal intercept removed.

### Gateway sheet lifecycle

The sheet moves the existing `VisitableView` and leaves a snapshot under it.
While it owns the view, the source controller's lifecycle delegate is suspended
so an adaptive full-screen presentation cannot make Hotwire detach the live
payment web view. Dismissal restores the view and delegate before navigation.
Pull-to-refresh and interactive swipe-to-dismiss are disabled during payment.
The Close button returns to the original merchant page through a cold boot when
needed; it never retries a provider POST. Selection pages remain full screen.

The fixture test submits a POST into a real WKWebView, moves it into and out of
the gateway controller, and verifies one navigation and retained JavaScript
state. Physical KakaoPay/Naver Pay completion still requires device testing.

## Server-side counterparts (nurio Rails repo)

- `OrdersController#refresh_payment_attempt` rotates `merchant_uid` before every
  attempt; `PAYMENT_NOT_PAID` from PortOne's cancel API is treated as
  safe-to-retry (commit `7994a482` in the nurio repo) — without it, abandoning a
  `READY` attempt hard-blocked checkout with HTTP 409.
- `Payments::PortoneController#complete` handles the failure redirect
  (`code=FAILURE_TYPE_PG` etc.) and currently sends failed ticket orders to the
  event page.

## Debugging

### Crashlytics context is best-effort

Rails sends allowlisted checkout stages through the `payment-telemetry` Hotwire
bridge. `PaymentCrashContext` hashes the merchant UID before setting Crashlytics
keys and records non-fatals only for technical shell failures. Expected cancel,
decline, and empty SDK responses are not native exceptions.

No telemetry call participates in a payment promise or navigation decision.
Bridge/reporter failures are ignored, app startup clears stale keys, and the
instrumentation never intercepts or replays the outbound Inicis POST. The shared
privacy and release-verification contract is in `../../docs/CRASH_REPORTING.md`.

### WebView diagnostics

Run a Debug build from Xcode (`debugLoggingEnabled` is on) and watch for:

- `[ColdBootVisit] startVisit https://nurio.kr/orders/new…` on checkout
  re-entry — **healthy**.
- `[JavascriptVisit] startVisit …/orders/new` followed by a
  `window.turboNative` TypeError from an `inicis.com` script — constraint 3
  firing (stuck web view).
- `[ColdBootVisit] startVisit https://ksmobile.inicis.com/…` →
  `payError.ini` — constraint 2 firing (something re-loaded the gateway URL).

## Android

Ticket checkout, payment summaries, and pass purchases use the full-screen web
fragment with pull-to-refresh disabled. The bottom-sheet fragment measures its
WebView inside a native ScrollView, which pushes fixed checkout buttons below
the visible area and clips KakaoPay's viewport-sized app-launch page. Keep the
existing full-screen WebView throughout the provider POST and authentication.

`android/.../routing/CheckoutColdBootRouteDecisionHandler.kt` is the parity
implementation, registered before `AppNavigationRouteDecisionHandler` in
`NurioApplication`. Android is simpler than iOS: all visit proposals flow
through route decision handlers, and `Session.reset()` is public API that
forces the next visit to cold-boot — so there is no equivalent of the iOS
"reload re-visits the gateway visitable" trap (constraint 2). The handler
clears the stuck gateway's cookies/storage and resets the session, then returns
`NAVIGATE`. Direct checkout entry from an exact `/events/:id` page or the pass
package index is covered as well as the dedicated payment-summary routes.

Android keeps a two-hour, app-private recovery record containing only the active
merchant reference and, when available, an exact `/events/:id` path. It is not
sent to Crashlytics or logs. A separate `payment-recovery` bridge owns that
state; the `payment-telemetry` bridge remains diagnostics-only. When an external
app cannot launch, or the user closes the payment window or chooses **Check
status**, `MainActivity` makes a single marked visit to
`/payments/portone/complete`. The route handler cold-boots
that visit only when the current WebView is foreign, and Rails queries PortOne
before deciding success/failure. A paymentId-less callback uses the active
recovery record; `/settings/tickets` remains only the last-resort fallback when
there is no recoverable attempt.

Normal completion callbacks use the same cold-boot rule as recovery. Both
`nurio://payment-complete` and the merchant HTTPS completion URL are consumed
inside the WebView and routed through `MainActivity`, without reopening the app
through Android. A bare `nurio://` only resumes the current gateway document.
Before routing a result or recovery, the activity closes its payment popup tree
programmatically, without starting a second user-dismiss recovery. Returning
from an external app without a result preserves the original gateway document:
wallet authentication can finish before the gateway approves the payment.
After two seconds the app offers **Check status**, without navigating or
claiming recovery automatically. Pausing or receiving a result dismisses that
prompt. An automatic recovery redirect at this point can strand a payment in
PortOne's `READY` state by destroying the gateway before it finishes.

During an active payment, provider HTTP/HTTPS steps stay in their original main
or popup WebView, including wallet domains outside Inicis/PortOne such as
KakaoPay and Naver Pay. Merchant completion returns to the main navigator. Only external app
schemes such as `intent://` are handed to Android. Never reload, intercept, or
replay the outbound Inicis POST. Constraints 1–4 above apply to Android all the same.

Android emulator regression tests cover ticket/pass popup completion, native
dismissal and provider window-opener behavior. A separate test parks the actual
navigator WebView on a non-Turbo gateway document after a form POST and verifies
that both callback types load the merchant completion with GET and remove the
native progress overlay without replaying the gateway request. It also covers
delayed completion after a stop/resume, an external callback intent, an explicit
status check, and a wallet bridge redirect that must remain in the same WebView.
These fixtures do not prove provider or physical-device
payment completion.

### Testing Android against localhost

The customer debug build accepts a `nurioBaseUrl` Gradle property or
`NURIO_BASE_URL` environment variable. It must be an HTTP(S) origin without a
path, credentials, query, or fragment. Release and `productionDebug` builds
always use `https://nurio.kr`.

With Rails running on port 3000, connect the selected emulator and install:

```sh
adb -s emulator-5554 reverse tcp:3000 tcp:3000
cd android
./gradlew :app:installDebug -PnurioBaseUrl=http://localhost:3000
```

Replace the serial with the device shown by `adb devices`. Debug-only network
security settings allow cleartext for `localhost`, `127.0.0.1`, and `10.0.2.2`;
other hosts still require HTTPS. The default debug origin remains `nurio.kr`.

Confirm the rendered checkout does not say **Mock mode enabled** before claiming
provider coverage. A previously started Rails process may retain mock-mode
environment overrides even when a new Rails runner reports real configuration.
Provider authentication and a verified paid order are separate from a successful
SDK launch, cancellation, or an automated callback fixture.
