package com.nurio.android.localization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class LocaleCookieBootstrapperTest {
    @Test
    fun `missing authoritative locale cookies writes device locale hint and flushes exactly once`() {
        val store = FakeLocaleCookieStore(cookies = "session=active")

        LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
            baseUrl = "https://nurio.kr",
            languageIdentifiers = listOf("ko-KR", "en-US"),
        )

        assertEquals(
            listOf("https://nurio.kr" to "device_locale=ko; Path=/; Max-Age=31536000; SameSite=Lax; Secure"),
            store.writes,
        )
        assertEquals(1, store.flushCount)
    }

    @Test
    fun `any existing exact locale cookie is authoritative`() {
        listOf("locale=en", "locale=ko", "locale=", "locale=unsupported").forEach { cookies ->
            val store = FakeLocaleCookieStore(cookies = cookies)

            LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
                baseUrl = "https://nurio.kr",
                languageIdentifiers = listOf("ko-KR"),
            )

            assertTrue("Expected no write for $cookies", store.writes.isEmpty())
            assertEquals("Expected no flush for $cookies", 0, store.flushCount)
        }
    }

    @Test
    fun `any existing exact device locale cookie is authoritative`() {
        listOf(
            "device_locale=en",
            "device_locale=ko",
            "device_locale=",
            "device_locale=unsupported",
        ).forEach { cookies ->
            val store = FakeLocaleCookieStore(cookies = cookies)

            LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
                baseUrl = "https://nurio.kr",
                languageIdentifiers = listOf("ko-KR"),
            )

            assertTrue("Expected no write for $cookies", store.writes.isEmpty())
            assertEquals("Expected no flush for $cookies", 0, store.flushCount)
        }
    }

    @Test
    fun `similarly named differently cased or malformed cookies are not authoritative`() {
        listOf(
            "preferred_locale=ko",
            "locale_hint=en",
            "Locale=ko",
            "locale",
            "preferred_device_locale=ko",
            "device_locale_hint=en",
            "Device_locale=ko",
            "DEVICE_LOCALE=en",
            "device_locale",
        ).forEach { cookies ->
            val store = FakeLocaleCookieStore(cookies = cookies)

            LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
                baseUrl = "https://nurio.kr",
                languageIdentifiers = listOf("ko-KR"),
            )

            assertEquals("Expected one write for $cookies", 1, store.writes.size)
            assertEquals("Expected one flush for $cookies", 1, store.flushCount)
        }
    }

    @Test
    fun `finds either exact lowercase authoritative cookie among whitespace separated entries`() {
        listOf(
            " session=active ;   locale = unsupported ; token=present ",
            " session=active ;   device_locale = unsupported ; token=present ",
        ).forEach { cookies ->
            val store = FakeLocaleCookieStore(cookies = cookies)

            LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
                baseUrl = "https://nurio.kr",
                languageIdentifiers = listOf("ko-KR"),
            )

            assertTrue("Expected no write for $cookies", store.writes.isEmpty())
            assertEquals("Expected no flush for $cookies", 0, store.flushCount)
        }
    }

    @Test
    fun `https cookie is host only secure and uses the resolved locale`() {
        val store = FakeLocaleCookieStore(cookies = null)

        LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
            baseUrl = "https://nurio.kr",
            languageIdentifiers = listOf("ja-JP", "en-GB", "ko-KR"),
        )

        val cookie = store.writes.single().second
        assertEquals(
            "device_locale=en; Path=/; Max-Age=31536000; SameSite=Lax; Secure",
            cookie,
        )
        assertFalse(cookie.contains("Domain="))
    }

    @Test
    fun `http cookie omits secure and domain attributes`() {
        val store = FakeLocaleCookieStore(cookies = null)

        LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
            baseUrl = "http://10.0.2.2:3000",
            languageIdentifiers = listOf("ko-KR"),
        )

        val cookie = store.writes.single().second
        assertEquals(
            "device_locale=ko; Path=/; Max-Age=31536000; SameSite=Lax",
            cookie,
        )
        assertFalse(cookie.contains("Domain="))
        assertFalse(cookie.contains("Secure"))
    }

    @Test
    fun `runtime failures are logged and absorbed so startup can continue`() {
        FailurePoint.values().forEach { failurePoint ->
            val failure = IllegalStateException("Failed at $failurePoint")
            val loggedFailures = mutableListOf<Exception>()
            val store = FakeLocaleCookieStore(
                cookies = null,
                failurePoint = failurePoint,
                failure = failure,
            )

            LocaleCookieBootstrapper(store, loggedFailures::add).bootstrap(
                baseUrl = "https://nurio.kr",
                languageIdentifiers = listOf("ko-KR"),
            )

            assertEquals("Expected one logged failure at $failurePoint", 1, loggedFailures.size)
            assertSame(failure, loggedFailures.single())
        }
    }

    @Test(expected = AssertionError::class)
    fun `fatal throwables are not absorbed`() {
        val store = object : LocaleCookieStore {
            override fun cookies(url: String): String? = throw AssertionError("fatal")

            override fun setCookie(url: String, value: String) = Unit

            override fun flush() = Unit
        }

        LocaleCookieBootstrapper(store, logFailure = {}).bootstrap(
            baseUrl = "https://nurio.kr",
            languageIdentifiers = listOf("ko-KR"),
        )
    }

    private enum class FailurePoint {
        READ,
        WRITE,
        FLUSH,
    }

    private class FakeLocaleCookieStore(
        private val cookies: String?,
        private val failurePoint: FailurePoint? = null,
        private val failure: RuntimeException = IllegalStateException("cookie failure"),
    ) : LocaleCookieStore {
        val writes = mutableListOf<Pair<String, String>>()
        var flushCount = 0
            private set

        override fun cookies(url: String): String? {
            if (failurePoint == FailurePoint.READ) throw failure
            return cookies
        }

        override fun setCookie(url: String, value: String) {
            if (failurePoint == FailurePoint.WRITE) throw failure
            writes += url to value
        }

        override fun flush() {
            if (failurePoint == FailurePoint.FLUSH) throw failure
            flushCount += 1
        }
    }
}
