package com.nurio.android.startup

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class MainActivityStartupCoordinatorTest {
    @Test
    fun `locale bootstrap runs before navigator initialization`() {
        val calls = mutableListOf<String>()
        val coordinator = coordinator(
            bootstrapLocale = { calls += "bootstrap" },
            initializeNavigator = { calls += "initialize" },
        )

        coordinator.start()

        assertEquals(listOf("bootstrap", "initialize"), calls)
    }

    @Test
    fun `navigator initialization runs exactly once when bootstrap throws an exception`() {
        val failure = IllegalStateException("cookie unavailable")
        val loggedFailures = mutableListOf<Exception>()
        var initializeCount = 0
        val coordinator = coordinator(
            bootstrapLocale = { throw failure },
            initializeNavigator = { initializeCount += 1 },
            logFailure = loggedFailures::add,
        )

        coordinator.start()
        coordinator.start()

        assertEquals(1, initializeCount)
        assertEquals(1, loggedFailures.size)
        assertSame(failure, loggedFailures.single())
    }

    @Test
    fun `route before navigator and host readiness is delivered once after both`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)

        coordinator.routeWhenReady("https://nurio.kr/events/1")
        assertTrue(routedUrls.isEmpty())

        coordinator.onNavigatorReady()
        assertTrue(routedUrls.isEmpty())

        coordinator.onHostResumed()
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()

        assertEquals(listOf("https://nurio.kr/events/1"), routedUrls)
    }

    @Test
    fun `route after navigator and host readiness is routed immediately`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()

        coordinator.routeWhenReady("https://nurio.kr/settings/tickets")

        assertEquals(listOf("https://nurio.kr/settings/tickets"), routedUrls)
    }

    @Test
    fun `latest pre-ready route wins while preserving one-slot semantics`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)

        coordinator.routeWhenReady("https://nurio.kr/events/first")
        coordinator.routeWhenReady("https://nurio.kr/events/latest")
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()

        assertEquals(listOf("https://nurio.kr/events/latest"), routedUrls)
    }

    @Test
    fun `host readiness before navigator readiness also drains the pending route`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)

        coordinator.routeWhenReady("https://nurio.kr/events/1")
        coordinator.onHostResumed()
        assertTrue(routedUrls.isEmpty())

        coordinator.onNavigatorReady()

        assertEquals(listOf("https://nurio.kr/events/1"), routedUrls)
    }

    @Test
    fun `route received while host is paused waits for the next resume`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()
        coordinator.onHostPaused()

        coordinator.routeWhenReady("https://nurio.kr/events/2")
        assertTrue(routedUrls.isEmpty())

        coordinator.onHostResumed()

        assertEquals(listOf("https://nurio.kr/events/2"), routedUrls)
    }

    private fun coordinator(
        bootstrapLocale: () -> Unit = {},
        initializeNavigator: () -> Unit = {},
        route: (String) -> Unit = {},
        logFailure: (Exception) -> Unit = {},
    ) = MainActivityStartupCoordinator(
        bootstrapLocale = bootstrapLocale,
        initializeNavigator = initializeNavigator,
        route = route,
        logFailure = logFailure,
    )
}
