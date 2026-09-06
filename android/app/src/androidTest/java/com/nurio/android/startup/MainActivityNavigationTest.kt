package com.nurio.android.startup

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.nurio.android.BuildConfig
import com.nurio.android.MainActivity
import dev.hotwire.core.config.Hotwire
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityNavigationTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val originalWebViewFactory = Hotwire.config.makeCustomWebView

    @Before
    fun setUp() {
        // Exercise real Hotwire fragments without contacting Rails or a payment
        // provider. Navigation readiness must not depend on network completion.
        Hotwire.config.makeCustomWebView = { context ->
            originalWebViewFactory(context).apply { settings.blockNetworkLoads = true }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            instrumentation.uiAutomation.grantRuntimePermission(
                BuildConfig.APPLICATION_ID,
                android.Manifest.permission.POST_NOTIFICATIONS
            )
        }
    }

    @After
    fun tearDown() {
        Hotwire.config.makeCustomWebView = originalWebViewFactory
    }

    @Test
    fun coldStartDeliversDeepLinkAfterDestinationResumes() {
        val destination = "${BuildConfig.BASE_URL}/settings/tickets"
        ActivityScenario.launch<MainActivity>(openIntent(destination)).use { scenario ->
            awaitDestination(scenario, destination)
        }
    }

    @Test
    fun coldStartPreservesPaymentCallbackAndEventContext() {
        val callback = Uri.Builder()
            .scheme("nurio")
            .authority("payment-complete")
            .appendQueryParameter("paymentId", "navigation-regression")
            .appendQueryParameter("redirect_uri", "/events/17")
            .build()
        val destination = Uri.parse("${BuildConfig.BASE_URL}/payments/portone/complete")
            .buildUpon()
            .appendQueryParameter("paymentId", "navigation-regression")
            .appendQueryParameter("redirect_uri", "/events/17")
            .build()
            .toString()

        ActivityScenario.launch<MainActivity>(launchIntent(callback)).use { scenario ->
            awaitDestination(scenario, destination)
        }
    }

    @Test
    fun activityRecreationPreservesDeepLinkWithoutNavigatingDuringAttachment() {
        val destination = "${BuildConfig.BASE_URL}/settings/tickets"
        ActivityScenario.launch<MainActivity>(openIntent(destination)).use { scenario ->
            awaitDestination(scenario, destination)
            scenario.recreate()
            awaitDestination(scenario, destination)
        }
    }

    @Test
    fun returningFromBackgroundDeliversNotificationIntent() {
        val firstDestination = "${BuildConfig.BASE_URL}/settings/tickets?_native_refresh=first"
        val nextDestination = "${BuildConfig.BASE_URL}/events?_native_refresh=second"
        // ActivityScenario identifies an activity by its intent's action/data.
        // Notification extras can change without losing its lifecycle observer.
        ActivityScenario.launch<MainActivity>(notificationIntent("/settings/tickets", "first")).use { scenario ->
            awaitDestination(scenario, firstDestination)
            scenario.moveToState(Lifecycle.State.CREATED)
            instrumentation.targetContext.startActivity(notificationIntent("/events", "second"))
            awaitDestination(scenario, nextDestination)
        }
    }

    private fun notificationIntent(path: String, id: String) =
        Intent(instrumentation.targetContext, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .putExtra("path", path)
            .putExtra(MainActivity.EXTRA_NOTIFICATION_ID, id)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun openIntent(destination: String): Intent {
        val uri = Uri.Builder()
            .scheme("nurio")
            .authority("open")
            .appendQueryParameter("url", destination)
            .build()
        return launchIntent(uri)
    }

    private fun launchIntent(uri: Uri) = Intent(instrumentation.targetContext, MainActivity::class.java)
        .setAction(Intent.ACTION_VIEW)
        .setData(uri)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun awaitDestination(scenario: ActivityScenario<MainActivity>, expected: String) {
        val deadline = SystemClock.uptimeMillis() + 10_000L
        var actual: String? = null
        var resumed = false
        while (SystemClock.uptimeMillis() < deadline) {
            instrumentation.waitForIdleSync()
            scenario.onActivity { activity ->
                val navigator = activity.delegate.currentNavigator
                actual = navigator?.location
                val destination = navigator?.currentDestination as? Fragment
                resumed = destination?.viewLifecycleOwnerLiveData?.value?.lifecycle
                    ?.currentState?.isAtLeast(Lifecycle.State.RESUMED) == true
            }
            if (actual == expected && resumed) return
            SystemClock.sleep(50L)
        }

        assertEquals("Queued navigation was not delivered", expected, actual)
        assertEquals("Destination view did not resume", true, resumed)
    }
}
