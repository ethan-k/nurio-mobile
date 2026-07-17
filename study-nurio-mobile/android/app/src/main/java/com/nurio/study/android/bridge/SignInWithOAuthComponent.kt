package com.nurio.study.android.bridge

import com.nurio.study.android.BuildConfig
import com.nurio.study.android.MainActivity
import com.nurio.study.android.auth.SocialAuthRoute
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
        if (message.event == "click") handleClick(message)
    }

    private fun handleClick(message: Message) {
        val data = message.data<ClickData>() ?: return
        val route = SocialAuthRoute.resolve(data.startPath, BuildConfig.BASE_URL) ?: return
        val activity = delegate.destination.fragment.activity as? MainActivity ?: return

        activity.dispatchSocialAuth(route)
    }

    @Serializable
    data class ClickData(
        @SerialName("startPath") val startPath: String
    )
}
