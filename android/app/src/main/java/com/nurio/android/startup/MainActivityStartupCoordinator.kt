package com.nurio.android.startup

internal class MainActivityStartupCoordinator(
    private val bootstrapLocale: () -> Unit,
    private val initializeNavigator: () -> Unit,
    private val route: (String) -> Unit,
    private val logFailure: (Exception) -> Unit,
    private val isDestinationReady: () -> Boolean,
    private val postNavigation: (() -> Unit) -> Unit,
) {
    private var started = false
    private var navigatorReady = false
    private var hostResumed = false
    private var destroyed = false
    private var drainPosted = false
    private var pendingRouteUrl: String? = null

    fun start() {
        if (started) return
        started = true

        try {
            bootstrapLocale()
        } catch (exception: Exception) {
            logFailure(exception)
        }

        initializeNavigator()
    }

    fun routeWhenReady(url: String) {
        if (destroyed) return
        pendingRouteUrl = url
        postPendingRouteDrain()
    }

    fun onNavigatorReady() {
        navigatorReady = true
        postPendingRouteDrain()
    }

    fun onHostResumed() {
        hostResumed = true
        postPendingRouteDrain()
    }

    fun onHostPaused() {
        hostResumed = false
    }

    fun onDestinationStateChanged() {
        postPendingRouteDrain()
    }

    fun onHostDestroyed() {
        destroyed = true
        pendingRouteUrl = null
    }

    private fun postPendingRouteDrain() {
        if (destroyed || drainPosted || pendingRouteUrl == null || !navigatorReady || !hostResumed) return

        // Hotwire's onNavigatorReady runs inside onAttachFragment, before the
        // destination initializes webDelegate in onCreate. Leave that transaction
        // before checking readiness or starting another navigation.
        drainPosted = true
        postNavigation {
            drainPosted = false
            drainPendingRouteIfReady()
        }
    }

    private fun drainPendingRouteIfReady() {
        if (destroyed || !navigatorReady || !hostResumed || !isDestinationReady()) return

        val routeUrl = pendingRouteUrl ?: return
        pendingRouteUrl = null
        route(routeUrl)
    }
}
