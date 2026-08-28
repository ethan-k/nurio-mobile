package com.nurio.android.payments

import android.content.Context
import android.content.SharedPreferences
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

internal data class PendingPaymentRecovery(
    val paymentId: String,
    val eventPath: String?,
    val startedAtMillis: Long,
    val externalAppHandoff: Boolean = false,
    val recoveryClaimed: Boolean = false,
)

internal interface PaymentRecoveryRepository {
    fun load(): PendingPaymentRecovery?
    fun save(attempt: PendingPaymentRecovery)
    fun clear()
}

internal class PaymentRecoveryCoordinator(
    private val repository: PaymentRecoveryRepository,
    baseUrl: String,
    private val clock: () -> Long = System::currentTimeMillis,
    private val recoveryTtlMillis: Long = DEFAULT_RECOVERY_TTL_MILLIS,
) {
    private val baseUri = URI(baseUrl)

    @Synchronized
    fun track(stage: String?, paymentReference: String?, sourceLocation: String?) {
        when (stage) {
            "gateway_handoff" -> {
                val paymentId = sanitizePaymentId(paymentReference) ?: return
                repository.save(
                    PendingPaymentRecovery(
                        paymentId = paymentId,
                        eventPath = exactEventPath(sourceLocation),
                        startedAtMillis = clock(),
                    )
                )
            }

            "completion_verifying" -> updateCurrentAttempt(paymentReference) { attempt ->
                attempt.copy(externalAppHandoff = false, recoveryClaimed = true)
            }

            "flow_finished" -> repository.clear()
        }
    }

    @Synchronized
    fun markExternalAppHandoff() {
        val attempt = currentAttempt() ?: return
        if (attempt.recoveryClaimed) return

        repository.save(attempt.copy(externalAppHandoff = true))
    }

    @Synchronized
    fun hasPendingExternalAppHandoff(): Boolean {
        val attempt = currentAttempt() ?: return false
        return attempt.externalAppHandoff && !attempt.recoveryClaimed
    }

    @Synchronized
    fun hasActiveAttempt(): Boolean = currentAttempt() != null

    @Synchronized
    fun takeExternalAppReturnRecovery(): PendingPaymentRecovery? {
        val attempt = currentAttempt() ?: return null
        if (!attempt.externalAppHandoff || attempt.recoveryClaimed) return null

        return claim(attempt)
    }

    @Synchronized
    fun takeLaunchFailureRecovery(): PendingPaymentRecovery? {
        val attempt = currentAttempt() ?: return null
        if (attempt.recoveryClaimed) return null

        return claim(attempt)
    }

    @Synchronized
    fun resolveCallback(paymentId: String?): PendingPaymentRecovery? {
        val callbackPaymentId = sanitizePaymentId(paymentId)
        val storedAttempt = currentAttempt()
        if (callbackPaymentId == null && storedAttempt == null) return null

        val resolved = if (storedAttempt == null) {
            PendingPaymentRecovery(
                paymentId = callbackPaymentId!!,
                eventPath = null,
                startedAtMillis = clock(),
                recoveryClaimed = true,
            )
        } else {
            storedAttempt.copy(
                paymentId = callbackPaymentId ?: storedAttempt.paymentId,
                externalAppHandoff = false,
                recoveryClaimed = true,
            )
        }

        repository.save(resolved)
        return resolved
    }

    @Synchronized
    fun clear() {
        repository.clear()
    }

    private fun claim(attempt: PendingPaymentRecovery): PendingPaymentRecovery {
        val claimed = attempt.copy(externalAppHandoff = false, recoveryClaimed = true)
        repository.save(claimed)
        return claimed
    }

    private fun updateCurrentAttempt(
        paymentReference: String?,
        update: (PendingPaymentRecovery) -> PendingPaymentRecovery,
    ) {
        val attempt = currentAttempt() ?: return
        val normalizedReference = sanitizePaymentId(paymentReference)
        if (normalizedReference != null && normalizedReference != attempt.paymentId) return

        repository.save(update(attempt))
    }

    private fun currentAttempt(): PendingPaymentRecovery? {
        val attempt = repository.load() ?: return null
        val age = clock() - attempt.startedAtMillis
        if (age < 0 || age > recoveryTtlMillis) {
            repository.clear()
            return null
        }

        return attempt
    }

    private fun exactEventPath(sourceLocation: String?): String? {
        val source = sourceLocation?.takeIf(String::isNotBlank) ?: return null
        val uri = runCatching { URI(source) }.getOrNull() ?: return null
        if (!isAppHost(uri.host)) return null

        normalizeEventPath(uri.path)?.let { return it }

        return uri.rawQuery
            ?.split("&")
            ?.asSequence()
            ?.mapNotNull { pair ->
                val separator = pair.indexOf('=')
                val rawName = if (separator >= 0) pair.substring(0, separator) else pair
                val rawValue = if (separator >= 0) pair.substring(separator + 1) else ""
                decode(rawName) to decode(rawValue)
            }
            ?.firstOrNull { (name, _) -> name == "redirect_uri" }
            ?.second
            ?.let(::normalizeEventPath)
    }

    private fun isAppHost(host: String?): Boolean {
        val normalizedHost = host?.lowercase() ?: return false
        val baseHost = baseUri.host?.lowercase() ?: return false
        return normalizedHost == baseHost || normalizedHost == "www.$baseHost"
    }

    private fun normalizeEventPath(path: String?): String? {
        val match = EVENT_DETAIL_PATH.matchEntire(path.orEmpty()) ?: return null
        return "/events/${match.groupValues[1]}"
    }

    private fun sanitizePaymentId(value: String?): String? {
        val paymentId = value?.trim()?.takeIf(String::isNotEmpty) ?: return null
        return paymentId.takeIf { PAYMENT_ID.matches(it) }
    }

    private fun decode(value: String): String? = runCatching {
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())
    }.getOrNull()

    private companion object {
        const val DEFAULT_RECOVERY_TTL_MILLIS = 2 * 60 * 60 * 1_000L
        val EVENT_DETAIL_PATH = Regex("^/events/([1-9][0-9]*)/?$")
        val PAYMENT_ID = Regex("^[A-Za-z0-9_-]{1,160}$")
    }
}

private class SharedPreferencesPaymentRecoveryRepository(
    private val preferences: SharedPreferences,
) : PaymentRecoveryRepository {
    override fun load(): PendingPaymentRecovery? {
        val paymentId = preferences.getString(KEY_PAYMENT_ID, null)?.takeIf(String::isNotBlank)
            ?: return null

        return PendingPaymentRecovery(
            paymentId = paymentId,
            eventPath = preferences.getString(KEY_EVENT_PATH, null),
            startedAtMillis = preferences.getLong(KEY_STARTED_AT, 0L),
            externalAppHandoff = preferences.getBoolean(KEY_EXTERNAL_HANDOFF, false),
            recoveryClaimed = preferences.getBoolean(KEY_RECOVERY_CLAIMED, false),
        )
    }

    override fun save(attempt: PendingPaymentRecovery) {
        preferences.edit()
            .putString(KEY_PAYMENT_ID, attempt.paymentId)
            .putString(KEY_EVENT_PATH, attempt.eventPath)
            .putLong(KEY_STARTED_AT, attempt.startedAtMillis)
            .putBoolean(KEY_EXTERNAL_HANDOFF, attempt.externalAppHandoff)
            .putBoolean(KEY_RECOVERY_CLAIMED, attempt.recoveryClaimed)
            .apply()
    }

    override fun clear() {
        preferences.edit().clear().apply()
    }

    private companion object {
        const val KEY_PAYMENT_ID = "payment_id"
        const val KEY_EVENT_PATH = "event_path"
        const val KEY_STARTED_AT = "started_at"
        const val KEY_EXTERNAL_HANDOFF = "external_app_handoff"
        const val KEY_RECOVERY_CLAIMED = "recovery_claimed"
    }
}

internal object PaymentRecovery {
    private var coordinator: PaymentRecoveryCoordinator? = null

    @Synchronized
    fun initialize(context: Context, baseUrl: String) {
        if (coordinator != null) return

        val preferences = context.applicationContext.getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
        coordinator = PaymentRecoveryCoordinator(
            repository = SharedPreferencesPaymentRecoveryRepository(preferences),
            baseUrl = baseUrl,
        )
    }

    fun track(stage: String?, paymentReference: String?, sourceLocation: String?) {
        coordinator?.track(stage, paymentReference, sourceLocation)
    }

    fun markExternalAppHandoff() {
        coordinator?.markExternalAppHandoff()
    }

    fun hasPendingExternalAppHandoff(): Boolean =
        coordinator?.hasPendingExternalAppHandoff() == true

    fun hasActiveAttempt(): Boolean = coordinator?.hasActiveAttempt() == true

    fun takeExternalAppReturnRecovery(): PendingPaymentRecovery? =
        coordinator?.takeExternalAppReturnRecovery()

    fun takeLaunchFailureRecovery(): PendingPaymentRecovery? =
        coordinator?.takeLaunchFailureRecovery()

    fun resolveCallback(paymentId: String?): PendingPaymentRecovery? =
        coordinator?.resolveCallback(paymentId)

    fun clear() {
        coordinator?.clear()
    }

    private const val PREFERENCES_NAME = "nurio_payment_recovery"
}
