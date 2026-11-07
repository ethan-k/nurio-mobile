package com.nurio.android.microphone

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MicrophonePermissionCoordinatorTest {
    private val baseUrl = "https://nurio.kr"
    private val translator = "$baseUrl/events/42/first_spark/translator"
    private val audioResource = "android.webkit.resource.AUDIO_CAPTURE"
    private val videoResource = "android.webkit.resource.VIDEO_CAPTURE"

    @Test
    fun `grants an audio-only translator request after the OS grant`() {
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { translator }

        coordinator.handle(Any(), baseUrl, arrayOf(audioResource), recorder::grant, recorder::deny)

        assertEquals(1, permissionHost.requestCount)
        assertTrue(recorder.grantedResources.isEmpty())

        permissionHost.resolve(granted = true)

        assertArrayEquals(arrayOf(audioResource), recorder.grantedResources.single())
        assertEquals(0, recorder.denyCount)
    }

    @Test
    fun `denies other pages before asking the OS`() {
        listOf(
            "$baseUrl/events/42",
            "$baseUrl/events/42/first_spark",
            "https://evil.example/events/42/first_spark/translator"
        ).forEach { currentLocation ->
            val permissionHost = FakeMicPermissionHost()
            val recorder = PermissionDecisionRecorder()
            val coordinator = coordinator(permissionHost) { currentLocation }

            coordinator.handle(Any(), baseUrl, arrayOf(audioResource), recorder::grant, recorder::deny)

            assertEquals(currentLocation, 0, permissionHost.requestCount)
            assertEquals(currentLocation, 1, recorder.denyCount)
        }
    }

    @Test
    fun `denies camera or mixed resources before asking the OS`() {
        listOf(arrayOf(videoResource), arrayOf(audioResource, videoResource)).forEach { resources ->
            val permissionHost = FakeMicPermissionHost()
            val recorder = PermissionDecisionRecorder()
            val coordinator = coordinator(permissionHost) { translator }

            coordinator.handle(Any(), baseUrl, resources, recorder::grant, recorder::deny)

            assertEquals(0, permissionHost.requestCount)
            assertEquals(1, recorder.denyCount)
            assertTrue(recorder.grantedResources.isEmpty())
        }
    }

    @Test
    fun `denies when the OS permission is refused`() {
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { translator }

        coordinator.handle(Any(), baseUrl, arrayOf(audioResource), recorder::grant, recorder::deny)
        permissionHost.resolve(granted = false)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(1, recorder.denyCount)
    }

    @Test
    fun `denies when navigation leaves the translator during the OS prompt`() {
        var currentLocation = translator
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { currentLocation }

        coordinator.handle(Any(), baseUrl, arrayOf(audioResource), recorder::grant, recorder::deny)
        currentLocation = "$baseUrl/events/42"
        permissionHost.resolve(granted = true)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(1, recorder.denyCount)
    }

    @Test
    fun `canceled web request ignores a later OS permission result`() {
        val requestKey = Any()
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { translator }

        coordinator.handle(requestKey, baseUrl, arrayOf(audioResource), recorder::grant, recorder::deny)
        coordinator.cancel(requestKey)
        permissionHost.resolve(granted = true)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(0, recorder.denyCount)
    }

    private fun coordinator(
        permissionHost: MicPermissionHost,
        currentLocation: () -> String?
    ) = MicrophonePermissionCoordinator(
        microphonePermissionHost = permissionHost,
        trustedBaseUrl = baseUrl,
        currentLocation = currentLocation,
        audioCaptureResource = audioResource
    )

    private class FakeMicPermissionHost : MicPermissionHost {
        var requestCount = 0
            private set
        private var callback: ((Boolean) -> Unit)? = null

        override fun requestMicrophonePermission(callback: (Boolean) -> Unit) {
            requestCount += 1
            this.callback = callback
        }

        fun resolve(granted: Boolean) {
            val pendingCallback = callback ?: error("No microphone permission request is pending")
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
