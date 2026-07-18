package com.nurio.study.android.notifications

import java.net.URI

object NotificationDestination {
    private val blockedPrefixes = listOf("/admin", "/tutoring", "/tutors")

    fun resolve(path: String?, url: String?, baseUrl: String): String {
        val base = parseBase(baseUrl) ?: return baseUrl
        val origin = origin(base)

        return resolveCandidate(path, base, origin)
            ?: resolveCandidate(url, base, origin)
            ?: origin
    }

    private fun resolveCandidate(candidate: String?, base: URI, origin: String): String? {
        val value = candidate?.trim()?.takeIf(String::isNotEmpty) ?: return null
        val uri = runCatching { URI(value) }.getOrNull() ?: return null

        if (uri.rawFragment != null || uri.rawUserInfo != null) return null

        val isRelativePath = uri.scheme == null && uri.rawAuthority == null
        val isSameOriginUrl = uri.scheme.equals("https", ignoreCase = true) &&
            uri.host?.equals(base.host, ignoreCase = true) == true &&
            effectivePort(uri) == effectivePort(base)

        if (!isRelativePath && !isSameOriginUrl) return null

        val rawPath = uri.rawPath.orEmpty()
        if (!rawPath.startsWith("/") || rawPath.startsWith("//") || rawPath.contains('%')) return null
        if (isBlocked(rawPath)) return null

        val query = uri.rawQuery?.let { "?$it" }.orEmpty()
        return "$origin$rawPath$query"
    }

    private fun parseBase(baseUrl: String): URI? {
        val base = runCatching { URI(baseUrl) }.getOrNull() ?: return null
        if (!base.scheme.equals("https", ignoreCase = true)) return null
        if (base.host.isNullOrBlank() || base.rawUserInfo != null || base.rawFragment != null) return null
        if (base.rawQuery != null || base.rawPath !in listOf("", "/")) return null
        if (effectivePort(base) != 443) return null
        return base
    }

    private fun origin(base: URI): String = "https://${base.host!!.lowercase()}"

    private fun effectivePort(uri: URI): Int = if (uri.port == -1) 443 else uri.port

    private fun isBlocked(path: String): Boolean {
        val normalized = path.lowercase()
        return blockedPrefixes.any { prefix ->
            normalized == prefix || normalized.startsWith("$prefix/")
        }
    }
}
