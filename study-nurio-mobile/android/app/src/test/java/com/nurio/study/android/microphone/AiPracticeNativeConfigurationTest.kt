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

    @Test
    fun `microphone settings recovery ships Korean defaults and English resources`() {
        val koreanDefaults = projectFile("src/main/res/values/strings.xml").readText()
        val english = projectFile("src/main/res/values-en/strings.xml").readText()

        val expectedResourceNames = listOf(
            "microphone_permission_settings_title",
            "microphone_permission_settings_message",
            "microphone_permission_settings_cancel",
            "microphone_permission_settings_open"
        )
        expectedResourceNames.forEach { resourceName ->
            assertTrue(koreanDefaults.contains("name=\"$resourceName\""))
            assertTrue(english.contains("name=\"$resourceName\""))
        }

        assertTrue(koreanDefaults.contains("마이크 권한이 필요해요"))
        assertTrue(koreanDefaults.contains("AI 영어회화 연습을 시작하려면 설정에서 Nurio Study의 마이크 권한을 허용해 주세요."))
        assertTrue(koreanDefaults.contains("나중에"))
        assertTrue(koreanDefaults.contains("설정 열기"))
        assertTrue(english.contains("Microphone access needed"))
        assertTrue(english.contains("To start AI English conversation practice, allow Nurio Study to use the microphone in Settings."))
        assertTrue(english.contains("Not now"))
        assertTrue(english.contains("Open Settings"))
    }

    private fun projectFile(relativePath: String): File {
        return listOf(File(relativePath), File("app/$relativePath")).firstOrNull(File::isFile)
            ?: error("Missing Android project file: $relativePath")
    }
}
