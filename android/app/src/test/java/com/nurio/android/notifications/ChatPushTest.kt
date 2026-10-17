package com.nurio.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ChatPushTest {
    private val payload = mapOf(
        "kind" to "chat",
        "title" to "Friday Seoul Meetup",
        "body" to "See you at 7!",
        "sender_name" to "Minji",
        "path" to "/events/42/chat",
        "url" to "https://nurio.kr/events/42/chat",
        "tag" to "chat-room-123",
        "chat_room_id" to "123",
        "sent_at" to "2026-10-17T09:30:00Z",
    )

    @Test
    fun `parses a data-only chat push`() {
        val push = ChatPush.from(payload, fallbackTitle = "nurio", now = 0L)!!

        assertEquals("Friday Seoul Meetup", push.title)
        assertEquals("See you at 7!", push.body)
        assertEquals("Minji", push.senderName)
        assertEquals("/events/42/chat", push.path)
        assertEquals("chat-room-123", push.tag)
        assertEquals(1_792_229_400_000L, push.sentAtMillis)
    }

    @Test
    fun `ignores payloads that are not chat messages`() {
        assertNull(ChatPush.from(payload + ("kind" to "event_reminder"), fallbackTitle = "nurio", now = 0L))
        assertNull(ChatPush.from(payload - "kind", fallbackTitle = "nurio", now = 0L))
        assertNull(ChatPush.from(payload - "body", fallbackTitle = "nurio", now = 0L))
    }

    @Test
    fun `falls back when optional fields are missing or malformed`() {
        val push = ChatPush.from(
            payload - "sender_name" - "tag" - "path" + ("sent_at" to "yesterday"),
            fallbackTitle = "nurio",
            now = 42L,
        )!!

        assertEquals("Friday Seoul Meetup", push.senderName)
        assertEquals("chat-room-123", push.tag)
        assertEquals("https://nurio.kr/events/42/chat", push.path)
        assertEquals(42L, push.sentAtMillis)
    }

    @Test
    fun `uses the app name when the room title is missing`() {
        val push = ChatPush.from(payload - "title" - "sender_name", fallbackTitle = "nurio", now = 0L)!!

        assertEquals("nurio", push.title)
        assertEquals("nurio", push.senderName)
    }
}
