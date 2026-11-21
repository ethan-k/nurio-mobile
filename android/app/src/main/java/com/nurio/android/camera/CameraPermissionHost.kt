package com.nurio.android.camera

interface CameraPermissionHost {
    fun requestCameraPermission(callback: (Boolean) -> Unit)
}
