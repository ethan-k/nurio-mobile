package com.nurio.android.localization

import org.junit.Assert.assertEquals
import org.junit.Test

class UiLocaleResolverTest {
    @Test
    fun `normalizes English language identifiers`() {
        listOf("en", "en-US", "EN_us").forEach { identifier ->
            assertEquals(
                "Expected $identifier to resolve to English",
                "en",
                UiLocaleResolver.resolve(listOf(identifier)),
            )
        }
    }

    @Test
    fun `normalizes Korean language identifiers`() {
        listOf("ko", "ko-KR", "ko_KR").forEach { identifier ->
            assertEquals(
                "Expected $identifier to resolve to Korean",
                "ko",
                UiLocaleResolver.resolve(listOf(identifier)),
            )
        }
    }

    @Test
    fun `selects the first supported language after unsupported languages`() {
        assertEquals(
            "ko",
            UiLocaleResolver.resolve(listOf("ja-JP", "ko-KR", "en-US")),
        )
    }

    @Test
    fun `keeps the ordered preference of supported languages`() {
        assertEquals(
            "en",
            UiLocaleResolver.resolve(listOf("en-US", "ko-KR")),
        )
    }

    @Test
    fun `skips malformed and unsupported entries before Korean`() {
        assertEquals(
            "ko",
            UiLocaleResolver.resolve(listOf(" ", "en-@", "fr-FR", " ko-KR ")),
        )
    }

    @Test
    fun `falls back to English when no supported language exists`() {
        assertEquals("en", UiLocaleResolver.resolve(emptyList()))
        assertEquals(
            "en",
            UiLocaleResolver.resolve(listOf("ja-JP", "fr-FR", "not_a_locale!!!")),
        )
    }
}
