package com.nurio.android.localization

import android.util.Log
import android.webkit.CookieManager
import java.net.URI

internal interface LocaleCookieStore {
    fun cookies(url: String): String?
    fun setCookie(url: String, value: String)
    fun flush()
}

internal class LocaleCookieBootstrapper(
    private val cookieStore: LocaleCookieStore = AndroidLocaleCookieStore(),
    private val logFailure: (Exception) -> Unit = { exception ->
        Log.w(TAG, "Unable to bootstrap the UI locale cookie", exception)
    },
) {
    fun bootstrap(baseUrl: String, languageIdentifiers: List<String>) {
        try {
            if (hasAuthoritativeLocaleCookie(cookieStore.cookies(baseUrl))) return

            val language = UiLocaleResolver.resolve(languageIdentifiers)
            val secureAttribute = if (isHttps(baseUrl)) "; Secure" else ""
            val cookie = "$DEVICE_LOCALE_COOKIE_NAME=$language; Path=/; Max-Age=$MAX_AGE_SECONDS; SameSite=Lax$secureAttribute"

            cookieStore.setCookie(baseUrl, cookie)
            cookieStore.flush()
        } catch (exception: Exception) {
            logFailure(exception)
        }
    }

    private fun hasAuthoritativeLocaleCookie(cookies: String?): Boolean {
        return cookies
            ?.split(';')
            ?.any { entry ->
                val separatorIndex = entry.indexOf('=')
                if (separatorIndex < 0) return@any false

                val cookieName = entry.substring(0, separatorIndex).trim()
                cookieName == LOCALE_COOKIE_NAME || cookieName == DEVICE_LOCALE_COOKIE_NAME
            }
            ?: false
    }

    private fun isHttps(baseUrl: String): Boolean {
        return URI(baseUrl).scheme.equals("https", ignoreCase = true)
    }

    private companion object {
        const val TAG = "LocaleCookieBootstrapper"
        const val LOCALE_COOKIE_NAME = "locale"
        const val DEVICE_LOCALE_COOKIE_NAME = "device_locale"
        const val MAX_AGE_SECONDS = 31_536_000
    }
}

private class AndroidLocaleCookieStore : LocaleCookieStore {
    override fun cookies(url: String): String? = CookieManager.getInstance().getCookie(url)

    override fun setCookie(url: String, value: String) {
        CookieManager.getInstance().setCookie(url, value)
    }

    override fun flush() {
        CookieManager.getInstance().flush()
    }
}
