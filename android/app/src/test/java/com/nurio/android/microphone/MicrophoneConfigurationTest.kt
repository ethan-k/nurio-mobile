package com.nurio.android.microphone

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class MicrophoneConfigurationTest {
    @Test
    fun `manifest declares the record audio permission`() {
        val manifest = projectFile("src/main/AndroidManifest.xml").readText()

        assertTrue(manifest.contains("<uses-permission android:name=\"android.permission.RECORD_AUDIO\" />"))
    }

    @Test
    fun `web fragment supplies the live shared WebView location to the microphone policy`() {
        val fragment = projectFile("src/main/java/com/nurio/android/fragments/WebFragment.kt").readText()

        assertTrue(fragment.contains("MicrophoneWebChromeClient("))
        assertTrue(fragment.contains("currentLocation = { session.webView.url }"))
    }

    @Test
    fun `microphone settings recovery ships Korean defaults and English resources`() {
        val korean = projectFile("src/main/res/values/strings.xml").readText()
        val english = projectFile("src/main/res/values-en/strings.xml").readText()

        listOf(
            "microphone_permission_settings_title",
            "microphone_permission_settings_message",
            "microphone_permission_settings_cancel",
            "microphone_permission_settings_open"
        ).forEach { name ->
            assertTrue(name, korean.contains("name=\"$name\""))
            assertTrue(name, english.contains("name=\"$name\""))
        }
    }

    private fun projectFile(relativePath: String): File {
        return listOf(File(relativePath), File("app/$relativePath")).firstOrNull(File::isFile)
            ?: error("Missing Android project file: $relativePath")
    }
}
