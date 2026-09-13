package com.nurio.android.webview

import android.app.Dialog
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.webkit.WebView
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.graphics.drawable.toDrawable
import com.nurio.android.R
import com.nurio.android.payments.PaymentRecoveryHost
import com.nurio.android.payments.findPaymentRecoveryHost

/** Owns the actual browser-created window for the lifetime of a payment popup. */
internal class PaymentPopupWindow(
    private val parent: WebView,
    private val popup: WebView,
) : View.OnAttachStateChangeListener {
    private var closed = false
    private var presented = false
    private val host = TextView(parent.context).apply {
        setTextColor(Color.DKGRAY)
        textSize = 14f
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
    }
    private val dialog = Dialog(parent.context).apply {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        setCanceledOnTouchOutside(false)
        setOnCancelListener { dismissByUser() }
        setOnDismissListener { close() }
    }

    init {
        openWindows.add(this)
        parent.addOnAttachStateChangeListener(this)
    }

    fun show(providerHost: String) {
        if (closed) return
        host.text = providerHost
        if (presented) return
        // A popup can start navigating while Dialog.show is still attaching
        // its content. Never rebuild or reparent the window on that callback.
        presented = true

        val spacing = (16 * parent.resources.displayMetrics.density).toInt()
        val heading = LinearLayout(parent.context).apply {
            orientation = LinearLayout.VERTICAL
            addView(TextView(context).apply {
                setText(R.string.payment_window_title)
                setTextColor(Color.DKGRAY)
                textSize = 18f
            })
            addView(host)
        }
        val toolbar = LinearLayout(parent.context).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(spacing, spacing / 2, spacing, spacing / 2)
            addView(heading, LinearLayout.LayoutParams(0, -2, 1f))
            addView(Button(context).apply {
                setText(R.string.dismiss)
                setOnClickListener { dismissByUser() }
            })
        }
        dialog.setContentView(LinearLayout(parent.context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
            addView(toolbar, LinearLayout.LayoutParams(-1, -2))
            addView(popup, LinearLayout.LayoutParams(-1, 0, 1f))
        })
        dialog.show()
        dialog.window?.apply {
            setBackgroundDrawable(Color.WHITE.toDrawable())
            setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
    }

    fun close() {
        if (closed) return
        closed = true
        openWindows.remove(this)
        parent.removeOnAttachStateChangeListener(this)
        (popup.parent as? ViewGroup)?.removeView(popup)
        dialog.dismiss()
        // WebView callbacks must finish before their WebView is destroyed.
        Handler(Looper.getMainLooper()).post { popup.destroy() }
    }

    private fun dismissByUser() {
        if (closed) return
        close()
        parent.context.findPaymentRecoveryHost()?.onPaymentPopupDismissed()
    }

    override fun onViewDetachedFromWindow(view: View) = close()
    override fun onViewAttachedToWindow(view: View) = Unit

    companion object {
        private val openWindows = mutableSetOf<PaymentPopupWindow>()

        fun closeAll(host: PaymentRecoveryHost) {
            // Closing a parent detaches its children and mutates the registry.
            // Programmatic closure must not trigger user-dismiss recovery.
            openWindows.filter { it.parent.context.findPaymentRecoveryHost() === host }
                .forEach { it.close() }
        }
    }
}
