package com.nurio.android.bridge

import android.net.Uri
import android.util.Log
import androidx.browser.customtabs.CustomTabsIntent
import com.nurio.android.BuildConfig
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class SignInWithOAuthComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "click" -> handleClick(message)
            else -> Log.w("OAuthComponent", "Unknown event: ${message.event}")
        }
    }

    private fun handleClick(message: Message) {
        val data = message.data<ClickData>() ?: return
        val baseUrl = BuildConfig.BASE_URL
        val fullUrl = "$baseUrl${data.startPath}"

        val customTabsIntent = CustomTabsIntent.Builder().build()
        val activity = delegate.destination.fragment.requireActivity()
        customTabsIntent.launchUrl(activity, Uri.parse(fullUrl))
    }

    @Serializable
    data class ClickData(
        @SerialName("startPath") val startPath: String
    )
}
