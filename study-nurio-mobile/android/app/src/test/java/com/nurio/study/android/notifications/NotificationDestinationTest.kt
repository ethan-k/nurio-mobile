package com.nurio.study.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationDestinationTest {
    private val baseUrl = "https://study.nurio.kr"

    @Test
    fun `accepts safe relative paths and same origin urls`() {
        assertEquals(
            "https://study.nurio.kr/events/42?tab=details",
            NotificationDestination.resolve("/events/42?tab=details", null, baseUrl)
        )
        assertEquals(
            "https://study.nurio.kr/messages",
            NotificationDestination.resolve(null, "https://STUDY.NURIO.KR/messages", baseUrl)
        )
    }

    @Test
    fun `uses url when path is invalid and path when it is valid`() {
        assertEquals(
            "https://study.nurio.kr/messages",
            NotificationDestination.resolve("//evil.example/events", "/messages", baseUrl)
        )
        assertEquals(
            "https://study.nurio.kr/events/42",
            NotificationDestination.resolve("/events/42", "/messages", baseUrl)
        )
    }

    @Test
    fun `falls back to root for untrusted destinations`() {
        val rejected = listOf(
            "//evil.example/events",
            "http://study.nurio.kr/events",
            "https://evil.example/events",
            "https://attacker:secret@study.nurio.kr/events",
            "https://study.nurio.kr:8443/events",
            "/events/42#fragment",
            "/%61dmin/events",
            "/events/../admin",
            "/events/./details",
            "/admin/events",
            "/tutoring/sessions",
            "/tutors/42"
        )

        rejected.forEach { destination ->
            assertEquals(
                "$destination must fall back to Study root",
                baseUrl,
                NotificationDestination.resolve(destination, null, baseUrl)
            )
        }
    }

    @Test
    fun `falls back when configured base origin is invalid`() {
        val invalidBases = listOf(
            "http://study.nurio.kr",
            "https://attacker@study.nurio.kr",
            "https://study.nurio.kr:8443"
        )

        invalidBases.forEach { invalidBase ->
            assertEquals(
                invalidBase,
                NotificationDestination.resolve("/events/42", null, invalidBase)
            )
        }
    }
}
