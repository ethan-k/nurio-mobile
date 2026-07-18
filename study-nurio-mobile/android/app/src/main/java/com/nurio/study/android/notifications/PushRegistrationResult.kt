package com.nurio.study.android.notifications

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

enum class PushRegistrationError(val wireValue: String) {
    FIREBASE_NOT_CONFIGURED("firebase_not_configured"),
    NOTIFICATION_PERMISSION_DENIED("notification_permission_denied"),
    NOTIFICATION_PERMISSION_FAILED("notification_permission_failed"),
    TOKEN_UNAVAILABLE("token_unavailable")
}

class PushRegistrationResult private constructor(
    val token: String? = null,
    val platform: String = "android",
    private val errorValue: String? = null
) {
    val error: PushRegistrationError?
        get() = errorValue?.let { value ->
            PushRegistrationError.entries.firstOrNull { it.wireValue == value }
        }

    val json: String
        get() = serializer.encodeToString(WirePayload(token, platform, errorValue))

    companion object {
        private val serializer = Json {
            encodeDefaults = true
            explicitNulls = false
        }

        fun success(token: String): PushRegistrationResult = fromToken(token)

        fun fromToken(token: String?): PushRegistrationResult {
            val normalized = token?.trim()?.takeIf(String::isNotEmpty)
                ?: return failure(PushRegistrationError.TOKEN_UNAVAILABLE)
            return PushRegistrationResult(token = normalized)
        }

        fun failure(error: PushRegistrationError): PushRegistrationResult =
            PushRegistrationResult(errorValue = error.wireValue)
    }

    @Serializable
    private data class WirePayload(
        val token: String? = null,
        val platform: String,
        val error: String? = null
    )
}
