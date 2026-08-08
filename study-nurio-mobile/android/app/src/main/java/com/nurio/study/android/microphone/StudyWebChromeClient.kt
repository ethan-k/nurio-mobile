package com.nurio.study.android.microphone

import android.webkit.PermissionRequest
import dev.hotwire.core.turbo.session.Session
import dev.hotwire.core.turbo.webview.HotwireWebChromeClient
import java.util.Collections
import java.util.IdentityHashMap

class StudyWebChromeClient(
    session: Session,
    private val microphonePermissionHost: MicPermissionHost,
    private val trustedBaseUrl: String
) : HotwireWebChromeClient(session) {
    private val pendingRequests = Collections.newSetFromMap(
        IdentityHashMap<PermissionRequest, Boolean>()
    )

    override fun onPermissionRequest(request: PermissionRequest) {
        val audioResources = AiPracticeNativePolicy.grantableAudioResources(
            request.resources,
            PermissionRequest.RESOURCE_AUDIO_CAPTURE
        )
        if (audioResources.isEmpty() || !AiPracticeNativePolicy.isTrustedMicrophoneRequest(
                request.origin?.toString(),
                trustedBaseUrl
            )
        ) {
            request.deny()
            return
        }

        if (!pendingRequests.add(request)) return
        microphonePermissionHost.requestMicrophonePermission { granted ->
            if (!pendingRequests.remove(request)) return@requestMicrophonePermission

            if (granted) {
                request.grant(audioResources)
            } else {
                request.deny()
            }
        }
    }

    override fun onPermissionRequestCanceled(request: PermissionRequest) {
        pendingRequests.remove(request)
        super.onPermissionRequestCanceled(request)
    }
}
