package com.nurio.study.android.bridge

import android.view.View
import android.view.ViewTreeObserver
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.math.roundToInt

/**
 * Mirrors ios/Bridge/KeyboardInsetsComponent.swift. The activity is edge-to-edge, so on
 * Android 11+ the window never resizes for the keyboard and the WebView keeps its full
 * height while the IME draws over its bottom. This component reports how much of the
 * screen the keyboard covers, in CSS px, on every change; the web side re-broadcasts each
 * reply as a `native-keyboard:inset` window event.
 *
 * The raw screen overlap is reported on purpose, exactly like iOS. The web layout converts
 * it into layout-viewport space (`innerHeight + inset - screen.height`), so when the WebView
 * has already been shrunk for the keyboard — LegacyWebViewInsets pads the content view by
 * the IME inset on older Android/WebView builds — that conversion collapses to zero and the
 * composer is never lifted twice.
 */
class KeyboardInsetsComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {
    private var observedView: View? = null
    private var lastHeight = 0
    private var active = true

    private val layoutListener = ViewTreeObserver.OnGlobalLayoutListener { publishIfChanged() }

    private val animationCallback =
        object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_CONTINUE_ON_SUBTREE) {
            override fun onProgress(
                insets: WindowInsetsCompat,
                runningAnimations: MutableList<WindowInsetsAnimationCompat>
            ): WindowInsetsCompat = insets

            // Root insets already hold the end state here, so the page learns the final
            // keyboard height as the animation begins — the same moment iOS reports
            // keyboardWillChangeFrame.
            override fun onStart(
                animation: WindowInsetsAnimationCompat,
                bounds: WindowInsetsAnimationCompat.BoundsCompat
            ): WindowInsetsAnimationCompat.BoundsCompat {
                publishIfChanged()
                return bounds
            }

            override fun onEnd(animation: WindowInsetsAnimationCompat) {
                publishIfChanged()
            }
        }

    override fun onReceive(message: Message) {
        if (message.event != "connect") return

        startObservingIfNeeded()
        lastHeight = currentHeight()
        reply(message, lastHeight)
    }

    override fun onStart() {
        active = true
        publishIfChanged()
    }

    override fun onStop() {
        active = false
    }

    private fun startObservingIfNeeded() {
        if (observedView != null) return

        val fragment = bridgeDelegate.destination.fragment
        val view = fragment.view ?: return
        observedView = view
        ViewCompat.setWindowInsetsAnimationCallback(view, animationCallback)
        view.viewTreeObserver.addOnGlobalLayoutListener(layoutListener)

        fragment.viewLifecycleOwner.lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onDestroy(owner: LifecycleOwner) {
                stopObserving()
            }
        })
    }

    private fun stopObserving() {
        val view = observedView ?: return
        ViewCompat.setWindowInsetsAnimationCallback(view, null)
        if (view.viewTreeObserver.isAlive) {
            view.viewTreeObserver.removeOnGlobalLayoutListener(layoutListener)
        }
        observedView = null
    }

    private fun publishIfChanged() {
        if (!active || observedView == null) return

        val height = currentHeight()
        if (height == lastHeight) return

        lastHeight = height
        val message = receivedMessageFor("connect") ?: return
        reply(message, height)
    }

    private fun currentHeight(): Int {
        val view = observedView ?: return 0
        val imeBottom = ViewCompat.getRootWindowInsets(view)
            ?.getInsets(WindowInsetsCompat.Type.ime())
            ?.bottom
            ?: 0
        return KeyboardInsets.cssPixels(imeBottom, view.resources.displayMetrics.density)
    }

    private fun reply(message: Message, height: Int) {
        replyWith(message.replacing(jsonData = Json.encodeToString(InsetData.serializer(), InsetData(height))))
    }

    @Serializable
    data class InsetData(
        @SerialName("height") val height: Int
    )
}

internal object KeyboardInsets {
    /** WebView CSS px are density-independent pixels, so dp is the page's unit. */
    fun cssPixels(imeBottomPx: Int, density: Float): Int {
        if (imeBottomPx <= 0 || density <= 0f) return 0
        return (imeBottomPx / density).roundToInt()
    }
}
