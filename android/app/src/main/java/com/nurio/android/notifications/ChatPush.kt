package com.nurio.android.notifications

import java.time.OffsetDateTime
import java.time.format.DateTimeParseException

/**
 * A data-only chat push. The server sends these (no `notification` block) only to
 * builds that advertise `nurio-messaging-style/1` in their user agent, so the app can
 * stack every message of a room into one MessagingStyle notification.
 */
internal data class ChatPush(
    val title: String,
    val body: String,
    val senderName: String,
    val path: String,
    val tag: String,
    val sentAtMillis: Long,
) {
    companion object {
        const val KIND = "chat"

        fun from(data: Map<String, String>, fallbackTitle: String, now: Long): ChatPush? {
            if (data["kind"] != KIND) return null
            val body = data.value("body") ?: return null
            val title = data.value("title") ?: fallbackTitle
            val path = data.value("path") ?: data.value("url") ?: "/"
            val tag = data.value("tag")
                ?: data.value("chat_room_id")?.let { "chat-room-$it" }
                ?: path

            return ChatPush(
                title = title,
                body = body,
                senderName = data.value("sender_name") ?: title,
                path = path,
                tag = tag,
                sentAtMillis = data.value("sent_at")?.let(::parseMillis) ?: now,
            )
        }

        private fun Map<String, String>.value(key: String): String? =
            get(key)?.trim()?.takeIf { it.isNotEmpty() }

        private fun parseMillis(value: String): Long? = try {
            OffsetDateTime.parse(value).toInstant().toEpochMilli()
        } catch (_: DateTimeParseException) {
            null
        }
    }
}
