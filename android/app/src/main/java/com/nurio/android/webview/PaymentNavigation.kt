package com.nurio.android.webview

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import com.nurio.android.BuildConfig

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
        val scheme = uri.scheme?.lowercase() ?: return false
        return scheme in webSchemes
    }

    fun openExternalPaymentApp(context: Context, uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase() ?: return false
        if (scheme in webSchemes || scheme in ignoredSchemes) return false

        if (scheme == "intent") {
            return openIntentUri(context, uri.toString())
        }

        launch(context, Intent(Intent.ACTION_VIEW, uri))
        return true
    }

    fun openExternalWebUrl(context: Context, uri: Uri): Boolean {
        if (!isWebUrl(uri)) return false

        launch(context, Intent(Intent.ACTION_VIEW, uri))
        return true
    }

    private fun isPaymentContext(location: String): Boolean {
        val uri = location.toUri()
        return isPaymentGatewayUrl(uri) || isCheckoutEntryUrl(uri)
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

    private fun openIntentUri(context: Context, location: String): Boolean {
        val intent = try {
            Intent.parseUri(location, Intent.URI_INTENT_SCHEME)
        } catch (_: Exception) {
            return true
        }

        intent.addCategory(Intent.CATEGORY_BROWSABLE)
        intent.component = null
        intent.selector = null

        if (launch(context, intent)) return true

        val fallbackUrl = intent.getStringExtra("browser_fallback_url")
        if (!fallbackUrl.isNullOrBlank()) {
            launch(context, Intent(Intent.ACTION_VIEW, fallbackUrl.toUri()))
            return true
        }

        val packageName = intent.`package`
        if (!packageName.isNullOrBlank()) {
            launch(context, Intent(Intent.ACTION_VIEW, "market://details?id=$packageName".toUri()))
        }

        return true
    }

    private fun launch(context: Context, intent: Intent): Boolean {
        if (context !is Activity) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            context.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
