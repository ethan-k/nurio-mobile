package com.nurio.android.capture

import com.nurio.android.LocalePath
import java.net.URI

internal object WebCapturePolicy {
    fun isTrustedRequest(
        origin: String?,
        currentLocation: String?,
        trustedBaseUrl: String,
        allowedPath: Regex
    ): Boolean {
        val requestedOrigin = origin?.let(::normalizedHttpsOrigin) ?: return false
        val trustedOrigin = normalizedHttpsOrigin(trustedBaseUrl) ?: return false
        val currentOrigin = currentLocation?.let(::normalizedHttpsOrigin) ?: return false

        return requestedOrigin == trustedOrigin &&
            currentOrigin == trustedOrigin &&
            runCatching { URI(currentLocation).rawPath }.getOrNull()
                ?.let(LocalePath::strip)?.matches(allowedPath) == true
    }

    fun grantableResources(
        requestedResources: Array<out String>,
        captureResource: String
    ): Array<String> {
        if (requestedResources.isEmpty() || requestedResources.any { it != captureResource }) {
            return emptyArray()
        }

        return arrayOf(captureResource)
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
