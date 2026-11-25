package com.nurio.studyleaders.android

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
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
            "/schedule",
            "/new",
            "/edit",
            "/sessions/12/new",
            "/sessions/12/edit",
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

    @Test
    fun `bundled path configuration exists and keeps login a full page`() {
        val asset = listOf(
            File("src/main/assets/json/path-configuration.json"),
            File("app/src/main/assets/json/path-configuration.json")
        ).firstOrNull(File::isFile)

        assertNotNull("Study Leader path configuration asset is missing", asset)

        val rules = Json.parseToJsonElement(asset!!.readText())
            .jsonObject
            .getValue("rules")
            .jsonArray

        assertTrue("Default Hotwire route rule is missing", rules.any { rule ->
            val properties = rule.jsonObject.getValue("properties").jsonObject
            properties["uri"]?.jsonPrimitive?.content == "hotwire://fragment/web"
        })

        // Login, signup, and /auth/* must stay regular navigations. The
        // logged-out root redirects to /login, so a modal rule here would
        // auto-present the login sheet whenever the app opens — and would
        // also stack a modal on /auth/native/token_auth after every native
        // login. The learner Study app keeps /login a full page too.
        val modalPatterns = rules
            .filter { rule ->
                val properties = rule.jsonObject.getValue("properties").jsonObject
                properties["context"]?.jsonPrimitive?.content == "modal"
            }
            .flatMap { rule ->
                rule.jsonObject.getValue("patterns").jsonArray.map { it.jsonPrimitive.content }
            }

        listOf("/login.*", "/signup.*", "/auth/.*").forEach { pattern ->
            assertFalse(
                "$pattern must not be presented as a modal",
                pattern in modalPatterns
            )
        }
    }
}
