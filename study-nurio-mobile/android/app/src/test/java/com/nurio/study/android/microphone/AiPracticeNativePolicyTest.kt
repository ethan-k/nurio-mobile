package com.nurio.study.android.microphone

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiPracticeNativePolicyTest {
    private val baseUrl = "https://study.nurio.kr"
    private val audioResource = "android.webkit.resource.AUDIO_CAPTURE"

    @Test
    fun `recognizes only numeric AI practice session locations`() {
        assertTrue(AiPracticeNativePolicy.isSessionLocation("https://study.nurio.kr/practice/42"))
        assertTrue(AiPracticeNativePolicy.isSessionLocation("https://study.nurio.kr/practice/42?lang=ko"))

        listOf(
            "https://study.nurio.kr/practice",
            "https://study.nurio.kr/practice/new",
            "https://study.nurio.kr/practice/42/review",
            "not a url"
        ).forEach { location ->
            assertFalse(location, AiPracticeNativePolicy.isSessionLocation(location))
        }
    }

    @Test
    fun `trusts microphone capture only from the configured HTTPS origin`() {
        assertTrue(AiPracticeNativePolicy.isTrustedMicrophoneRequest(baseUrl, baseUrl))
        assertTrue(
            AiPracticeNativePolicy.isTrustedMicrophoneRequest(
                "https://STUDY.NURIO.KR:443",
                baseUrl
            )
        )

        listOf(
            "http://study.nurio.kr",
            "https://evil.example",
            "https://study.nurio.kr:8443",
            "https://attacker@study.nurio.kr"
        ).forEach { origin ->
            assertFalse(origin, AiPracticeNativePolicy.isTrustedMicrophoneRequest(origin, baseUrl))
        }
    }

    @Test
    fun `grants audio capture without granting other requested resources`() {
        assertArrayEquals(
            arrayOf(audioResource),
            AiPracticeNativePolicy.grantableAudioResources(
                arrayOf(audioResource, "android.webkit.resource.VIDEO_CAPTURE", audioResource),
                audioResource
            )
        )
        assertTrue(
            AiPracticeNativePolicy.grantableAudioResources(
                arrayOf("android.webkit.resource.VIDEO_CAPTURE"),
                audioResource
            ).isEmpty()
        )
    }
}
