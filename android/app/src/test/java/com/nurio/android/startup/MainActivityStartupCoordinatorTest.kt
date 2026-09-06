package com.nurio.android.startup

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class MainActivityStartupCoordinatorTest {
    private val postedNavigation = ArrayDeque<() -> Unit>()

    @Test
    fun `navigator attachment does not navigate inside the fragment attach callback`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)

        coordinator.routeWhenReady("https://nurio.kr/settings/tickets")
        coordinator.onHostResumed()
        coordinator.onNavigatorReady()

        // Hotwire calls onNavigatorReady from onAttachFragment, before the web
        // fragment initializes webDelegate in onCreate. Routing here crashes.
        assertTrue(routedUrls.isEmpty())
    }

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
        drainPostedNavigation()

        assertEquals(listOf("https://nurio.kr/events/1"), routedUrls)
    }

    @Test
    fun `route after navigator and host readiness is posted once`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()

        coordinator.routeWhenReady("https://nurio.kr/settings/tickets")
        assertTrue(routedUrls.isEmpty())
        drainPostedNavigation()

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
        drainPostedNavigation()

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
        drainPostedNavigation()

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
        drainPostedNavigation()

        assertEquals(listOf("https://nurio.kr/events/2"), routedUrls)
    }

    @Test
    fun `attached destination waits for its view to resume without losing the payment route`() {
        val routedUrls = mutableListOf<String>()
        var destinationReady = false
        val coordinator = coordinator(
            route = routedUrls::add,
            isDestinationReady = { destinationReady },
        )
        val paymentUrl = "https://nurio.kr/payments/portone/complete?paymentId=test-payment&native_recovery=1"
        coordinator.routeWhenReady(paymentUrl)
        coordinator.onHostResumed()
        coordinator.onNavigatorReady()
        drainPostedNavigation()
        assertTrue(routedUrls.isEmpty())

        destinationReady = true
        coordinator.onDestinationStateChanged()
        coordinator.onDestinationStateChanged()
        drainPostedNavigation()

        assertEquals(listOf(paymentUrl), routedUrls)
    }

    @Test
    fun `activity pausing before the posted route runs preserves it until resume`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()
        coordinator.routeWhenReady("https://nurio.kr/settings/tickets")
        coordinator.onHostPaused()
        drainPostedNavigation()
        assertTrue(routedUrls.isEmpty())

        coordinator.onHostResumed()
        drainPostedNavigation()

        assertEquals(listOf("https://nurio.kr/settings/tickets"), routedUrls)
    }

    @Test
    fun `destination readiness is checked when the posted route runs`() {
        val routedUrls = mutableListOf<String>()
        var destinationReady = true
        val coordinator = coordinator(
            route = routedUrls::add,
            isDestinationReady = { destinationReady },
        )
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()
        coordinator.routeWhenReady("https://nurio.kr/events/1")
        destinationReady = false
        drainPostedNavigation()
        assertTrue(routedUrls.isEmpty())

        coordinator.routeWhenReady("https://nurio.kr/events/2")
        destinationReady = true
        coordinator.onDestinationStateChanged()
        drainPostedNavigation()

        assertEquals(listOf("https://nurio.kr/events/2"), routedUrls)
    }

    @Test
    fun `destroyed activity never delivers a pending route or accepts a new route`() {
        val routedUrls = mutableListOf<String>()
        val coordinator = coordinator(route = routedUrls::add)
        coordinator.onNavigatorReady()
        coordinator.onHostResumed()
        coordinator.routeWhenReady("https://nurio.kr/events/1")
        coordinator.onHostDestroyed()
        drainPostedNavigation()

        coordinator.routeWhenReady("https://nurio.kr/events/2")
        coordinator.onHostResumed()
        coordinator.onDestinationStateChanged()
        drainPostedNavigation()

        assertTrue(routedUrls.isEmpty())
    }

    private fun drainPostedNavigation() {
        while (postedNavigation.isNotEmpty()) postedNavigation.removeFirst().invoke()
    }

    private fun coordinator(
        bootstrapLocale: () -> Unit = {},
        initializeNavigator: () -> Unit = {},
        route: (String) -> Unit = {},
        logFailure: (Exception) -> Unit = {},
        isDestinationReady: () -> Boolean = { true },
    ) = MainActivityStartupCoordinator(
        bootstrapLocale = bootstrapLocale,
        initializeNavigator = initializeNavigator,
        route = route,
        logFailure = logFailure,
        isDestinationReady = isDestinationReady,
        postNavigation = postedNavigation::addLast,
    )
}
