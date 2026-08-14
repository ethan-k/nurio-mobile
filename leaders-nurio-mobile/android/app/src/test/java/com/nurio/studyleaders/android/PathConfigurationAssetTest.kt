package com.nurio.studyleaders.android

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PathConfigurationAssetTest {
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
