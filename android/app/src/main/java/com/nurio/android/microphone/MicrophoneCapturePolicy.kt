package com.nurio.android.microphone

import com.nurio.android.capture.WebCapturePolicy

/** Allows microphone capture on the First Spark table translator on the configured HTTPS origin. */
internal object MicrophoneCapturePolicy {
    private val allowedPath = Regex("^/events/\\d+/first_spark/translator/?$")

    fun isTrustedMicrophoneRequest(
        origin: String?,
        currentLocation: String?,
        trustedBaseUrl: String
    ): Boolean = WebCapturePolicy.isTrustedRequest(origin, currentLocation, trustedBaseUrl, allowedPath)
}
