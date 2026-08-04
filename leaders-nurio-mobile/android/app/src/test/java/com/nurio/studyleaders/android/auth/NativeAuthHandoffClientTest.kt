package com.nurio.studyleaders.android.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class NativeAuthHandoffClientTest {
    @Test
    fun `callback payload becomes encoded Study Leader auth callback`() {
        assertEquals(
            "nurioleaders://auth-callback?token=signed+token&state=one%2Ftime",
            NativeAuthHandoffClient.callbackUrl(
                """{"token":"signed token","state":"one/time"}"""
            )
        )
    }

    @Test
    fun `blank or malformed handoff payload is rejected`() {
        assertThrows(IllegalArgumentException::class.java) {
            NativeAuthHandoffClient.callbackUrl("""{"token":"","state":"state"}""")
        }
        assertThrows(IllegalArgumentException::class.java) {
            NativeAuthHandoffClient.callbackUrl("""{"unexpected":true}""")
        }
    }
}
