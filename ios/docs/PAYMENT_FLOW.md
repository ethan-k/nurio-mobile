# Checkout Payment Flow (PortOne / KG Inicis)

How card payments work in the Hotwire Native iOS app, the constraints that shaped
the design, and the failure modes we hit while getting there. Read this **before
touching anything** in `ios/Payments/` or the checkout navigation.

## How a payment flows

1. The checkout page (`/orders/new` or `*/payment_summary`) is a normal Turbo
   page in the **modal session's web view** (path configuration routes checkout
   to the modal context).
2. Tapping **pay by card** runs the PortOne browser SDK, which submits a
   **form POST** to KG Inicis (`mobile.inicis.com` → `ksmobile.inicis.com`)
   *inside the same modal web view*. The init parameters (`P_INIT_PAYMENT`)
   travel in the POST body.
3. The Inicis flow may bounce out to card/bank apps via custom URL schemes and
   back.
4. On completion (success or failure), the gateway redirects through PortOne
   (`checkout-service.prod.iamport.co`) to **`nurio://payment-complete?paymentId=…`**.
   The server advertises this capability via the `NurioPaymentReturn/1` user-agent
   token; the app catches the scheme (`AppRouteCoordinator` →
   `NativePaymentCallback`) and routes to `/payments/portone/complete`, which
   verifies, fulfills, and redirects.

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

### 2. Never `reload()` / `markContentAsStale()` while the modal visitable is on the gateway

After step 2 above, the modal screen's *visitable URL becomes the Inicis URL*.
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

`ios/Payments/CheckoutColdBootWebViewPolicyDecisionHandler.swift`, registered
first in `AppDelegate` (registration **replaces** the default policy chain, so
the framework defaults are re-listed after it).

On a main-frame navigation to a **checkout entry point** (`/orders/new`,
`*/payment_summary`, `*/purchase` — deliberately *not* `/orders/:id` or the
payment-complete return) while the modal session's web view is parked
**off-origin**:

1. **Clear website data for the stuck gateway's registrable domain only**
   (cookies/storage/cache for e.g. `inicis.com`; nurio.kr untouched) →
   neutralizes constraint 4.
2. `navigator.route(url)` as normal.
3. **Force a cold boot of the *newly created* checkout visitable**:
   `modalSession.visit(newVisitable, options: .replace, reload: true)`.
   This loads only the checkout URL — never the gateway URL — sidestepping
   constraints 2 and 3.

The outbound gateway POST is never matched (it is off-origin), so constraint 1
is satisfied by construction.

## Server-side counterparts (nurio Rails repo)

- `OrdersController#refresh_payment_attempt` rotates `merchant_uid` before every
  attempt; `PAYMENT_NOT_PAID` from PortOne's cancel API is treated as
  safe-to-retry (commit `7994a482` in the nurio repo) — without it, abandoning a
  `READY` attempt hard-blocked checkout with HTTP 409.
- `Payments::PortoneController#complete` handles the failure redirect
  (`code=FAILURE_TYPE_PG` etc.) and currently sends failed ticket orders to the
  event page.

## Debugging

Run a Debug build from Xcode (`debugLoggingEnabled` is on) and watch for:

- `[ColdBootVisit] startVisit https://nurio.kr/orders/new…` on checkout
  re-entry — **healthy**.
- `[JavascriptVisit] startVisit …/orders/new` followed by a
  `window.turboNative` TypeError from an `inicis.com` script — constraint 3
  firing (stuck web view).
- `[ColdBootVisit] startVisit https://ksmobile.inicis.com/…` →
  `payError.ini` — constraint 2 firing (something re-loaded the gateway URL).

## Android

Android Hotwire Native reuses sessions the same way and has not received the
equivalent handler yet. Until it does, expect the same stuck-page and
rapid-retry behaviour there.
