package com.nurio.android.camera

import com.nurio.android.capture.WebCapturePolicy

/** Allows camera capture on the Human Bingo confirmation page on the configured HTTPS origin. */
internal object CameraCapturePolicy {
    private val allowedPath = Regex("^/events/\\d+/human_bingo/confirm/?$")

    fun isTrustedCameraRequest(
        origin: String?,
        currentLocation: String?,
        trustedBaseUrl: String
    ): Boolean = WebCapturePolicy.isTrustedRequest(origin, currentLocation, trustedBaseUrl, allowedPath)
}
