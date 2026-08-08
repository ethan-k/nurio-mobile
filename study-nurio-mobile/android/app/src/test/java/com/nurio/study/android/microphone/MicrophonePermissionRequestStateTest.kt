package com.nurio.study.android.microphone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MicrophonePermissionRequestStateTest {
    @Test
    fun `missing OS grant always launches a runtime request`() {
        val state = MicrophonePermissionRequestState()
        val results = mutableListOf<Boolean>()

        val action = state.request(permissionGranted = false, callback = results::add)

        assertEquals(MicrophonePermissionRequestAction.LAUNCH_RUNTIME_REQUEST, action)
        assertTrue(results.isEmpty())
    }

    @Test
    fun `granted OS permission completes immediately without a runtime request`() {
        val state = MicrophonePermissionRequestState()
        val results = mutableListOf<Boolean>()

        val action = state.request(permissionGranted = true, callback = results::add)

        assertEquals(MicrophonePermissionRequestAction.COMPLETE_GRANTED, action)
        assertEquals(listOf(true), results)
        assertNull(state.complete(granted = true, shouldShowRequestPermissionRationale = false))
    }

    @Test
    fun `concurrent callers share one request and receive its result exactly once`() {
        val state = MicrophonePermissionRequestState()
        val firstResults = mutableListOf<Boolean>()
        val secondResults = mutableListOf<Boolean>()

        assertEquals(
            MicrophonePermissionRequestAction.LAUNCH_RUNTIME_REQUEST,
            state.request(permissionGranted = false, callback = firstResults::add)
        )
        assertEquals(
            MicrophonePermissionRequestAction.AWAIT_RUNTIME_RESULT,
            state.request(permissionGranted = false, callback = secondResults::add)
        )

        val result = state.complete(
            granted = false,
            shouldShowRequestPermissionRationale = true
        )

        assertFalse(result!!.granted)
        assertFalse(result.showSettingsRecovery)
        assertEquals(listOf(false), firstResults)
        assertEquals(listOf(false), secondResults)

        assertNull(
            state.complete(
                granted = false,
                shouldShowRequestPermissionRationale = false
            )
        )
        assertEquals(listOf(false), firstResults)
        assertEquals(listOf(false), secondResults)
    }

    @Test
    fun `settings recovery follows only a completed non-requestable denial`() {
        val state = MicrophonePermissionRequestState()

        assertNull(
            state.complete(
                granted = false,
                shouldShowRequestPermissionRationale = false
            )
        )

        state.request(permissionGranted = false) { }
        val requestableDenial = state.complete(
            granted = false,
            shouldShowRequestPermissionRationale = true
        )
        assertFalse(requestableDenial!!.showSettingsRecovery)

        state.request(permissionGranted = false) { }
        val nonRequestableDenial = state.complete(
            granted = false,
            shouldShowRequestPermissionRationale = false
        )
        assertTrue(nonRequestableDenial!!.showSettingsRecovery)

        state.request(permissionGranted = false) { }
        val grant = state.complete(
            granted = true,
            shouldShowRequestPermissionRationale = false
        )
        assertFalse(grant!!.showSettingsRecovery)
    }

    @Test
    fun `destroyed lifecycle drops callers and ignores a stale result`() {
        val state = MicrophonePermissionRequestState()
        var callbackCount = 0

        state.request(permissionGranted = false) { callbackCount += 1 }
        state.cancel()

        assertNull(
            state.complete(
                granted = false,
                shouldShowRequestPermissionRationale = false
            )
        )
        assertEquals(0, callbackCount)
        assertEquals(
            MicrophonePermissionRequestAction.LAUNCH_RUNTIME_REQUEST,
            state.request(permissionGranted = false) { callbackCount += 1 }
        )
    }
}
