package com.nurio.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AppEnvironmentTest {
    @Test
    fun `cold start location uses the base URL root`() {
        assertEquals("https://nurio.kr/", AppEnvironment.coldStartLocation("https://nurio.kr"))
    }

    @Test
    fun `cold start location normalizes a trailing slash`() {
        assertEquals("https://nurio.kr/", AppEnvironment.coldStartLocation("https://nurio.kr/"))
    }
}
