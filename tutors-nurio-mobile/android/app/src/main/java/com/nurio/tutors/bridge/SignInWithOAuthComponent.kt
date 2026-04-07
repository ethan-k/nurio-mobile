package com.nurio.tutors.bridge

import android.net.Uri
import android.util.Log
import androidx.browser.customtabs.CustomTabsIntent
import com.nurio.tutors.BuildConfig
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
    companion object {
        private const val TAG = "OAuthComponent"
    }

    override fun onReceive(message: Message) {
        when (message.event) {
            "click" -> handleClick(message)
            else -> Log.w(TAG, "Unknown event: ${message.event}")
        }
    }

    private fun handleClick(message: Message) {
        val data = message.data<ClickData>() ?: return
        if (data.startPath.isBlank()) {
            Log.w(TAG, "Missing OAuth start path")
            return
        }

        val fullUrl = if (data.startPath.startsWith("http://") || data.startPath.startsWith("https://")) {
            data.startPath
        } else {
            "${BuildConfig.BASE_URL.trimEnd('/')}/${data.startPath.trimStart('/')}"
        }
        val activity = delegate.destination.fragment.activity

        if (activity == null) {
            Log.w(TAG, "Cannot launch OAuth because the fragment is not attached")
            return
        }

        val customTabsIntent = CustomTabsIntent.Builder().build()
        customTabsIntent.launchUrl(activity, Uri.parse(fullUrl))
    }

    @Serializable
    data class ClickData(
        @SerialName("startPath") val startPath: String
    )
}
