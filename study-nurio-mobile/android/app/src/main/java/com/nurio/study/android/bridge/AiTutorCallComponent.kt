package com.nurio.study.android.bridge

import android.util.Log
import com.nurio.study.android.BuildConfig
import com.nurio.study.android.aitutor.AiTutorCallActivity
import com.nurio.study.android.aitutor.AiTutorCallController
import com.nurio.study.android.aitutor.AiTutorCallRequest
import com.nurio.study.android.microphone.MicPermissionHost
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * `ai-tutor-call`: takes the class-review call over from the web page (/practice/<id>).
 * Replying `{event: "presented"}` tells the page to stop offering its WebView call; when this
 * component cannot take over it stays silent and the web call keeps working.
 */
class AiTutorCallComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {
    override fun onReceive(message: Message) {
        if (message.event != "start") return

        val data = runCatching { message.data<StartData>() }.getOrNull()
        val request = data?.let {
            AiTutorCallRequest.resolve(
                joinUrl = it.joinUrl,
                endUrl = it.endUrl,
                reviewUrl = it.reviewUrl,
                topic = it.topic,
                csrfToken = it.csrfToken,
                baseUrl = BuildConfig.BASE_URL
            )
        }
        val activity = delegate.destination.fragment.activity
        val permissionHost = activity as? MicPermissionHost
        if (request == null || activity == null || permissionHost == null) {
            Log.w(TAG, "Native class review unavailable; keeping the web call")
            return
        }

        replyWith(message.replacing(jsonData = PRESENTED_JSON))

        if (AiTutorCallController.isActive) {
            AiTutorCallActivity.open(activity)
            return
        }

        val appContext = activity.applicationContext
        permissionHost.requestMicrophonePermission { granted ->
            if (!granted) {
                AiTutorCallController.endWithoutCall(appContext, request)
                return@requestMicrophonePermission
            }

            AiTutorCallController.start(appContext, request)
            val host = delegate.destination.fragment.activity
            if (host != null && !host.isFinishing && !host.isDestroyed) {
                AiTutorCallActivity.open(host)
            } else {
                AiTutorCallActivity.open(appContext)
            }
        }
    }

    @Serializable
    data class StartData(
        @SerialName("joinUrl") val joinUrl: String? = null,
        @SerialName("endUrl") val endUrl: String? = null,
        @SerialName("reviewUrl") val reviewUrl: String? = null,
        @SerialName("topic") val topic: String? = null,
        @SerialName("csrfToken") val csrfToken: String? = null
    )

    private companion object {
        const val TAG = "AiTutorCallBridge"
        const val PRESENTED_JSON = """{"event":"presented"}"""
    }
}
