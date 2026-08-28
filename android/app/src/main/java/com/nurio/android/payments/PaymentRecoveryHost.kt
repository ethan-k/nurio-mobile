package com.nurio.android.payments

import android.content.Context
import android.content.ContextWrapper

interface PaymentRecoveryHost {
    fun onExternalPaymentLaunchFailed()
}

internal fun Context.findPaymentRecoveryHost(): PaymentRecoveryHost? {
    var current: Context? = this
    val visited = mutableSetOf<Context>()

    while (current != null && visited.add(current)) {
        if (current is PaymentRecoveryHost) return current
        current = (current as? ContextWrapper)?.baseContext
    }

    return null
}
