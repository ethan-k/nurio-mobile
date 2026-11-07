package com.nurio.android.fragments

import android.os.Bundle
import android.view.View
import com.nurio.android.BuildConfig
import com.nurio.android.microphone.MicPermissionHost
import com.nurio.android.microphone.MicrophoneWebChromeClient
import com.nurio.android.webview.PaymentWebChromeClient
import dev.hotwire.core.turbo.webview.HotwireWebChromeClient
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class WebFragment : HotwireWebFragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        toolbarForNavigation()?.visibility = View.GONE
    }

    override fun createWebChromeClient(): HotwireWebChromeClient {
        val session = navigator.session
        val permissionHost = activity as? MicPermissionHost
            ?: return PaymentWebChromeClient(session)
        return MicrophoneWebChromeClient(
            session = session,
            microphonePermissionHost = permissionHost,
            trustedBaseUrl = BuildConfig.BASE_URL,
            currentLocation = { session.webView.url }
        )
    }
}
