package com.nurio.studyleaders.android.routing

import java.net.URI
import java.util.Locale

internal object LeaderScopePolicy {
    private val blockedPrefixes = listOf("/admin")
    private val webSchemes = setOf("http", "https")

    fun shouldOpenExternally(location: String, appUrl: String): Boolean {
        return try {
            val appUri = URI(appUrl)
            val resolvedUri = appUri.resolve(location)
            val scheme = resolvedUri.scheme?.lowercase(Locale.ROOT) ?: return false

            if (scheme !in webSchemes) return false
            if (!sameOrigin(resolvedUri, appUri)) return true

            val path = resolvedUri.path.orEmpty().lowercase(Locale.ROOT)
            blockedPrefixes.any { prefix ->
                path == prefix || path.startsWith("$prefix/")
            }
        } catch (_: Exception) {
            true
        }
    }

    private fun sameOrigin(candidate: URI, appUri: URI): Boolean {
        val candidateScheme = candidate.scheme?.lowercase(Locale.ROOT)
        val appScheme = appUri.scheme?.lowercase(Locale.ROOT)

        return candidateScheme == appScheme &&
            candidate.host?.equals(appUri.host, ignoreCase = true) == true &&
            effectivePort(candidate) == effectivePort(appUri)
    }

    private fun effectivePort(uri: URI): Int {
        if (uri.port != -1) return uri.port

        return when (uri.scheme?.lowercase(Locale.ROOT)) {
            "http" -> 80
            "https" -> 443
            else -> -1
        }
    }
}
