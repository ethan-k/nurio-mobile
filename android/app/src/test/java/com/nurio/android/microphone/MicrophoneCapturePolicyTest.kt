package com.nurio.android.microphone

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MicrophoneCapturePolicyTest {
    private val baseUrl = "https://nurio.kr"
    private val translator = "$baseUrl/events/42/first_spark/translator"
    private val audioResource = "android.webkit.resource.AUDIO_CAPTURE"
    private val videoResource = "android.webkit.resource.VIDEO_CAPTURE"

    @Test
    fun `trusts the First Spark translator on the configured https origin`() {
        listOf(
            translator,
            "$translator/",
            "$translator?lang=ko",
            "https://NURIO.KR:443/events/7/first_spark/translator"
        ).forEach { currentLocation ->
            assertTrue(
                currentLocation,
                MicrophoneCapturePolicy.isTrustedMicrophoneRequest(baseUrl, currentLocation, baseUrl)
            )
        }
    }

    @Test
    fun `denies other pages on the trusted origin`() {
        listOf(
            "$baseUrl/",
            "$baseUrl/events/42",
            "$baseUrl/events/42/first_spark",
            "$baseUrl/events/42/first_spark/translator/turns",
            "$baseUrl/events/42/first_spark/translator/finish",
            "$baseUrl/events/abc/first_spark/translator",
            "$baseUrl/events/%34%32/first_spark/translator",
            "$baseUrl/practice/42",
            "not a url"
        ).forEach { currentLocation ->
            assertFalse(
                currentLocation,
                MicrophoneCapturePolicy.isTrustedMicrophoneRequest(baseUrl, currentLocation, baseUrl)
            )
        }
    }

    @Test
    fun `denies http, foreign, port-shifted and credentialed origins`() {
        listOf(
            "http://nurio.kr" to translator,
            "https://evil.example" to translator,
            "https://nurio.kr:8443" to translator,
            "https://attacker@nurio.kr" to translator,
            baseUrl to "http://nurio.kr/events/42/first_spark/translator",
            baseUrl to "https://evil.example/events/42/first_spark/translator",
            baseUrl to "https://study.nurio.kr/events/42/first_spark/translator"
        ).forEach { (origin, currentLocation) ->
            assertFalse(
                "$origin from $currentLocation",
                MicrophoneCapturePolicy.isTrustedMicrophoneRequest(origin, currentLocation, baseUrl)
            )
        }

        assertFalse(MicrophoneCapturePolicy.isTrustedMicrophoneRequest(null, translator, baseUrl))
        assertFalse(MicrophoneCapturePolicy.isTrustedMicrophoneRequest(baseUrl, null, baseUrl))
    }

    @Test
    fun `denies everything when the app itself runs on an http base url`() {
        val httpBase = "http://10.0.2.2:3000"

        assertFalse(
            MicrophoneCapturePolicy.isTrustedMicrophoneRequest(
                httpBase,
                "$httpBase/events/42/first_spark/translator",
                httpBase
            )
        )
    }

    @Test
    fun `grants only audio-only capture requests`() {
        assertArrayEquals(
            arrayOf(audioResource),
            MicrophoneCapturePolicy.grantableAudioResources(
                arrayOf(audioResource, audioResource),
                audioResource
            )
        )
        assertTrue(
            MicrophoneCapturePolicy.grantableAudioResources(arrayOf(videoResource), audioResource).isEmpty()
        )
        assertTrue(
            MicrophoneCapturePolicy.grantableAudioResources(
                arrayOf(audioResource, videoResource),
                audioResource
            ).isEmpty()
        )
        assertTrue(MicrophoneCapturePolicy.grantableAudioResources(emptyArray(), audioResource).isEmpty())
    }
}
