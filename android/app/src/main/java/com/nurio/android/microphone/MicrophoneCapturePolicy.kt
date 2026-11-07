package com.nurio.android.microphone

import java.net.URI

/**
 * Decides which web pages may capture the microphone. Only the First Spark table translator on
 * the configured https origin qualifies; every other page, scheme, origin and resource is denied.
 */
internal object MicrophoneCapturePolicy {
    private val translatorPath = Regex("^/events/\\d+/first_spark/translator/?$")

    fun isTrustedMicrophoneRequest(
        origin: String?,
        currentLocation: String?,
        trustedBaseUrl: String
    ): Boolean {
        val requestedOrigin = origin?.let(::normalizedHttpsOrigin) ?: return false
        val trustedOrigin = normalizedHttpsOrigin(trustedBaseUrl) ?: return false
        val currentOrigin = currentLocation?.let(::normalizedHttpsOrigin) ?: return false

        return requestedOrigin == trustedOrigin &&
            currentOrigin == trustedOrigin &&
            isTranslatorLocation(currentLocation)
    }

    fun grantableAudioResources(
        requestedResources: Array<out String>,
        audioCaptureResource: String
    ): Array<String> {
        if (requestedResources.isEmpty() || requestedResources.any { it != audioCaptureResource }) {
            return emptyArray()
        }

        return arrayOf(audioCaptureResource)
    }

    private fun isTranslatorLocation(location: String): Boolean {
        return runCatching { URI(location).rawPath }
            .getOrNull()
            ?.matches(translatorPath) == true
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
