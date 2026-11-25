package com.nurio.tutors.android

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PathConfigurationAssetTest {
    @Test
    fun `locale prefixes preserve bundled path configuration properties`() {
        val asset = listOf(
            File("src/main/assets/json/path-configuration.json"),
            File("app/src/main/assets/json/path-configuration.json")
        ).first(File::isFile)
        val rules = Json.parseToJsonElement(asset.readText()).jsonObject.getValue("rules").jsonArray
        val paths = listOf(
            "/settings",
            "/auth/login",
            "/auth/create-account",
            "/auth/verify",
            "/signup",
            "/orders/new",
            "/orders/12/payment_summary",
            "/bookings/new",
            "/bookings/12/review/new",
            "/dashboard/onboarding",
            "/dashboard/offers/new",
            "/dashboard/offers/12/edit",
            "/credits",
            "/bookings",
            "/dashboard",
            "/tutors",
        )
        assertTrue("Missing path configuration rules", rules.isNotEmpty())
        val patternsByRule = rules.associateWith { rule ->
            val patterns = rule.jsonObject.getValue("patterns").jsonArray
            assertTrue("Missing patterns for rule $rule", patterns.isNotEmpty())
            patterns.map { Regex(it.jsonPrimitive.content) }
        }
        fun propertiesFor(path: String) = rules.filter { rule ->
            patternsByRule.getValue(rule).any { it.containsMatchIn(path) }
        }.flatMap { rule ->
            rule.jsonObject.getValue("properties").jsonObject.entries
        }.associate { it.key to it.value }

        for (path in paths) {
            for (locale in listOf("en", "ko", "KO")) {
                val prefixed = "/$locale$path"
                assertEquals(prefixed, propertiesFor(path), propertiesFor(prefixed))
            }
        }
        for (pattern in patternsByRule.values.flatten()) {
            val samples = paths.filter(pattern::containsMatchIn)
            assertTrue("Missing sample for ${pattern.pattern}", samples.isNotEmpty())
            for (path in samples) {
                assertTrue("${pattern.pattern} must match /ko$path", pattern.containsMatchIn("/ko$path"))
            }
        }
    }
}
