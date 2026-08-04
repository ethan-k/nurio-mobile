package com.nurio.studyleaders.android.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NativeAuthCallbackTest {
    @Test
    fun buildsTokenAuthUrlForValidLeaderCallback() {
        val result = NativeAuthCallback.toTokenAuthUrl(
            "nurioleaders://auth-callback?token=test-token&state=test-state",
            "https://studyleaders.nurio.kr"
        )

        assertEquals(
            "https://studyleaders.nurio.kr/auth/native/token_auth?token=test-token&state=test-state",
            result
        )
    }

    @Test
    fun rejectsWrongSchemeAndDuplicateCredentials() {
        assertNull(
            NativeAuthCallback.toTokenAuthUrl(
                "nurio://auth-callback?token=test-token&state=test-state",
                "https://studyleaders.nurio.kr"
            )
        )
        assertNull(
            NativeAuthCallback.toTokenAuthUrl(
                "nurioleaders://auth-callback?token=one&token=two&state=test-state",
                "https://studyleaders.nurio.kr"
            )
        )
    }
}
