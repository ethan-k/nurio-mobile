package com.nurio.study.android.aitutor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AiTutorCallRequestTest {
    @Test
    fun `relative bridge paths resolve against the app base URL`() {
        val request = AiTutorCallRequest.resolve(
            joinUrl = "/practice/7/tutor_join",
            endUrl = "/practice/7/tutor_end",
            reviewUrl = "/practice/7/review",
            topic = "  Ordering coffee ",
            csrfToken = "csrf-123",
            baseUrl = BASE_URL
        )

        assertEquals(callRequest(), request)
    }

    @Test
    fun `URLs on another origin or scheme are rejected`() {
        listOf(
            "https://evil.example/practice/7/tutor_join",
            "http://study.nurio.kr/practice/7/tutor_join",
            "https://study.nurio.kr:8443/practice/7/tutor_join",
            "https://user@study.nurio.kr/practice/7/tutor_join",
            "//evil.example/practice"
        ).forEach { joinUrl ->
            assertNull(
                joinUrl,
                AiTutorCallRequest.resolve(joinUrl, "/e", "/r", "t", "c", BASE_URL)
            )
        }
    }

    @Test
    fun `missing URLs are rejected`() {
        assertNull(AiTutorCallRequest.resolve("/j", null, "/r", "t", "c", BASE_URL))
        assertNull(AiTutorCallRequest.resolve("/j", "/e", " ", "t", "c", BASE_URL))
    }

    @Test
    fun `countdown rounds up to whole seconds and never goes negative`() {
        assertEquals("10:00", AiTutorCountdown.format(600_000))
        assertEquals("0:01", AiTutorCountdown.format(1))
        assertEquals("0:00", AiTutorCountdown.format(-5_000))
    }
}
