package com.nurio.studyleaders.android.routing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LeaderScopePolicyTest {
    private val appUrl = "https://studyleaders.nurio.kr"

    @Test
    fun keepsLeaderRoutesInApp() {
        assertFalse(LeaderScopePolicy.shouldOpenExternally("/schedule", appUrl))
        assertFalse(LeaderScopePolicy.shouldOpenExternally("/pair-practice-sessions", appUrl))
    }

    @Test
    fun opensAdminAndOtherHostsExternally() {
        assertTrue(LeaderScopePolicy.shouldOpenExternally("/admin/events", appUrl))
        assertTrue(
            LeaderScopePolicy.shouldOpenExternally(
                "https://study.nurio.kr/study-groups",
                appUrl
            )
        )
        assertTrue(
            LeaderScopePolicy.shouldOpenExternally(
                "https://example.com/support",
                appUrl
            )
        )
    }
}
