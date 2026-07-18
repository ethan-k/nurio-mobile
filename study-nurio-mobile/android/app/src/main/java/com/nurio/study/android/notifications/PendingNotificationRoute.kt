package com.nurio.study.android.notifications

class PendingNotificationRoute {
    private var destination: String? = null

    @Synchronized
    fun accept(destination: String) {
        this.destination = destination
    }

    @Synchronized
    fun consume(): String? = destination.also { destination = null }
}
