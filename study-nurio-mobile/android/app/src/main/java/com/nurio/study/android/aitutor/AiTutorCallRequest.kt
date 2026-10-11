package com.nurio.study.android.aitutor

import java.net.URI

/**
 * One class-review call as announced by the `ai-tutor-call` bridge component.
 * Every URL is absolute and same-origin with the app base URL, so session cookies
 * are never sent anywhere else.
 */
data class AiTutorCallRequest(
    val joinUrl: String,
    val endUrl: String,
    val reviewUrl: String,
    val topic: String,
    val csrfToken: String
) {
    companion object {
        fun resolve(
            joinUrl: String?,
            endUrl: String?,
            reviewUrl: String?,
            topic: String?,
            csrfToken: String?,
            baseUrl: String
        ): AiTutorCallRequest? {
            return AiTutorCallRequest(
                joinUrl = AiTutorUrls.resolveSameOrigin(joinUrl, baseUrl) ?: return null,
                endUrl = AiTutorUrls.resolveSameOrigin(endUrl, baseUrl) ?: return null,
                reviewUrl = AiTutorUrls.resolveSameOrigin(reviewUrl, baseUrl) ?: return null,
                topic = topic.orEmpty().trim(),
                csrfToken = csrfToken.orEmpty()
            )
        }
    }
}

internal object AiTutorUrls {
    fun resolveSameOrigin(candidate: String?, baseUrl: String): String? {
        if (candidate.isNullOrBlank()) return null

        val base = runCatching { URI(baseUrl) }.getOrNull() ?: return null
        val resolved = runCatching { base.resolve(candidate.trim()) }.getOrNull() ?: return null
        if (resolved.userInfo != null) return null
        if (!sameOrigin(base, resolved)) return null

        return resolved.toString()
    }

    private fun sameOrigin(base: URI, other: URI): Boolean {
        val scheme = base.scheme?.lowercase() ?: return false
        if (scheme != "https" && scheme != "http") return false
        if (other.scheme?.lowercase() != scheme) return false
        if (base.host.isNullOrBlank() || !base.host.equals(other.host, ignoreCase = true)) return false

        return effectivePort(base) == effectivePort(other)
    }

    private fun effectivePort(uri: URI): Int = when {
        uri.port != -1 -> uri.port
        uri.scheme.equals("https", ignoreCase = true) -> 443
        else -> 80
    }
}
