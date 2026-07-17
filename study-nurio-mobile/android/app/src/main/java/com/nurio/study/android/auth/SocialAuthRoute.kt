package com.nurio.study.android.auth

import java.net.URI
import java.net.URISyntaxException
import java.util.Locale

enum class SocialAuthProvider(val path: String) {
    KAKAO("/auth/kakao"),
    GOOGLE("/auth/google_oauth2"),
    NAVER("/auth/naver");

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
        fun resolve(startPath: String, baseUrl: String): SocialAuthRoute? {
            return try {
                val baseUri = URI(baseUrl)
                val resolvedUri = baseUri.resolve(startPath)
                val scheme = resolvedUri.scheme?.lowercase(Locale.ROOT)
                val resolvedHost = resolvedUri.host
                val baseHost = baseUri.host

                if (
                    scheme !in setOf("http", "https") ||
                    resolvedHost == null ||
                    baseHost == null ||
                    !resolvedHost.equals(baseHost, ignoreCase = true)
                ) {
                    return null
                }

                val provider = SocialAuthProvider.fromPath(resolvedUri.path) ?: return null

                SocialAuthRoute(provider, resolvedUri.toString())
            } catch (_: URISyntaxException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
        }
    }
}
