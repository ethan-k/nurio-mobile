package com.nurio.study.android.microphone

import android.webkit.PermissionRequest
import dev.hotwire.core.turbo.session.Session
import dev.hotwire.core.turbo.webview.HotwireWebChromeClient
import java.util.Collections
import java.util.IdentityHashMap

class StudyWebChromeClient(
    session: Session,
    microphonePermissionHost: MicPermissionHost,
    trustedBaseUrl: String,
    currentLocation: () -> String?
) : HotwireWebChromeClient(session) {
    private val microphonePermissionCoordinator = AiPracticeMicrophonePermissionCoordinator(
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

internal class AiPracticeMicrophonePermissionCoordinator(
    private val microphonePermissionHost: MicPermissionHost,
    private val trustedBaseUrl: String,
    private val currentLocation: () -> String?,
    private val audioCaptureResource: String
) {
    private val pendingRequests = Collections.newSetFromMap(
        IdentityHashMap<Any, Boolean>()
    )

    fun handle(
        requestKey: Any,
        origin: String?,
        requestedResources: Array<out String>,
        grant: (Array<String>) -> Unit,
        deny: () -> Unit
    ) {
        val audioResources = AiPracticeNativePolicy.grantableAudioResources(
            requestedResources,
            audioCaptureResource
        )
        if (audioResources.isEmpty() || !isTrustedRequest(origin)) {
            deny()
            return
        }

        if (!pendingRequests.add(requestKey)) return
        microphonePermissionHost.requestMicrophonePermission { osPermissionGranted ->
            if (!pendingRequests.remove(requestKey)) return@requestMicrophonePermission

            if (osPermissionGranted && isTrustedRequest(origin)) {
                grant(audioResources)
            } else {
                deny()
            }
        }
    }

    fun cancel(requestKey: Any) {
        pendingRequests.remove(requestKey)
    }

    private fun isTrustedRequest(origin: String?): Boolean {
        return AiPracticeNativePolicy.isTrustedMicrophoneRequest(
            origin = origin,
            currentLocation = currentLocation(),
            trustedBaseUrl = trustedBaseUrl
        )
    }
}
