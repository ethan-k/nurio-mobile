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
            "https://study.nurio.kr/practice/%34%32",
            "not a url"
        ).forEach { location ->
            assertFalse(location, AiPracticeNativePolicy.isSessionLocation(location))
        }
    }

    @Test
    fun `trusts microphone capture only on a configured-origin practice session`() {
        assertTrue(
            AiPracticeNativePolicy.isTrustedMicrophoneRequest(
                origin = baseUrl,
                currentLocation = "$baseUrl/practice/42?lang=ko",
                trustedBaseUrl = baseUrl
            )
        )
        assertTrue(
            AiPracticeNativePolicy.isTrustedMicrophoneRequest(
                origin = "https://STUDY.NURIO.KR:443",
                currentLocation = "https://STUDY.NURIO.KR:443/practice/42",
                trustedBaseUrl = baseUrl
            )
        )

        val rejectedRequests = listOf(
            baseUrl to "$baseUrl/sign_in",
            baseUrl to "$baseUrl/dashboard",
            baseUrl to "$baseUrl/practice/42/review",
            baseUrl to "https://evil.example/practice/42",
            "http://study.nurio.kr" to "$baseUrl/practice/42",
            "https://evil.example" to "$baseUrl/practice/42",
            "https://study.nurio.kr:8443" to "$baseUrl/practice/42",
            "https://attacker@study.nurio.kr" to "$baseUrl/practice/42"
        )
        rejectedRequests.forEach { (origin, currentLocation) ->
            assertFalse(
                "$origin from $currentLocation",
                AiPracticeNativePolicy.isTrustedMicrophoneRequest(
                    origin = origin,
                    currentLocation = currentLocation,
                    trustedBaseUrl = baseUrl
                )
            )
        }

        assertFalse(AiPracticeNativePolicy.isTrustedMicrophoneRequest(null, "$baseUrl/practice/42", baseUrl))
        assertFalse(AiPracticeNativePolicy.isTrustedMicrophoneRequest(baseUrl, null, baseUrl))
    }

    @Test
    fun `trusts microphone capture on the placement speaking page`() {
        listOf(
            "$baseUrl/placement/42/speaking",
            "$baseUrl/placement/42/speaking?lang=ko"
        ).forEach { currentLocation ->
            assertTrue(
                currentLocation,
                AiPracticeNativePolicy.isTrustedMicrophoneRequest(baseUrl, currentLocation, baseUrl)
            )
        }

        listOf(
            baseUrl to "$baseUrl/placement/42",
            baseUrl to "$baseUrl/placement/42/writing",
            baseUrl to "$baseUrl/placement/new",
            baseUrl to "$baseUrl/placement/abc/speaking",
            baseUrl to "https://evil.example/placement/42/speaking",
            "https://evil.example" to "$baseUrl/placement/42/speaking"
        ).forEach { (origin, currentLocation) ->
            assertFalse(
                "$origin from $currentLocation",
                AiPracticeNativePolicy.isTrustedMicrophoneRequest(origin, currentLocation, baseUrl)
            )
        }
    }

    @Test
    fun `placement speaking page is not an AI practice session`() {
        assertFalse(AiPracticeNativePolicy.isSessionLocation("$baseUrl/placement/42/speaking"))
    }

    @Test
    fun `grants only audio-only capture requests`() {
        assertArrayEquals(
            arrayOf(audioResource),
            AiPracticeNativePolicy.grantableAudioResources(
                arrayOf(audioResource, audioResource),
                audioResource
            )
        )
        assertTrue(
            AiPracticeNativePolicy.grantableAudioResources(
                arrayOf("android.webkit.resource.VIDEO_CAPTURE"),
                audioResource
            ).isEmpty()
        )
        assertTrue(
            AiPracticeNativePolicy.grantableAudioResources(
                arrayOf(audioResource, "android.webkit.resource.VIDEO_CAPTURE"),
                audioResource
            ).isEmpty()
        )
    }
}
