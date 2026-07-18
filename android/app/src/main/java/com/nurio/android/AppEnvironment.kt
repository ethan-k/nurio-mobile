package com.nurio.android

internal object AppEnvironment {
    fun coldStartLocation(baseUrl: String): String {
        return "${baseUrl.trimEnd('/')}/"
    }
}
