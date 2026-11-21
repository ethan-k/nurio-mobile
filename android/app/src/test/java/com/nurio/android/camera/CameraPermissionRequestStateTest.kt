package com.nurio.android.camera

import com.nurio.android.capture.CapturePermissionRequestAction
import com.nurio.android.capture.CapturePermissionRequestState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraPermissionRequestStateTest {
    @Test
    fun `camera and microphone requests complete independently`() {
        val cameraState = CapturePermissionRequestState()
        val microphoneState = CapturePermissionRequestState()
        val cameraResults = mutableListOf<Boolean>()
        val microphoneResults = mutableListOf<Boolean>()

        assertEquals(
            CapturePermissionRequestAction.LAUNCH_RUNTIME_REQUEST,
            cameraState.request(permissionGranted = false, callback = cameraResults::add)
        )
        assertEquals(
            CapturePermissionRequestAction.AWAIT_RUNTIME_RESULT,
            cameraState.request(permissionGranted = false, callback = cameraResults::add)
        )
        assertEquals(
            CapturePermissionRequestAction.LAUNCH_RUNTIME_REQUEST,
            microphoneState.request(permissionGranted = false, callback = microphoneResults::add)
        )

        val cameraDenial = cameraState.complete(
            granted = false,
            shouldShowRequestPermissionRationale = false
        )
        assertTrue(cameraDenial!!.showSettingsRecovery)
        assertEquals(listOf(false, false), cameraResults)
        assertTrue(microphoneResults.isEmpty())
        assertNull(cameraState.complete(granted = false, shouldShowRequestPermissionRationale = false))

        val microphoneGrant = microphoneState.complete(
            granted = true,
            shouldShowRequestPermissionRationale = false
        )
        assertFalse(microphoneGrant!!.showSettingsRecovery)
        assertEquals(listOf(true), microphoneResults)
        assertEquals(listOf(false, false), cameraResults)
    }
}
