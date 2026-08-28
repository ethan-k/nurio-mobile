package com.nurio.android.payments

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentRecoveryCoordinatorTest {
    private val repository = FakePaymentRecoveryRepository()
    private var now = 1_000L
    private val coordinator = PaymentRecoveryCoordinator(
        repository = repository,
        baseUrl = "https://nurio.kr",
        clock = { now },
        recoveryTtlMillis = 60_000L,
    )

    @Test
    fun `gateway handoff remembers the payment and exact event detail`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-123",
            sourceLocation = "https://nurio.kr/events/42?lang=ko",
        )
        coordinator.markExternalAppHandoff()

        val recovery = coordinator.takeExternalAppReturnRecovery()

        assertEquals("payment-123", recovery?.paymentId)
        assertEquals("/events/42", recovery?.eventPath)
        assertNull(coordinator.takeExternalAppReturnRecovery())
    }

    @Test
    fun `pass checkout recovers the exact event from redirect uri`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-456",
            sourceLocation = "https://nurio.kr/pass_packages/3/payment_summary?order_id=9&redirect_uri=%2Fevents%2F77",
        )

        val recovery = coordinator.takeLaunchFailureRecovery()

        assertEquals("payment-456", recovery?.paymentId)
        assertEquals("/events/77", recovery?.eventPath)
    }

    @Test
    fun `generic events path is never stored as an event recovery destination`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-789",
            sourceLocation = "https://nurio.kr/events",
        )

        assertNull(coordinator.takeLaunchFailureRecovery()?.eventPath)
    }

    @Test
    fun `callback without payment id uses the active attempt and preserves its event`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-active",
            sourceLocation = "https://nurio.kr/events/88",
        )
        coordinator.markExternalAppHandoff()

        val recovery = coordinator.resolveCallback(paymentId = null)

        assertEquals("payment-active", recovery?.paymentId)
        assertEquals("/events/88", recovery?.eventPath)
        assertNull(coordinator.takeExternalAppReturnRecovery())
    }

    @Test
    fun `callback payment id wins over a stored attempt id`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-old",
            sourceLocation = "https://nurio.kr/events/91",
        )

        val recovery = coordinator.resolveCallback(paymentId = "payment-callback")

        assertEquals("payment-callback", recovery?.paymentId)
        assertEquals("/events/91", recovery?.eventPath)
    }

    @Test
    fun `completion verification prevents resume recovery from racing the web callback`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-123",
            sourceLocation = "https://nurio.kr/events/42",
        )
        coordinator.markExternalAppHandoff()

        coordinator.track(
            stage = "completion_verifying",
            paymentReference = "payment-123",
            sourceLocation = "https://nurio.kr/events/42",
        )

        assertTrue(coordinator.hasActiveAttempt())
        assertNull(coordinator.takeExternalAppReturnRecovery())
    }

    @Test
    fun `finished flow clears private recovery state`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-123",
            sourceLocation = "https://nurio.kr/events/42",
        )

        coordinator.track(
            stage = "flow_finished",
            paymentReference = null,
            sourceLocation = "https://nurio.kr/events/42",
        )

        assertFalse(coordinator.hasActiveAttempt())
        assertNull(repository.load())
    }

    @Test
    fun `expired attempt is removed instead of being reconciled`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-expired",
            sourceLocation = "https://nurio.kr/events/42",
        )
        coordinator.markExternalAppHandoff()
        now += 60_001L

        assertNull(coordinator.takeExternalAppReturnRecovery())
        assertNull(repository.load())
    }

    @Test
    fun `invalid payment references are not persisted`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "   ",
            sourceLocation = "https://nurio.kr/events/42",
        )

        assertNull(repository.load())
        assertFalse(coordinator.hasPendingExternalAppHandoff())
    }

    @Test
    fun `external app handoff is exposed only for a current unclaimed attempt`() {
        coordinator.track(
            stage = "gateway_handoff",
            paymentReference = "payment-123",
            sourceLocation = "https://nurio.kr/events/42",
        )

        assertFalse(coordinator.hasPendingExternalAppHandoff())
        coordinator.markExternalAppHandoff()
        assertTrue(coordinator.hasPendingExternalAppHandoff())
        coordinator.takeExternalAppReturnRecovery()
        assertFalse(coordinator.hasPendingExternalAppHandoff())
    }

    private class FakePaymentRecoveryRepository : PaymentRecoveryRepository {
        private var attempt: PendingPaymentRecovery? = null

        override fun load(): PendingPaymentRecovery? = attempt

        override fun save(attempt: PendingPaymentRecovery) {
            this.attempt = attempt
        }

        override fun clear() {
            attempt = null
        }
    }
}
