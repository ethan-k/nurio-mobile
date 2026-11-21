package com.nurio.android.capture

import java.util.Collections
import java.util.IdentityHashMap

/**
 * Answers WebView capture requests: denies anything the policy rejects without prompting, and
 * re-checks the policy after the OS prompt in case the page navigated away meanwhile.
 */
internal class WebCapturePermissionCoordinator(
    private val captureResource: String,
    private val isTrustedRequest: (String?) -> Boolean,
    private val requestPermission: ((Boolean) -> Unit) -> Unit
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
        val resources = WebCapturePolicy.grantableResources(
            requestedResources,
            captureResource
        )
        if (resources.isEmpty() || !isTrustedRequest(origin)) {
            deny()
            return
        }

        if (!pendingRequests.add(requestKey)) return
        requestPermission { osPermissionGranted ->
            if (!pendingRequests.remove(requestKey)) return@requestPermission

            if (osPermissionGranted && isTrustedRequest(origin)) {
                grant(resources)
            } else {
                deny()
            }
        }
    }

    fun cancel(requestKey: Any) {
        pendingRequests.remove(requestKey)
    }
}
