package com.nurio.study.android.fragments

import android.os.Bundle
import android.view.View
import com.nurio.study.android.BuildConfig
import com.nurio.study.android.microphone.AiPracticeNativePolicy
import com.nurio.study.android.microphone.MicPermissionHost
import com.nurio.study.android.microphone.StudyWebChromeClient
import dev.hotwire.core.turbo.webview.HotwireWebChromeClient
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class WebFragment : HotwireWebFragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        toolbarForNavigation()?.visibility = View.GONE
        view.keepScreenOn = AiPracticeNativePolicy.isSessionLocation(location)
    }

    override fun onDestroyView() {
        view?.keepScreenOn = false
        super.onDestroyView()
    }

    override fun createWebChromeClient(): HotwireWebChromeClient {
        val permissionHost = activity as? MicPermissionHost ?: return super.createWebChromeClient()
        return StudyWebChromeClient(
            session = navigator.session,
            microphonePermissionHost = permissionHost,
            trustedBaseUrl = BuildConfig.BASE_URL
        )
    }
}
