package com.nurio.android.fragments

import com.nurio.android.webview.PaymentWebChromeClient
import dev.hotwire.core.turbo.webview.HotwireWebChromeClient
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web/modal")
class WebModalFragment : HotwireWebBottomSheetFragment() {
    override fun createWebChromeClient(): HotwireWebChromeClient {
        return PaymentWebChromeClient(navigator.session)
    }
}
