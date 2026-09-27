package com.nurio.android.webview

import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.View
import android.webkit.WebView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Android WebView reports `env(safe-area-inset-*)` as 0 on an edge-to-edge activity unless both
 * the WebView is Chromium 140+ and the device runs Android 15+ (older Android, e.g. Android 10 on
 * a Mi 8 Lite, stays at 0 even with an up-to-date WebView), so web content slides under the
 * status and navigation bars. In those cases pad the content view by the system-bar insets
 * natively, so the page sits between the bars. The insets are consumed, so the WebView never
 * double-pads through `env()`.
 */
object LegacyWebViewInsets {
    private const val TAG = "LegacyWebViewInsets"
    private const val FIRST_SAFE_AREA_AWARE_MAJOR = 140
    private const val FIRST_SAFE_AREA_AWARE_SDK = Build.VERSION_CODES.VANILLA_ICE_CREAM

    fun needsNativeSystemBarPadding(sdkInt: Int, webViewVersionName: String?): Boolean {
        if (sdkInt < FIRST_SAFE_AREA_AWARE_SDK) return true
        val major = webViewVersionName?.substringBefore('.')?.toIntOrNull() ?: return false
        return major < FIRST_SAFE_AREA_AWARE_MAJOR
    }

    fun applyIfNeeded(activity: Activity) {
        val versionName = WebView.getCurrentWebViewPackage()?.versionName
        if (!needsNativeSystemBarPadding(Build.VERSION.SDK_INT, versionName)) return

        Log.i(TAG, "Android ${Build.VERSION.SDK_INT} / WebView $versionName lacks safe-area insets; padding system bars natively")
        WindowCompat.getInsetsController(activity.window, activity.window.decorView).apply {
            isAppearanceLightStatusBars = true
            isAppearanceLightNavigationBars = true
        }

        val content = activity.findViewById<View>(android.R.id.content)
        ViewCompat.setOnApplyWindowInsetsListener(content) { view, insets ->
            val bars = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
            )
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            view.setPadding(bars.left, bars.top, bars.right, maxOf(bars.bottom, ime.bottom))
            WindowInsetsCompat.CONSUMED
        }
    }
}
