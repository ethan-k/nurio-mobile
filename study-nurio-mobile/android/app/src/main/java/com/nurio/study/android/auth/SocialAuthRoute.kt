package com.nurio.study.android.auth

import java.net.URI
import java.net.URISyntaxException
import java.util.Locale

enum class SocialAuthProvider(val path: String) {
    KAKAO("/auth/kakao"),
    GOOGLE("/auth/google_oauth2"),
    NAVER("/auth/naver"),
    APPLE("/auth/apple");

    companion object {
        fun fromPath(path: String): SocialAuthProvider? = entries.firstOrNull { provider ->
            provider.path == path
        }
    }
}

data class SocialAuthRoute(
    val provider: SocialAuthProvider,
    val url: String
) {
    companion object {
        private val webSchemes = setOf("http", "https")

        fun resolve(startPath: String, baseUrl: String): SocialAuthRoute? {
            return try {
                val baseUri = URI(baseUrl)
                val baseScheme = baseUri.scheme?.lowercase(Locale.ROOT) ?: return null
                val baseHost = baseUri.host

                if (
                    baseScheme !in webSchemes ||
                    baseHost == null ||
                    baseUri.userInfo != null
                ) {
                    return null
                }

                val resolvedUri = baseUri.resolve(startPath)
                val resolvedScheme = resolvedUri.scheme?.lowercase(Locale.ROOT) ?: return null
                val resolvedHost = resolvedUri.host

                if (
                    resolvedScheme != baseScheme ||
                    resolvedHost == null ||
                    !resolvedHost.equals(baseHost, ignoreCase = true) ||
                    resolvedUri.userInfo != null ||
                    effectivePort(resolvedUri, resolvedScheme) != effectivePort(baseUri, baseScheme)
                ) {
                    return null
                }

                val provider = SocialAuthProvider.fromPath(resolvedUri.rawPath) ?: return null

                SocialAuthRoute(provider, resolvedUri.toString())
            } catch (_: URISyntaxException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
        }

        private fun effectivePort(uri: URI, scheme: String): Int {
            if (uri.port != -1) return uri.port

            return when (scheme) {
                "http" -> 80
                "https" -> 443
                else -> -1
            }
        }
    }
}
