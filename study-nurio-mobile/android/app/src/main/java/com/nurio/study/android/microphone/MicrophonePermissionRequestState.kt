package com.nurio.study.android.microphone

internal enum class MicrophonePermissionRequestAction {
    COMPLETE_GRANTED,
    LAUNCH_RUNTIME_REQUEST,
    AWAIT_RUNTIME_RESULT
}

internal data class MicrophonePermissionResult(
    val granted: Boolean,
    val showSettingsRecovery: Boolean
)

/**
 * Keeps Android permission prompts and their callers in one exactly-once lifecycle.
 *
 * A persisted "requested before" marker cannot distinguish a restored or auto-reset grant from a
 * permanent denial. The only pre-request input is therefore the current OS grant. Settings recovery
 * is considered only after Android has returned a denial for a request launched by this lifecycle.
 */
internal class MicrophonePermissionRequestState {
    private val callbacks = mutableListOf<(Boolean) -> Unit>()
    private var runtimeRequestPending = false

    fun request(
        permissionGranted: Boolean,
        callback: (Boolean) -> Unit
    ): MicrophonePermissionRequestAction {
        if (permissionGranted) {
            callback(true)
            return MicrophonePermissionRequestAction.COMPLETE_GRANTED
        }

        callbacks += callback
        if (runtimeRequestPending) {
            return MicrophonePermissionRequestAction.AWAIT_RUNTIME_RESULT
        }

        runtimeRequestPending = true
        return MicrophonePermissionRequestAction.LAUNCH_RUNTIME_REQUEST
    }

    fun complete(
        granted: Boolean,
        shouldShowRequestPermissionRationale: Boolean
    ): MicrophonePermissionResult? {
        if (!runtimeRequestPending) return null

        runtimeRequestPending = false
        val pendingCallbacks = callbacks.toList()
        callbacks.clear()
        pendingCallbacks.forEach { callback -> callback(granted) }

        return MicrophonePermissionResult(
            granted = granted,
            showSettingsRecovery = !granted && !shouldShowRequestPermissionRationale
        )
    }

    fun cancel() {
        runtimeRequestPending = false
        callbacks.clear()
    }
}
