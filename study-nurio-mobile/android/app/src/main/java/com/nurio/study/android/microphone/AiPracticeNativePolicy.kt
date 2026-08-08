package com.nurio.study.android.microphone

import java.net.URI

internal object AiPracticeNativePolicy {
    private val sessionPath = Regex("^/practice/\\d+/?$")

    fun isSessionLocation(location: String): Boolean {
        return runCatching { URI(location).path }
            .getOrNull()
            ?.matches(sessionPath) == true
    }

    fun isTrustedMicrophoneRequest(origin: String?, trustedBaseUrl: String): Boolean {
        val requestedOrigin = origin?.let(::normalizedHttpsOrigin) ?: return false
        val trustedOrigin = normalizedHttpsOrigin(trustedBaseUrl) ?: return false
        return requestedOrigin == trustedOrigin
    }

    fun grantableAudioResources(
        requestedResources: Array<out String>,
        audioCaptureResource: String
    ): Array<String> {
        return requestedResources.filter { it == audioCaptureResource }.distinct().toTypedArray()
    }

    private fun normalizedHttpsOrigin(location: String): Origin? {
        val uri = runCatching { URI(location) }.getOrNull() ?: return null
        if (!uri.scheme.equals("https", ignoreCase = true)) return null
        if (uri.host.isNullOrBlank() || uri.userInfo != null) return null

        val port = when (uri.port) {
            -1, 443 -> 443
            else -> return null
        }
        return Origin(uri.host.lowercase(), port)
    }

    private data class Origin(val host: String, val port: Int)
}
