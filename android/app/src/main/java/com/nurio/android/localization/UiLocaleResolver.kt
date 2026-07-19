package com.nurio.android.localization

import java.util.Locale

internal object UiLocaleResolver {
    private const val DEFAULT_LANGUAGE = "en"
    private val supportedLanguages = setOf(DEFAULT_LANGUAGE, "ko")

    fun resolve(languageIdentifiers: List<String>): String {
        for (identifier in languageIdentifiers) {
            val language = parseBaseLanguage(identifier) ?: continue
            if (language in supportedLanguages) return language
        }

        return DEFAULT_LANGUAGE
    }

    private fun parseBaseLanguage(identifier: String): String? {
        val normalizedIdentifier = identifier.trim().replace('_', '-')
        if (normalizedIdentifier.isEmpty()) return null

        return runCatching {
            Locale.Builder()
                .setLanguageTag(normalizedIdentifier)
                .build()
                .language
                .lowercase(Locale.ROOT)
        }.getOrNull()?.takeIf { it.isNotEmpty() }
    }
}
