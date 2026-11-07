package com.nurio.android.microphone

import android.webkit.PermissionRequest
import com.nurio.android.webview.PaymentWebChromeClient
import dev.hotwire.core.turbo.session.Session

/** Payment-aware chrome client that also answers First Spark translator microphone requests. */
class MicrophoneWebChromeClient(
    session: Session,
    microphonePermissionHost: MicPermissionHost,
    trustedBaseUrl: String,
    currentLocation: () -> String?
) : PaymentWebChromeClient(session) {
    private val microphonePermissionCoordinator = MicrophonePermissionCoordinator(
        microphonePermissionHost = microphonePermissionHost,
        trustedBaseUrl = trustedBaseUrl,
        currentLocation = currentLocation,
        audioCaptureResource = PermissionRequest.RESOURCE_AUDIO_CAPTURE
    )

    override fun onPermissionRequest(request: PermissionRequest) {
        microphonePermissionCoordinator.handle(
            requestKey = request,
            origin = request.origin?.toString(),
            requestedResources = request.resources,
            grant = { resources -> request.grant(resources) },
            deny = request::deny
        )
    }

    override fun onPermissionRequestCanceled(request: PermissionRequest) {
        microphonePermissionCoordinator.cancel(request)
        super.onPermissionRequestCanceled(request)
    }
}
