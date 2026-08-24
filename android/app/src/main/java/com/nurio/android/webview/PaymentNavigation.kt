package com.nurio.android.webview

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import com.nurio.android.BuildConfig
import com.nurio.android.payments.PaymentCrashTelemetry
import com.nurio.android.payments.PaymentFailureKind

internal data class ExternalPaymentNavigationOutcome(
    val consumed: Boolean,
    val launched: Boolean,
    val failureKind: PaymentFailureKind? = null,
)

object PaymentNavigation {
    private val webSchemes = setOf("http", "https")
    private val ignoredSchemes = setOf("about", "blob", "data", "javascript")
    private val gatewayDomains = setOf(
        "inicis.com",
        "iamport.co",
        "portone.io"
    )

    fun shouldStayInWebView(uri: Uri, currentLocation: String?): Boolean {
        if (!isPaymentGatewayUrl(uri)) return false
        return currentLocation == null || isPaymentContext(currentLocation)
    }

    fun isPaymentContext(location: String?): Boolean {
        if (location.isNullOrBlank()) return false

        val uri = location.toUri()
        return isPaymentGatewayUrl(uri) || isCheckoutEntryUrl(uri)
    }

    private fun isPaymentGatewayUrl(uri: Uri): Boolean {
        if (!isWebUrl(uri)) return false
        val host = uri.host?.lowercase() ?: return false

        return gatewayDomains.any { domain ->
            host == domain || host.endsWith(".$domain")
        }
    }

    fun isIgnoredUrl(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase() ?: return true
        return scheme in ignoredSchemes
    }

    fun isWebUrl(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase()
            ?: return false
        return scheme in webSchemes
    }

    internal fun openExternalPaymentApp(context: Context, uri: Uri): ExternalPaymentNavigationOutcome {
        val scheme = uri.scheme?.lowercase()
            ?: return ExternalPaymentNavigationOutcome(consumed = false, launched = false)
        if (scheme in webSchemes || scheme in ignoredSchemes) {
            return ExternalPaymentNavigationOutcome(consumed = false, launched = false)
        }

        if (scheme == "intent") {
            return openIntentUri(context, uri.toString())
        }

        val launch = launch(context, Intent(Intent.ACTION_VIEW, uri))
        return paymentOutcome(launch)
    }

    fun openExternalWebUrl(context: Context, uri: Uri): Boolean {
        if (!isWebUrl(uri)) return false

        launch(context, Intent(Intent.ACTION_VIEW, uri))
        return true
    }

    private fun isCheckoutEntryUrl(uri: Uri): Boolean {
        if (!isWebUrl(uri)) return false

        val baseHost = BuildConfig.BASE_URL.toUri().host?.lowercase() ?: return false
        val host = uri.host?.lowercase() ?: return false
        if (host != baseHost && host != "www.$baseHost") return false

        val path = uri.path.orEmpty()
        return path == "/orders/new" ||
            path.endsWith("/payment_summary") ||
            path.endsWith("/purchase")
    }

    private fun openIntentUri(context: Context, location: String): ExternalPaymentNavigationOutcome {
        val intent = try {
            Intent.parseUri(location, Intent.URI_INTENT_SCHEME)
        } catch (_: Exception) {
            PaymentCrashTelemetry.reportTechnicalFailure(PaymentFailureKind.MALFORMED_INTENT)
            return ExternalPaymentNavigationOutcome(
                consumed = true,
                launched = false,
                failureKind = PaymentFailureKind.MALFORMED_INTENT,
            )
        }

        intent.addCategory(Intent.CATEGORY_BROWSABLE)
        intent.component = null
        intent.selector = null

        val primaryLaunch = launch(context, intent)
        if (primaryLaunch == LaunchOutcome.LAUNCHED) return paymentOutcome(primaryLaunch)

        reportLaunchFailure(primaryLaunch)

        val fallbackUrl = intent.getStringExtra("browser_fallback_url")
        if (!fallbackUrl.isNullOrBlank()) {
            val fallbackLaunch = launch(context, Intent(Intent.ACTION_VIEW, fallbackUrl.toUri()))
            if (fallbackLaunch == LaunchOutcome.LAUNCHED) {
                PaymentCrashTelemetry.markExternalAppHandoff()
                return ExternalPaymentNavigationOutcome(
                    consumed = true,
                    launched = true,
                    failureKind = primaryLaunch.failureKind,
                )
            }
        }

        val packageName = intent.`package`
        if (!packageName.isNullOrBlank()) {
            val marketLaunch = launch(
                context,
                Intent(Intent.ACTION_VIEW, "market://details?id=$packageName".toUri()),
            )
            if (marketLaunch == LaunchOutcome.LAUNCHED) {
                PaymentCrashTelemetry.markExternalAppHandoff()
                return ExternalPaymentNavigationOutcome(
                    consumed = true,
                    launched = true,
                    failureKind = primaryLaunch.failureKind,
                )
            }
        }

        return ExternalPaymentNavigationOutcome(
            consumed = true,
            launched = false,
            failureKind = primaryLaunch.failureKind,
        )
    }

    private fun paymentOutcome(launch: LaunchOutcome): ExternalPaymentNavigationOutcome {
        if (launch == LaunchOutcome.LAUNCHED) {
            PaymentCrashTelemetry.markExternalAppHandoff()
        } else {
            reportLaunchFailure(launch)
        }

        return ExternalPaymentNavigationOutcome(
            consumed = true,
            launched = launch == LaunchOutcome.LAUNCHED,
            failureKind = launch.failureKind,
        )
    }

    private fun reportLaunchFailure(launch: LaunchOutcome) {
        launch.failureKind?.let(PaymentCrashTelemetry::reportTechnicalFailure)
    }

    private fun launch(context: Context, intent: Intent): LaunchOutcome {
        if (context !is Activity) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            context.startActivity(intent)
            LaunchOutcome.LAUNCHED
        } catch (_: ActivityNotFoundException) {
            LaunchOutcome.UNAVAILABLE
        } catch (_: SecurityException) {
            LaunchOutcome.SECURITY_REJECTED
        }
    }

    private enum class LaunchOutcome(val failureKind: PaymentFailureKind?) {
        LAUNCHED(null),
        UNAVAILABLE(PaymentFailureKind.EXTERNAL_APP_UNAVAILABLE),
        SECURITY_REJECTED(PaymentFailureKind.EXTERNAL_APP_SECURITY),
    }
}
