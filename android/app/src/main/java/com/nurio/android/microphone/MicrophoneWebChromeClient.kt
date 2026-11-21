package com.nurio.android.microphone

import android.webkit.PermissionRequest
import com.nurio.android.camera.CameraCapturePolicy
import com.nurio.android.camera.CameraPermissionHost
import com.nurio.android.capture.WebCapturePermissionCoordinator
import com.nurio.android.webview.PaymentWebChromeClient
import dev.hotwire.core.turbo.session.Session

/** Payment-aware chrome client that handles microphone and camera requests from trusted pages. */
class MicrophoneWebChromeClient(
    session: Session,
    microphonePermissionHost: MicPermissionHost,
    trustedBaseUrl: String,
    currentLocation: () -> String?,
    cameraPermissionHost: CameraPermissionHost? = null
) : PaymentWebChromeClient(session) {
    private val microphonePermissionCoordinator = WebCapturePermissionCoordinator(
        captureResource = PermissionRequest.RESOURCE_AUDIO_CAPTURE,
        isTrustedRequest = { origin ->
            MicrophoneCapturePolicy.isTrustedMicrophoneRequest(origin, currentLocation(), trustedBaseUrl)
        },
        requestPermission = microphonePermissionHost::requestMicrophonePermission
    )
    private val cameraPermissionCoordinator = cameraPermissionHost?.let { host ->
        WebCapturePermissionCoordinator(
            captureResource = PermissionRequest.RESOURCE_VIDEO_CAPTURE,
            isTrustedRequest = { origin ->
                CameraCapturePolicy.isTrustedCameraRequest(origin, currentLocation(), trustedBaseUrl)
            },
            requestPermission = host::requestCameraPermission
        )
    }

    override fun onPermissionRequest(request: PermissionRequest) {
        val resources = request.resources
        val coordinator = when {
            PermissionRequest.RESOURCE_VIDEO_CAPTURE in resources -> cameraPermissionCoordinator
            PermissionRequest.RESOURCE_AUDIO_CAPTURE in resources -> microphonePermissionCoordinator
            else -> null
        }
        if (coordinator == null) {
            request.deny()
            return
        }

        coordinator.handle(
            requestKey = request,
            origin = request.origin?.toString(),
            requestedResources = resources,
            grant = { grantedResources -> request.grant(grantedResources) },
            deny = request::deny
        )
    }

    override fun onPermissionRequestCanceled(request: PermissionRequest) {
        microphonePermissionCoordinator.cancel(request)
        cameraPermissionCoordinator?.cancel(request)
        super.onPermissionRequestCanceled(request)
    }
}
