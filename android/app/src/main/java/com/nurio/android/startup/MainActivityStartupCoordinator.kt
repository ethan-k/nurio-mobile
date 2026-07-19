package com.nurio.android.startup

internal class MainActivityStartupCoordinator(
    private val bootstrapLocale: () -> Unit,
    private val initializeNavigator: () -> Unit,
    private val route: (String) -> Unit,
    private val logFailure: (Exception) -> Unit,
) {
    private var started = false
    private var navigatorReady = false
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
        if (navigatorReady) {
            route(url)
        } else {
            pendingRouteUrl = url
        }
    }

    fun onNavigatorReady() {
        navigatorReady = true

        val routeUrl = pendingRouteUrl ?: return
        pendingRouteUrl = null
        route(routeUrl)
    }
}
