package com.nurio.study.android.microphone

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AiPracticeNativeConfigurationTest {
    @Test
    fun `manifest declares microphone permissions`() {
        val manifest = projectFile("src/main/AndroidManifest.xml").readText()

        assertTrue(manifest.contains("android.permission.RECORD_AUDIO"))
        assertTrue(manifest.contains("android.permission.MODIFY_AUDIO_SETTINGS"))
    }

    @Test
    fun `AI practice sessions keep default context and disable pull to refresh`() {
        val rules = Json.parseToJsonElement(
            projectFile("src/main/assets/json/path-configuration.json").readText()
        ).jsonObject.getValue("rules").jsonArray

        val practiceRule = rules.firstOrNull { rule ->
            rule.jsonObject.getValue("patterns").jsonArray
                .map { it.jsonPrimitive.content }
                .contains("/practice/\\d+(?:\\?.*)?$")
        }

        assertNotNull("AI practice path rule is missing", practiceRule)
        val properties = practiceRule!!.jsonObject.getValue("properties").jsonObject
        assertEquals("default", properties.getValue("context").jsonPrimitive.content)
        assertEquals("hotwire://fragment/web", properties.getValue("uri").jsonPrimitive.content)
        assertFalse(properties.getValue("pull_to_refresh_enabled").jsonPrimitive.boolean)
    }

    @Test
    fun `web fragment supplies the live shared WebView location to microphone policy`() {
        val fragment = projectFile(
            "src/main/java/com/nurio/study/android/fragments/WebFragment.kt"
        ).readText()

        assertTrue(fragment.contains("currentLocation = { session.webView.url }"))
    }

    private fun projectFile(relativePath: String): File {
        return listOf(File(relativePath), File("app/$relativePath")).firstOrNull(File::isFile)
            ?: error("Missing Android project file: $relativePath")
    }
}
