package com.nurio.android

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        delegate.setCurrentNavigator(navigatorConfigurations().first())
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "events",
            startLocation = "${BuildConfig.BASE_URL}/events",
            navigatorHostId = R.id.nav_host_events
        )
    )
}
