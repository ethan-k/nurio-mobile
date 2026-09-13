# Customer Android payment windows

Payment popups must retain the WebView supplied through `WebViewTransport`.
`PaymentWebChromeClient` presents that child in `PaymentPopupWindow`, preserving
form POST bodies, the checkout opener, `postMessage`, and `window.close()`.
Never transfer a gateway navigation to another WebView with `loadUrl`: this
reissues a GET and discards the original form submission.

The popup displays its current host and a localized Close action. Provider
`window.close()` returns control to the checkout's JavaScript. Native Close or
Back asks Rails to verify the pending payment through the existing
`native_recovery=1` return route; closing does not establish success or failure.
Bank-app handoffs retain the popup, and browser fallbacks load inside it.
Detaching the checkout closes its owned popups and disposes their WebViews.

This behavior is shared by customer ticket/deposit and pass checkout fragments.
It applies only to the top-level `android/` app.

## Regression verification

From `android/`, using JDK 17 and an Android emulator:

```sh
./gradlew :app:testDebugUnitTest :app:lintDebug :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.nurio.android.webview.PaymentPopupWebViewTest
```

The instrumented tests use real WebView popup creation and form submission, with
all network requests blocked or intercepted locally. Ticket and pass scenarios
assert an intact POST, a visible provider window, an unchanged checkout opener,
provider cancellation through `postMessage` and `window.close`, another payment
attempt, and native Close/Back routing to status verification.

On the original 1.0.15 (20) source, both initial-payment scenarios reproduced a
popup POST followed by replacement GETs in the parent. This is local regression
evidence; it does not establish the cause of every reported payment failure.
Real PortOne/Inicis, installed bank apps, physical-device payment completion,
and adoption through a new store build require separate verification.

Android's [WebViewClient contract](https://developer.android.com/reference/android/webkit/WebViewClient)
documents that POST navigations skip `shouldOverrideUrlLoading`, so popup
presentation also handles `onPageStarted` without replaying the request.
