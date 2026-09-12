package com.nurio.android

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PathConfigurationAssetTest {
    @Test
    fun `bundled path configuration keeps the native sign-in destinations out of modals`() {
        val asset = listOf(
            File("src/main/assets/json/path-configuration.json"),
            File("app/src/main/assets/json/path-configuration.json")
        ).firstOrNull(File::isFile)

        assertNotNull("Customer path configuration asset is missing", asset)

        val rules = Json.parseToJsonElement(asset!!.readText())
            .jsonObject
            .getValue("rules")
            .jsonArray

        assertTrue("Default Hotwire route rule is missing", rules.any { rule ->
            val properties = rule.jsonObject.getValue("properties").jsonObject
            properties["uri"]?.jsonPrimitive?.content == "hotwire://fragment/web"
        })

        // /auth/native/token_auth is visited on the main stack and redirects to
        // /signup for a brand-new account. A modal rule for that destination makes
        // Hotwire Native present /signup as a sheet on top of the main screen that
        // already rendered the same page, so the user sees the signup page twice.
        val modalPatterns = rules
            .filter { rule ->
                val properties = rule.jsonObject.getValue("properties").jsonObject
                properties["context"]?.jsonPrimitive?.content == "modal"
            }
            .flatMap { rule ->
                rule.jsonObject.getValue("patterns").jsonArray.map { it.jsonPrimitive.content }
            }

        listOf("/signup", "/login", "/auth/native/token_auth").forEach { path ->
            modalPatterns.forEach { pattern ->
                assertFalse(
                    "$path must not be presented as a modal, but modal pattern $pattern matches it",
                    Regex(pattern).containsMatchIn(path)
                )
            }
        }
    }

    @Test
    fun `ticket checkout uses main stack while payment summaries and pass purchases stay modal`() {
        val asset = listOf(
            File("src/main/assets/json/path-configuration.json"),
            File("app/src/main/assets/json/path-configuration.json")
        ).first(File::isFile)
        val shared = listOf(
            File("../../shared/path-configuration.json"),
            File("../shared/path-configuration.json")
        ).first(File::isFile)
        val destinations = mapOf(
            "/orders/new" to "default",
            "/orders/new?event_id=34&lang=en&quantity=1&ticket_offer_id=4&step=tickets" to "default",
            "/orders/new?event_id=34&lang=ko" to "default",
            "/orders/42/payment_summary?lang=en" to "modal",
            "/pass_packages/4/purchase?lang=en" to "modal",
            "/pass_packages/4/payment_summary" to "modal",
            "/events/34/reviews/new" to "modal"
        )

        listOf(asset, shared).forEach { configuration ->
            val rules = Json.parseToJsonElement(configuration.readText()).jsonObject.getValue("rules").jsonArray
            destinations.forEach { (path, expectedContext) ->
                val properties = rules.filter { rule ->
                    rule.jsonObject.getValue("patterns").jsonArray.any {
                        Regex(it.jsonPrimitive.content).containsMatchIn(path)
                    }
                }.flatMap { rule ->
                    rule.jsonObject.getValue("properties").jsonObject.entries
                }.associate { it.key to it.value.jsonPrimitive.content }

                assertEquals("$configuration: $path", expectedContext, properties["context"])
                assertEquals(
                    "$configuration: $path fragment",
                    if (expectedContext == "modal") "hotwire://fragment/web/modal" else "hotwire://fragment/web",
                    properties["uri"]
                )
                if (path.startsWith("/orders/new")) {
                    assertEquals("$configuration: $path refresh", "false", properties["pull_to_refresh_enabled"])
                }
            }
        }
    }
}
