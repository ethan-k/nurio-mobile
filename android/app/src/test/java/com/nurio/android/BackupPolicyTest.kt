package com.nurio.android

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class BackupPolicyTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"
    private val domains = setOf("root", "file", "database", "sharedpref", "external")
    private val parser = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = true
    }.newDocumentBuilder()

    @Test
    fun `all Android shells exclude app state from backup and device transfer`() {
        val repository = generateSequence(File(".").canonicalFile) { it.parentFile }
            .first { File(it, "android/app/src/main/AndroidManifest.xml").isFile }
        val shells = listOf(
            "android",
            "study-nurio-mobile/android",
            "leaders-nurio-mobile/android",
            "tutors-nurio-mobile/android"
        )

        for (shell in shells) {
            val main = File(repository, "$shell/app/src/main")
            val manifest = parser.parse(File(main, "AndroidManifest.xml")).documentElement
            val application = manifest.children("application").single()
            assertEquals(shell, "false", application.getAttributeNS(androidNamespace, "allowBackup"))

            val extractionRules = readRules(main, application, "dataExtractionRules", "data-extraction-rules")
            for (section in listOf("cloud-backup", "device-transfer")) {
                val sections = extractionRules.children(section)
                assertEquals("$shell <$section> count", 1, sections.size)
                assertWholeDomainExclusions("$shell <$section>", sections.single())
            }

            val legacyRules = readRules(main, application, "fullBackupContent", "full-backup-content")
            assertWholeDomainExclusions("$shell <full-backup-content>", legacyRules)
        }
    }

    private fun readRules(main: File, application: Element, attribute: String, rootTag: String): Element {
        val reference = application.getAttributeNS(androidNamespace, attribute)
        val resource = requireNotNull(Regex("@xml/([a-z0-9_]+)").matchEntire(reference)) {
            "$main AndroidManifest.xml must reference an XML resource for $attribute"
        }.groupValues[1]
        val file = File(main, "res/xml/$resource.xml")
        val root = parser.parse(file).documentElement
        assertEquals(file.path, rootTag, root.tagName)
        assertEquals("$file <include> count", 0, root.getElementsByTagName("include").length)
        return root
    }

    private fun assertWholeDomainExclusions(location: String, section: Element) {
        val excluded = section.children("exclude")
            .filter { it.getAttribute("path") == "." && it.getAttribute("requireFlags").isEmpty() }
            .map { it.getAttribute("domain") }
            .toSet()
        val missing = domains - excluded
        assertTrue("$location is missing whole-domain exclusions for $missing", missing.isEmpty())
    }

    private fun Element.children(tag: String): List<Element> {
        val elements = getElementsByTagName(tag)
        return (0 until elements.length)
            .map { elements.item(it) as Element }
            .filter { it.parentNode == this }
    }
}
