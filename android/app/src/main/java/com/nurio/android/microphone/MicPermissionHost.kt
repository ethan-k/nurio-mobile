package com.nurio.android.microphone

interface MicPermissionHost {
    fun requestMicrophonePermission(callback: (Boolean) -> Unit)
}
