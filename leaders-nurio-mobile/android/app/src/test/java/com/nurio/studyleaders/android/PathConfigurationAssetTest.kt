package com.nurio.studyleaders.android

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PathConfigurationAssetTest {
    @Test
    fun `bundled path configuration exists and keeps auth routes modal`() {
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

        val authRule = rules.firstOrNull { rule ->
            val patterns = rule.jsonObject.getValue("patterns").jsonArray
                .map { it.jsonPrimitive.content }
            "/login.*" in patterns && "/signup.*" in patterns && "/auth/.*" in patterns
        } ?: error("Study Leader login/auth modal rule is missing")

        assertEquals(
            "hotwire://fragment/web/modal",
            authRule.jsonObject
                .getValue("properties")
                .jsonObject
                .getValue("uri")
                .jsonPrimitive
                .content
        )
        assertEquals(
            "false",
            authRule.jsonObject
                .getValue("properties")
                .jsonObject
                .getValue("pull_to_refresh_enabled")
                .jsonPrimitive
                .content
        )
    }
}
