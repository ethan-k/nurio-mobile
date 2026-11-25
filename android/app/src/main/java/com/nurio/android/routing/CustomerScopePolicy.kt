package com.nurio.android.routing

import com.nurio.android.LocalePath

internal object CustomerScopePolicy {
    private val blockedPathPrefixes = listOf(
        "/admin",
        "/tutoring",
        "/tutors",
        "/study_group_admin",
    )

    fun isBlockedPath(path: String): Boolean {
        val normalized = LocalePath.strip(path).lowercase()
        return blockedPathPrefixes.any { prefix ->
            normalized == prefix || normalized.startsWith("$prefix/")
        }
    }
}
