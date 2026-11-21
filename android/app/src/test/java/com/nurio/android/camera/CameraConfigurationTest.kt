package com.nurio.android.camera

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class CameraConfigurationTest {
    @Test
    fun `manifest requests camera permission and makes the camera optional`() {
        val manifest = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
        }.newDocumentBuilder().parse(projectFile("src/main/AndroidManifest.xml"))
        val androidNamespace = "http://schemas.android.com/apk/res/android"
        val permissions = manifest.getElementsByTagName("uses-permission")
        val features = manifest.getElementsByTagName("uses-feature")

        assertTrue((0 until permissions.length).any { index ->
            (permissions.item(index) as Element).getAttributeNS(androidNamespace, "name") ==
                "android.permission.CAMERA"
        })
        val camera = (0 until features.length)
            .map { features.item(it) as Element }
            .single { it.getAttributeNS(androidNamespace, "name") == "android.hardware.camera" }
        assertEquals("false", camera.getAttributeNS(androidNamespace, "required"))
    }

    @Test
    fun `web fragment wires the camera host and live WebView location`() {
        val fragment = projectFile("src/main/java/com/nurio/android/fragments/WebFragment.kt").readText()

        assertTrue(fragment.contains("cameraPermissionHost = permissionHost as? CameraPermissionHost"))
        assertTrue(fragment.contains("currentLocation = { session.webView.url }"))
    }

    @Test
    fun `camera settings recovery ships the Human Bingo message in Korean and English`() {
        val korean = projectFile("src/main/res/values/strings.xml").readText()
        val english = projectFile("src/main/res/values-en/strings.xml").readText()
        val title = "camera_permission_settings_title"
        val message = "camera_permission_settings_message"

        assertTrue(korean.contains("name=\"$title\""))
        assertTrue(english.contains("name=\"$title\""))
        assertTrue(korean.contains(
            "name=\"$message\">휴먼 빙고 QR 코드를 스캔하려면 설정에서 nurio의 카메라 권한을 허용해 주세요.</string>"
        ))
        assertTrue(english.contains(
            "name=\"$message\">To scan Human Bingo QR codes, allow nurio to use the camera in Settings.</string>"
        ))
    }

    private fun projectFile(relativePath: String): File {
        return listOf(File(relativePath), File("app/$relativePath")).firstOrNull(File::isFile)
            ?: error("Missing Android project file: $relativePath")
    }
}
