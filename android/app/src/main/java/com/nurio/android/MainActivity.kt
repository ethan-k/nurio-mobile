package com.nurio.android

import android.os.Bundle
import android.view.View
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {

    private lateinit var bottomNavigation: BottomNavigationView
    private var currentTabId = R.id.nav_home

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        setupBottomNavigation()
        setupEdgeToEdge()
        setupBackNavigation()
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

    private fun setupEdgeToEdge() {
        ViewCompat.setOnApplyWindowInsetsListener(bottomNavigation) { view, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(0, 0, 0, systemBars.bottom)
            insets
        }
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // If not on home tab, go to home tab
                if (currentTabId != R.id.nav_home) {
                    bottomNavigation.selectedItemId = R.id.nav_home
                } else {
                    // On home tab, let the system handle it (exit app)
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
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
