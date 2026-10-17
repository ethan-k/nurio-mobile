package com.nurio.study.android

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test

class PathConfigurationAssetTest {
    @Test
    fun `chat screens disable pull to refresh and keep the default stack`() {
        val android = listOf(
            File("src/main/assets/json/path-configuration.json"),
            File("app/src/main/assets/json/path-configuration.json")
        ).first(File::isFile)
        val ios = listOf(
            File("../../ios/path-configuration.json"),
            File("../ios/path-configuration.json")
        ).first(File::isFile)
        val chatPaths = listOf(
            "/chat",
            "/chat?lang=ko",
            "/study-groups/14/chat",
            "/study-groups/14/chat/88?lang=en",
            "/study_group_admin/chats",
            "/study_group_admin/chats/5"
        )
        val refreshablePaths = listOf("/", "/study-groups/14", "/chatbot")

        listOf(android, ios).forEach { configuration ->
            val rules = Json.parseToJsonElement(configuration.readText()).jsonObject.getValue("rules").jsonArray
            fun propertiesFor(path: String) = rules.filter { rule ->
                rule.jsonObject.getValue("patterns").jsonArray.any {
                    Regex(it.jsonPrimitive.content).containsMatchIn(path)
                }
            }.flatMap { rule ->
                rule.jsonObject.getValue("properties").jsonObject.entries
            }.associate { it.key to it.value.jsonPrimitive.content }

            chatPaths.forEach { path ->
                val properties = propertiesFor(path)
                assertEquals("$configuration: $path refresh", "false", properties["pull_to_refresh_enabled"])
                assertEquals("$configuration: $path context", "default", properties["context"])
            }
            refreshablePaths.forEach { path ->
                assertEquals("$configuration: $path refresh", "true", propertiesFor(path)["pull_to_refresh_enabled"])
            }
        }
    }
}
