package com.nurio.studyleaders.android.bridge

import android.util.Log
import com.nurio.studyleaders.android.BuildConfig
import com.nurio.studyleaders.android.MainActivity
import com.nurio.studyleaders.android.auth.SocialAuthRoute
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
        val route = SocialAuthRoute.resolve(data.startPath, BuildConfig.BASE_URL) ?: return
        val activity = delegate.destination.fragment.activity as? MainActivity

        if (activity == null) {
            Log.w(TAG, "Cannot launch OAuth because the fragment is not attached")
            return
        }

        activity.dispatchSocialAuth(route)
    }

    @Serializable
    data class ClickData(
        @SerialName("startPath") val startPath: String
    )
}
