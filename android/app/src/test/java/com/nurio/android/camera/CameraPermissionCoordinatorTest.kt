package com.nurio.android.camera

import com.nurio.android.capture.WebCapturePermissionCoordinator
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraPermissionCoordinatorTest {
    private val baseUrl = "https://nurio.kr"
    private val confirmation = "$baseUrl/events/42/human_bingo/confirm"
    private val audioResource = "android.webkit.resource.AUDIO_CAPTURE"
    private val videoResource = "android.webkit.resource.VIDEO_CAPTURE"

    @Test
    fun `grants a video-only Human Bingo request after the OS grant`() {
        val permissionHost = FakeCameraPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { confirmation }

        coordinator.handle(Any(), baseUrl, arrayOf(videoResource), recorder::grant, recorder::deny)

        assertEquals(1, permissionHost.requestCount)
        assertTrue(recorder.grantedResources.isEmpty())

        permissionHost.resolve(granted = true)

        assertArrayEquals(arrayOf(videoResource), recorder.grantedResources.single())
        assertEquals(0, recorder.denyCount)
    }

    @Test
    fun `denies other pages before asking the OS`() {
        listOf(
            "$baseUrl/events/42",
            "$baseUrl/events/42/human_bingo",
            "https://evil.example/events/42/human_bingo/confirm"
        ).forEach { currentLocation ->
            val permissionHost = FakeCameraPermissionHost()
            val recorder = PermissionDecisionRecorder()
            val coordinator = coordinator(permissionHost) { currentLocation }

            coordinator.handle(Any(), baseUrl, arrayOf(videoResource), recorder::grant, recorder::deny)

            assertEquals(currentLocation, 0, permissionHost.requestCount)
            assertEquals(currentLocation, 1, recorder.denyCount)
        }
    }

    @Test
    fun `denies audio or mixed resources before asking the OS`() {
        listOf(arrayOf(audioResource), arrayOf(audioResource, videoResource)).forEach { resources ->
            val permissionHost = FakeCameraPermissionHost()
            val recorder = PermissionDecisionRecorder()
            val coordinator = coordinator(permissionHost) { confirmation }

            coordinator.handle(Any(), baseUrl, resources, recorder::grant, recorder::deny)

            assertEquals(0, permissionHost.requestCount)
            assertEquals(1, recorder.denyCount)
            assertTrue(recorder.grantedResources.isEmpty())
        }
    }

    @Test
    fun `denies when the OS permission is refused`() {
        val permissionHost = FakeCameraPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { confirmation }

        coordinator.handle(Any(), baseUrl, arrayOf(videoResource), recorder::grant, recorder::deny)
        permissionHost.resolve(granted = false)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(1, recorder.denyCount)
    }

    @Test
    fun `denies when navigation leaves the confirmation during the OS prompt`() {
        var currentLocation = confirmation
        val permissionHost = FakeCameraPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { currentLocation }

        coordinator.handle(Any(), baseUrl, arrayOf(videoResource), recorder::grant, recorder::deny)
        currentLocation = "$baseUrl/events/42"
        permissionHost.resolve(granted = true)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(1, recorder.denyCount)
    }

    @Test
    fun `canceled web request ignores a later OS permission result`() {
        val requestKey = Any()
        val permissionHost = FakeCameraPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { confirmation }

        coordinator.handle(requestKey, baseUrl, arrayOf(videoResource), recorder::grant, recorder::deny)
        coordinator.cancel(requestKey)
        permissionHost.resolve(granted = true)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(0, recorder.denyCount)
    }

    private fun coordinator(
        permissionHost: CameraPermissionHost,
        currentLocation: () -> String?
    ) = WebCapturePermissionCoordinator(
        captureResource = videoResource,
        isTrustedRequest = { origin ->
            CameraCapturePolicy.isTrustedCameraRequest(origin, currentLocation(), baseUrl)
        },
        requestPermission = permissionHost::requestCameraPermission
    )

    private class FakeCameraPermissionHost : CameraPermissionHost {
        var requestCount = 0
            private set
        private var callback: ((Boolean) -> Unit)? = null

        override fun requestCameraPermission(callback: (Boolean) -> Unit) {
            requestCount += 1
            this.callback = callback
        }

        fun resolve(granted: Boolean) {
            val pendingCallback = callback ?: error("No camera permission request is pending")
            callback = null
            pendingCallback(granted)
        }
    }

    private class PermissionDecisionRecorder {
        val grantedResources = mutableListOf<Array<String>>()
        var denyCount = 0
            private set

        fun grant(resources: Array<String>) {
            grantedResources += resources
        }

        fun deny() {
            denyCount += 1
        }
    }
}
