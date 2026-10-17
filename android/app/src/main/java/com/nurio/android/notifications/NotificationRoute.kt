package com.nurio.android.notifications

import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

internal object NotificationRoute {
    const val REFRESH_QUERY_PARAMETER = "_native_refresh"

    private val blockedPathPrefixes = listOf(
        "/admin",
        "/tutoring",
        "/tutors",
        "/study_group_admin",
    )

    fun destination(path: String?, baseUrl: String): String? {
        val value = path?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val baseUri = parseUri(baseUrl) ?: return null
        val candidate = when {
            value.startsWith("/") && !value.startsWith("//") -> baseUri.resolve(value)
            else -> parseUri(value)
        } ?: return null

        val scheme = candidate.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return null

        val baseHost = baseUri.host?.lowercase() ?: return null
        val candidateHost = candidate.host?.lowercase() ?: return null
        if (candidateHost != baseHost && candidateHost != "www.$baseHost") return null

        val normalizedPath = candidate.path.orEmpty().lowercase()
        if (blockedPathPrefixes.any { prefix ->
                normalizedPath == prefix || normalizedPath.startsWith("$prefix/")
            }
        ) {
            return null
        }

        return if (candidateHost == "www.$baseHost") {
            URI(
                baseUri.scheme,
                candidate.userInfo,
                baseHost,
                baseUri.port,
                candidate.path,
                candidate.query,
                candidate.fragment,
            ).toString()
        } else {
            candidate.toString()
        }
    }

    /**
     * True when the push points at the visible screen. Only the path is compared: the push
     * and the page may differ in query parameters such as `lang` without being different screens.
     */
    fun isShowing(pushPath: String?, visibleLocation: String?, baseUrl: String): Boolean {
        val push = destination(pushPath, baseUrl)?.let(::parseUri) ?: return false
        val visible = destination(visibleLocation, baseUrl)?.let(::parseUri) ?: return false

        return push.host.equals(visible.host, ignoreCase = true) &&
            normalizedPath(push) == normalizedPath(visible)
    }

    private fun normalizedPath(uri: URI): String =
        uri.path.orEmpty().trimEnd('/').ifEmpty { "/" }

    fun refreshingDestination(destination: String, token: String): String {
        val fragment = destination.substringAfter('#', missingDelimiterValue = "")
        val withoutFragment = destination.substringBefore('#')
        val base = withoutFragment.substringBefore('?')
        val existingQuery = withoutFragment.substringAfter('?', missingDelimiterValue = "")
        val queryParts = existingQuery
            .split('&')
            .filter { it.isNotEmpty() }
            .filterNot { it.substringBefore('=') == REFRESH_QUERY_PARAMETER }
            .toMutableList()
        val encodedToken = URLEncoder.encode(token, StandardCharsets.UTF_8.toString())
            .replace("+", "%20")

        queryParts += "$REFRESH_QUERY_PARAMETER=$encodedToken"

        return buildString {
            append(base)
            append('?')
            append(queryParts.joinToString("&"))
            if (fragment.isNotEmpty()) {
                append('#')
                append(fragment)
            }
        }
    }

    private fun parseUri(value: String): URI? {
        return try {
            URI(value)
        } catch (_: IllegalArgumentException) {
            null
        }
    }
}
