package com.nurio.android.microphone

import java.util.Collections
import java.util.IdentityHashMap

/**
 * Answers WebView capture requests: denies anything the policy rejects without prompting, and
 * re-checks the policy after the OS prompt in case the page navigated away meanwhile.
 */
internal class MicrophonePermissionCoordinator(
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
        val audioResources = MicrophoneCapturePolicy.grantableAudioResources(
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
        return MicrophoneCapturePolicy.isTrustedMicrophoneRequest(
            origin = origin,
            currentLocation = currentLocation(),
            trustedBaseUrl = trustedBaseUrl
        )
    }
}
