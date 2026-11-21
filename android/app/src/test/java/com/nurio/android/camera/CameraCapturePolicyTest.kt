package com.nurio.android.camera

import com.nurio.android.capture.WebCapturePolicy
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraCapturePolicyTest {
    private val baseUrl = "https://nurio.kr"
    private val confirmation = "$baseUrl/events/42/human_bingo/confirm"
    private val audioResource = "android.webkit.resource.AUDIO_CAPTURE"
    private val videoResource = "android.webkit.resource.VIDEO_CAPTURE"

    @Test
    fun `trusts the Human Bingo confirmation page on the configured https origin`() {
        listOf(
            confirmation,
            "$confirmation/",
            "$confirmation?lang=ko",
            "https://NURIO.KR:443/events/7/human_bingo/confirm"
        ).forEach { currentLocation ->
            assertTrue(
                currentLocation,
                CameraCapturePolicy.isTrustedCameraRequest(baseUrl, currentLocation, baseUrl)
            )
        }
    }

    @Test
    fun `denies other pages on the trusted origin`() {
        listOf(
            "$baseUrl/",
            "$baseUrl/events/42",
            "$baseUrl/events/42/human_bingo",
            "$confirmation/scan",
            "${confirmation}ed",
            "$baseUrl/events/abc/human_bingo/confirm",
            "$baseUrl/events/%34%32/human_bingo/confirm",
            "$baseUrl/events/42/first_spark/translator",
            "not a url"
        ).forEach { currentLocation ->
            assertFalse(
                currentLocation,
                CameraCapturePolicy.isTrustedCameraRequest(baseUrl, currentLocation, baseUrl)
            )
        }
    }

    @Test
    fun `denies http, foreign, port-shifted and credentialed origins`() {
        listOf(
            "http://nurio.kr" to confirmation,
            "https://evil.example" to confirmation,
            "https://nurio.kr:8443" to confirmation,
            "https://attacker@nurio.kr" to confirmation,
            baseUrl to "http://nurio.kr/events/42/human_bingo/confirm",
            baseUrl to "https://evil.example/events/42/human_bingo/confirm",
            baseUrl to "https://study.nurio.kr/events/42/human_bingo/confirm"
        ).forEach { (origin, currentLocation) ->
            assertFalse(
                "$origin from $currentLocation",
                CameraCapturePolicy.isTrustedCameraRequest(origin, currentLocation, baseUrl)
            )
        }

        assertFalse(CameraCapturePolicy.isTrustedCameraRequest(null, confirmation, baseUrl))
        assertFalse(CameraCapturePolicy.isTrustedCameraRequest(baseUrl, null, baseUrl))
    }

    @Test
    fun `denies everything when the app itself runs on an http base url`() {
        val httpBase = "http://10.0.2.2:3000"

        assertFalse(
            CameraCapturePolicy.isTrustedCameraRequest(
                httpBase,
                "$httpBase/events/42/human_bingo/confirm",
                httpBase
            )
        )
    }

    @Test
    fun `grants video-only capture requests`() {
        assertArrayEquals(
            arrayOf(videoResource),
            WebCapturePolicy.grantableResources(
                arrayOf(videoResource, videoResource),
                videoResource
            )
        )
        assertTrue(
            WebCapturePolicy.grantableResources(arrayOf(audioResource), videoResource).isEmpty()
        )
        assertTrue(
            WebCapturePolicy.grantableResources(
                arrayOf(audioResource, videoResource),
                videoResource
            ).isEmpty()
        )
        assertTrue(WebCapturePolicy.grantableResources(emptyArray(), videoResource).isEmpty())
    }
}
