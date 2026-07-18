package com.nurio.study.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class PushRegistrationResultTest {
    @Test
    fun `serializes a successful Android token without an error`() {
        assertEquals(
            "{\"token\":\"fcm-token\",\"platform\":\"android\"}",
            PushRegistrationResult.success(" fcm-token ").json
        )
    }

    @Test
    fun `serializes stable errors without raw exception details`() {
        PushRegistrationError.entries.forEach { error ->
            val result = PushRegistrationResult.failure(error)

            assertEquals(
                "{\"platform\":\"android\",\"error\":\"${error.wireValue}\"}",
                result.json
            )
            assertFalse(result.json.contains("FirebaseException"))
        }
    }

    @Test
    fun `maps blank tokens to token unavailable`() {
        assertEquals(
            PushRegistrationError.TOKEN_UNAVAILABLE,
            PushRegistrationResult.fromToken(" ").error
        )
    }
}
