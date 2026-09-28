package com.nurio.study.android.webview

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LegacyWebViewInsetsTest {
    private val android10 = 29
    private val android14 = 34
    private val android15 = 35

    @Test
    fun `pads system bars natively when the WebView predates safe-area support`() {
        assertTrue(LegacyWebViewInsets.needsNativeSystemBarPadding(android15, "139.0.7258.158"))
    }

    @Test
    fun `pads system bars natively on Android 10 even with an up-to-date WebView`() {
        assertTrue(LegacyWebViewInsets.needsNativeSystemBarPadding(android10, "140.0.7339.207"))
    }

    @Test
    fun `pads system bars natively below Android 15 whatever the WebView reports`() {
        assertTrue(LegacyWebViewInsets.needsNativeSystemBarPadding(android14, "150.0.1.2"))
        assertTrue(LegacyWebViewInsets.needsNativeSystemBarPadding(android14, null))
    }

    @Test
    fun `leaves edge-to-edge alone when the WebView reports safe-area insets`() {
        assertFalse(LegacyWebViewInsets.needsNativeSystemBarPadding(android15, "140.0.7339.207"))
    }

    @Test
    fun `leaves edge-to-edge alone for newer WebViews`() {
        assertFalse(LegacyWebViewInsets.needsNativeSystemBarPadding(android15, "150.0.1.2"))
    }

    @Test
    fun `leaves edge-to-edge alone on Android 15 when the WebView version is unknown`() {
        assertFalse(LegacyWebViewInsets.needsNativeSystemBarPadding(android15, null))
        assertFalse(LegacyWebViewInsets.needsNativeSystemBarPadding(android15, ""))
        assertFalse(LegacyWebViewInsets.needsNativeSystemBarPadding(android15, "dev-build"))
    }
}
