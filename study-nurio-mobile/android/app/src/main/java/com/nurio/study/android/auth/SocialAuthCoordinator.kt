package com.nurio.study.android.auth

import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.Locale

class SocialAuthCoordinator(
    private val startKakao: () -> Unit,
    private val openSystemAuth: (String) -> Unit
) {
    fun start(route: SocialAuthRoute) {
        when (route.provider) {
            SocialAuthProvider.KAKAO -> startKakao()
            SocialAuthProvider.GOOGLE,
            SocialAuthProvider.NAVER -> openSystemAuth(route.url)
        }
    }
}

internal object NativeAuthCallback {
    private const val CALLBACK_SCHEME = "nuriostudy"
    private const val CALLBACK_HOST = "auth-callback"
    private const val TOKEN_AUTH_PATH = "/auth/native/token_auth"
    private val webSchemes = setOf("http", "https")

    fun toTokenAuthUrl(callbackUrl: String, baseUrl: String): String? {
        return try {
            val callbackUri = URI(callbackUrl)
            if (
                !callbackUri.scheme.equals(CALLBACK_SCHEME, ignoreCase = true) ||
                !callbackUri.host.equals(CALLBACK_HOST, ignoreCase = true) ||
                callbackUri.userInfo != null
            ) {
                return null
            }

            val queryParameters = parseQuery(callbackUri.rawQuery ?: return null)
            val token = queryParameters["token"]?.singleOrNull()?.takeIf(String::isNotBlank)
                ?: return null
            val state = queryParameters["state"]?.singleOrNull()?.takeIf(String::isNotBlank)
                ?: return null

            val baseUri = URI(baseUrl)
            val scheme = baseUri.scheme?.lowercase(Locale.ROOT) ?: return null
            if (scheme !in webSchemes || baseUri.host == null || baseUri.userInfo != null) {
                return null
            }

            val endpoint = URI(
                scheme,
                null,
                baseUri.host,
                baseUri.port,
                TOKEN_AUTH_PATH,
                null,
                null
            )
            QueryUriBuilder(endpoint)
                .appendQueryParameter("token", token)
                .appendQueryParameter("state", state)
                .build()
        } catch (_: Exception) {
            null
        }
    }

    private fun parseQuery(rawQuery: String): Map<String, List<String>> {
        return rawQuery
            .split('&')
            .map { pair ->
                val delimiter = pair.indexOf('=')
                val rawName = if (delimiter >= 0) pair.substring(0, delimiter) else pair
                val rawValue = if (delimiter >= 0) pair.substring(delimiter + 1) else ""
                decode(rawName) to decode(rawValue)
            }
            .groupBy(keySelector = Pair<String, String>::first, valueTransform = Pair<String, String>::second)
    }

    private fun decode(value: String): String =
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())

    private class QueryUriBuilder(private val endpoint: URI) {
        private val parameters = mutableListOf<Pair<String, String>>()

        fun appendQueryParameter(name: String, value: String) = apply {
            parameters += name to value
        }

        fun build(): String = buildString {
            append(endpoint.toASCIIString())
            parameters.forEachIndexed { index, (name, value) ->
                append(if (index == 0) '?' else '&')
                append(encode(name))
                append('=')
                append(encode(value))
            }
        }

        private fun encode(value: String): String =
            URLEncoder.encode(value, StandardCharsets.UTF_8.name())
    }
}
