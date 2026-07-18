package com.nurio.study.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationPayloadTest {
    private val baseUrl = "https://study.nurio.kr"

    @Test
    fun `resolves FCM path and url fields through destination policy`() {
        assertEquals(
            "https://study.nurio.kr/events/42",
            NotificationPayload.destination(mapOf("path" to "/events/42"), baseUrl)
        )
        assertEquals(
            "https://study.nurio.kr/messages",
            NotificationPayload.destination(
                mapOf("path" to "//evil.example/x", "url" to "/messages"),
                baseUrl
            )
        )
    }

    @Test
    fun `falls back to root when FCM fields are absent or blocked`() {
        assertEquals(baseUrl, NotificationPayload.destination(emptyMap(), baseUrl))
        assertEquals(
            baseUrl,
            NotificationPayload.destination(mapOf("path" to "/admin/events"), baseUrl)
        )
    }
}
