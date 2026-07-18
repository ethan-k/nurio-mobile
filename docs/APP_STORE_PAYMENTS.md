# App Store Payments Policy — StoreKit / In-App Purchase Position

Status of record for all three iOS targets (`ios/`, `study-nurio-mobile/`, `tutors-nurio-mobile/`).

## TL;DR

**We do not integrate StoreKit, and we must not add Apple In-App Purchase for what we sell today.**
Everything purchasable in the apps is a real-world service consumed outside the app
(in-person meetups, study groups, 1:1 tutoring lessons). Under App Store Review
Guideline 3.1.3(e), such purchases **must** use payment methods *other than* IAP — which
is exactly what the web checkout (Portone/Inicis for nurio.kr, Toss Payments for
tutors.nurio.kr) already does inside the Hotwire Native shell.

Nothing needs to change in App Store Connect except review notes (see below).
Do **not** create In-App Purchase products.

## What each target sells

| Target | Purchasable items (`Order#order_kind`) | Nature |
|---|---|---|
| `ios/` (customer app) | `ticket`, `pass_package`, `deposit`, `event_add_on` | Tickets/passes for **in-person** language-exchange meetups at physical venues; wallet deposits spendable only on those meetups |
| `study-nurio-mobile/` | `study_group` | Enrollment in study groups (real-world group programs) |
| `tutors-nurio-mobile/` | — (tutor-only shell) | No consumer purchases; tutors manage lessons and payouts. Student-side `tutoring_single` / `tutoring_package` credit purchases happen on the web or customer surfaces |

## Why no IAP is required (guideline mapping)

- **3.1.3(e) — Goods and Services Outside of the App**: apps selling physical goods or
  services consumed outside the app **must** use purchase methods other than IAP.
  Meetup tickets, passes, event add-ons, and study-group enrollment are in-person
  services → non-IAP web checkout is not just allowed, it is the required method.
- **3.1.3(d) — Person-to-person services**: real-time **1:1** person-to-person services
  (Apple's own example is tutoring) may use purchase methods other than IAP.
  Tutoring lesson credits qualify as long as lessons stay 1:1.
- **3.1.1** only applies to digital content/features unlocked *within* the app. We sell
  none.

Wallet deposits are safe under this position **only because** wallet credit can be spent
solely on real-world services. That linkage is load-bearing — see red lines below.

## App Store Connect: what to do (and not do)

1. **In-App Purchases section**: leave empty. Creating IAP products would signal to
   App Review that we sell digital goods and invite 3.1.1 scrutiny.
2. **Review notes**: every submission should include the payments paragraph now listed
   in each target's `ios/docs/SUBMISSION.md` review notes — it preempts the most likely
   rejection (a reviewer seeing a credit-card form and reflexively citing 3.1.1).
3. **App Privacy label**: payment is collected by the PG inside the web checkout. Verify
   the privacy label declares "Purchase History" / "Payment Info" as collected if the
   questionnaire's definitions apply; keep it consistent across the three targets.
4. No entitlements, capabilities, or agreements changes are needed for the current model.

## If App Review rejects citing 3.1.1

Reply in Resolution Center, in this order:

1. State that all purchases are for real-world services consumed outside the app:
   in-person language-exchange meetups at physical venues (include a sample event URL),
   study-group programs, and 1:1 person-to-person tutoring lessons.
2. Cite **Guideline 3.1.3(e)** (physical services must not use IAP) and **3.1.3(d)**
   (1:1 person-to-person services may use non-IAP).
3. Offer a demo account and a sample checkout the reviewer can inspect.

Do not "fix" such a rejection by hiding checkout from the app before appealing — the
appeal usually succeeds for genuinely physical-world services.

## Red lines — changes that WOULD force StoreKit/IAP

Adding any of the following to an app surface makes IAP mandatory for that item
(and can drag the wallet with it):

- Paid **digital** features consumed in-app: AI practice sessions, premium quiz/warmup
  packs, learning content unlocks, or any subscription to app functionality.
- **One-to-few or one-to-many** realtime online classes (group video lessons, webinars) —
  3.1.3(d) explicitly requires IAP for these, even though they are "live".
- Making wallet/deposit credit spendable on any digital good — this converts the whole
  deposit flow into an IAP-scoped purchase.
- Tutoring shifting from 1:1 to group online formats.

If a product decision crosses one of these lines, budget for the StoreKit work below
**before** shipping the feature, and get the App Store Connect products approved with
the build.

## Implementation sketch (only if a red line is crossed)

1. **App Store Connect**: create products (consumable / non-consumable / auto-renewable
   subscription); complete Agreements, Tax, and Banking.
2. **iOS shell (StoreKit 2)**: `Product.products(for:)`, `product.purchase()`,
   `Transaction.currentEntitlements`; expose purchase triggers to the web layer via a
   Hotwire Native bridge component so Rails views can open the native purchase sheet.
3. **Rails backend**: verify signed JWS transactions server-side (App Store Server API /
   Server Library), add an App Store Server Notifications V2 webhook controller
   alongside the existing Portone webhook, create a new `order_kind`, and fulfill from
   verified transactions only — never trust the client.
4. **Testing**: sandbox Apple IDs, StoreKit configuration files for local testing,
   then TestFlight.
5. **Korea storefront option**: Apple's external-purchase entitlement for South Korea
   allows a third-party PG for digital goods at a reduced commission; evaluate against
   standard IAP economics at that time.

## Related docs

- `ios/docs/PAYMENT_FLOW.md` — how the web (Portone/Inicis) checkout runs inside the
  customer shell, including the cold-boot handoff rules.
- `ios/docs/SUBMISSION.md`, `study-nurio-mobile/ios/docs/SUBMISSION.md`,
  `tutors-nurio-mobile/ios/docs/SUBMISSION.md` — per-target review notes.
