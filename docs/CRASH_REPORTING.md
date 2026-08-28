# Crash Reporting

Firebase Crashlytics is configured independently for the Nurio customer, Nurio
Study, and Nurio Study Leader iOS/Android apps. Release reports use stable app
identity keys:

| Product | `app_surface` |
| --- | --- |
| Nurio customer | `nurio` |
| Nurio Study | `nurio_study` |
| Nurio Study Leader | `nurio_study_leader` |

Every app also sets `native_platform` to `ios` or `android`. Debug builds disable
Crashlytics collection. Study Debug builds may run without the external Firebase
configuration; production/release builds still require the configuration to be
present and match the expected Firebase project and bundle/package ID.

Leader Android is independent. Leader iOS Crashlytics and these identity keys
must land with its existing push/Firebase integration bundle: the committed
Leader iOS target has no Firebase for Crashlytics to attach to, so the identity
lines must not be cherry-picked separately from that bundle.

## Payment context

The customer and Study apps register a `payment-telemetry` Hotwire bridge. Rails
owns the checkout lifecycle events; native code owns hashing, Crashlytics keys,
native handoff/callback context, and technical non-fatals. The Leader app has no
customer payment flow and therefore sets only product/platform identity.

Customer Android also registers a separate `payment-recovery` bridge. Recovery
state and navigation must never be added to `payment-telemetry`; raw merchant
references used privately for provider reconciliation must never enter logs or
Crashlytics.

Payment diagnostics are strictly best-effort:

- no bridge callback or Firebase result participates in a payment promise;
- malformed/missing bridge data is ignored;
- reporter exceptions are caught per key, log, and non-fatal call;
- missing Firebase leaves telemetry inactive;
- no diagnostic code intercepts or replays the KG Inicis form POST.

Only the first 16 lowercase hex characters of the payment reference's SHA-256
digest can enter Crashlytics. Do not add raw merchant IDs, amounts, names,
emails, phone numbers, URLs/query strings, provider messages/payloads, tokens,
signatures, or payment credentials.

Expected cancellation, decline, empty SDK response, and ordinary validation
errors are not non-fatals. Technical categories use stable safe names such as
`sdk_load`, `sdk_request`, `attempt_refresh`, `native_request`,
`malformed_callback`, and `renderer_terminated`.

## Delivery proof

A local build or test does not prove Firebase delivery. Before calling a release
verified:

1. Install an internal/release build for each product/platform.
2. Trigger one controlled test crash or safe non-fatal.
3. Confirm it appears under the correct Firebase app with `app_surface` and
   `native_platform`.
4. For customer/Study payment context, confirm only allowlisted keys appear and
   `payment_reference` is hashed.
5. Confirm iOS frames are symbolicated after dSYM upload.
