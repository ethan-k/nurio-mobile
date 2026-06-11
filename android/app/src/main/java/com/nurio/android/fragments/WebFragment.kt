package com.nurio.android.fragments

import android.os.Bundle
import android.view.View
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
        return PaymentWebChromeClient(navigator.session)
    }
}
