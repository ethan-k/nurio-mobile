package com.nurio.study.android.microphone

interface MicPermissionHost {
    fun requestMicrophonePermission(callback: (Boolean) -> Unit)
}
