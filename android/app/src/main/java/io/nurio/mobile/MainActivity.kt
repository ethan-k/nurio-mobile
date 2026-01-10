package io.nurio.mobile

import android.os.Bundle
import android.view.View
import androidx.activity.enableEdgeToEdge
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {

    private lateinit var bottomNavigation: BottomNavigationView
    private var currentTabId = R.id.nav_home

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        setupBottomNavigation()
    }

    private fun setupBottomNavigation() {
        bottomNavigation = findViewById(R.id.bottom_navigation)

        bottomNavigation.setOnItemSelectedListener { item ->
            if (item.itemId != currentTabId) {
                switchTab(item.itemId)
                currentTabId = item.itemId
            }
            true
        }
    }

    private fun switchTab(tabId: Int) {
        val homeHost = findViewById<View>(R.id.nav_host_home)
        val eventsHost = findViewById<View>(R.id.nav_host_events)
        val profileHost = findViewById<View>(R.id.nav_host_profile)

        homeHost.visibility = View.GONE
        eventsHost.visibility = View.GONE
        profileHost.visibility = View.GONE

        when (tabId) {
            R.id.nav_home -> homeHost.visibility = View.VISIBLE
            R.id.nav_events -> eventsHost.visibility = View.VISIBLE
            R.id.nav_profile -> profileHost.visibility = View.VISIBLE
        }
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "home",
            startLocation = BuildConfig.BASE_URL,
            navigatorHostId = R.id.nav_host_home
        ),
        NavigatorConfiguration(
            name = "events",
            startLocation = "${BuildConfig.BASE_URL}/events",
            navigatorHostId = R.id.nav_host_events
        ),
        NavigatorConfiguration(
            name = "profile",
            startLocation = "${BuildConfig.BASE_URL}/settings/profile",
            navigatorHostId = R.id.nav_host_profile
        )
    )
}
