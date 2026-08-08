package com.nurio.study.android.microphone

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class MicrophonePermissionBackupRulesTest {
    private val legacyPreferencesFile = "nurio_study_microphone.xml"

    @Test
    fun `legacy microphone request marker is excluded from Android backups`() {
        listOf(
            projectFile("src/main/res/xml/backup_rules.xml"),
            projectFile("src/main/res/xml/data_extraction_rules.xml")
        ).forEach { rulesFile ->
            val excludedSharedPreferences = excludedSharedPreferences(rulesFile)

            assertTrue(
                "${rulesFile.name} must exclude $legacyPreferencesFile",
                legacyPreferencesFile in excludedSharedPreferences
            )
        }
    }

    @Test
    fun `activity removes any marker restored by an older backup`() {
        val activity = projectFile(
            "src/main/java/com/nurio/study/android/MainActivity.kt"
        ).readText()

        assertTrue(
            activity.contains(
                "deleteSharedPreferences(LEGACY_MICROPHONE_PERMISSION_PREFERENCES)"
            )
        )
    }

    private fun excludedSharedPreferences(rulesFile: File): Set<String> {
        val document = DocumentBuilderFactory.newInstance()
            .newDocumentBuilder()
            .parse(rulesFile)
        val exclusions = document.getElementsByTagName("exclude")

        return buildSet {
            for (index in 0 until exclusions.length) {
                val exclusion = exclusions.item(index) as Element
                if (exclusion.getAttribute("domain") == "sharedpref") {
                    add(exclusion.getAttribute("path"))
                }
            }
        }
    }

    private fun projectFile(relativePath: String): File {
        return listOf(File(relativePath), File("app/$relativePath")).firstOrNull(File::isFile)
            ?: error("Missing Android project file: $relativePath")
    }
}
