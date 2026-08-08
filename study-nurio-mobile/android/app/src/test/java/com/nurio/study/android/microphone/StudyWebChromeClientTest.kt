package com.nurio.study.android.microphone

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StudyWebChromeClientTest {
    private val baseUrl = "https://study.nurio.kr"
    private val audioResource = "android.webkit.resource.AUDIO_CAPTURE"
    private val videoResource = "android.webkit.resource.VIDEO_CAPTURE"

    @Test
    fun `grants an audio-only request on the active trusted practice session`() {
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { "$baseUrl/practice/42" }

        coordinator.handle(
            requestKey = Any(),
            origin = baseUrl,
            requestedResources = arrayOf(audioResource),
            grant = recorder::grant,
            deny = recorder::deny
        )

        assertEquals(1, permissionHost.requestCount)
        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(0, recorder.denyCount)

        permissionHost.resolve(granted = true)

        assertEquals(1, recorder.grantedResources.size)
        assertArrayEquals(arrayOf(audioResource), recorder.grantedResources.single())
        assertEquals(0, recorder.denyCount)
    }

    @Test
    fun `denies login dashboard review and foreign current pages before OS permission`() {
        listOf(
            "$baseUrl/sign_in",
            "$baseUrl/dashboard",
            "$baseUrl/practice/42/review",
            "https://evil.example/practice/42"
        ).forEach { currentLocation ->
            val permissionHost = FakeMicPermissionHost()
            val recorder = PermissionDecisionRecorder()
            val coordinator = coordinator(permissionHost) { currentLocation }

            coordinator.handle(
                requestKey = Any(),
                origin = baseUrl,
                requestedResources = arrayOf(audioResource),
                grant = recorder::grant,
                deny = recorder::deny
            )

            assertEquals(currentLocation, 0, permissionHost.requestCount)
            assertEquals(currentLocation, 1, recorder.denyCount)
            assertTrue(currentLocation, recorder.grantedResources.isEmpty())
        }
    }

    @Test
    fun `denies combined audio and video without requesting OS permission`() {
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { "$baseUrl/practice/42" }

        coordinator.handle(
            requestKey = Any(),
            origin = baseUrl,
            requestedResources = arrayOf(audioResource, videoResource),
            grant = recorder::grant,
            deny = recorder::deny
        )

        assertEquals(0, permissionHost.requestCount)
        assertEquals(1, recorder.denyCount)
        assertTrue(recorder.grantedResources.isEmpty())
    }

    @Test
    fun `denies when navigation leaves the practice session during OS permission`() {
        var currentLocation = "$baseUrl/practice/42"
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { currentLocation }

        coordinator.handle(
            requestKey = Any(),
            origin = baseUrl,
            requestedResources = arrayOf(audioResource),
            grant = recorder::grant,
            deny = recorder::deny
        )
        currentLocation = "$baseUrl/dashboard"
        permissionHost.resolve(granted = true)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(1, recorder.denyCount)
    }

    @Test
    fun `canceled web request ignores a later OS permission result`() {
        val requestKey = Any()
        val permissionHost = FakeMicPermissionHost()
        val recorder = PermissionDecisionRecorder()
        val coordinator = coordinator(permissionHost) { "$baseUrl/practice/42" }

        coordinator.handle(
            requestKey = requestKey,
            origin = baseUrl,
            requestedResources = arrayOf(audioResource),
            grant = recorder::grant,
            deny = recorder::deny
        )
        coordinator.cancel(requestKey)
        permissionHost.resolve(granted = true)

        assertTrue(recorder.grantedResources.isEmpty())
        assertEquals(0, recorder.denyCount)
    }

    private fun coordinator(
        permissionHost: MicPermissionHost,
        currentLocation: () -> String?
    ): AiPracticeMicrophonePermissionCoordinator {
        return AiPracticeMicrophonePermissionCoordinator(
            microphonePermissionHost = permissionHost,
            trustedBaseUrl = baseUrl,
            currentLocation = currentLocation,
            audioCaptureResource = audioResource
        )
    }

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
