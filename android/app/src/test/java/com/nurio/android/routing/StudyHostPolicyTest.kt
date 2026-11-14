package com.nurio.android.routing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StudyHostPolicyTest {
    private val startLocation = "https://nurio.kr/"

    @Test
    fun `study host links open in the system browser`() {
        assertTrue(StudyHostPolicy.opensInSystemBrowser("https://study.nurio.kr/?utm_source=nurio_events", startLocation))
        assertTrue(StudyHostPolicy.opensInSystemBrowser("https://STUDY.nurio.kr/classes", startLocation))
    }

    @Test
    fun `other links stay with the default routing`() {
        assertFalse(StudyHostPolicy.opensInSystemBrowser("https://nurio.kr/events", startLocation))
        assertFalse(StudyHostPolicy.opensInSystemBrowser("https://studyleaders.nurio.kr/", startLocation))
        assertFalse(StudyHostPolicy.opensInSystemBrowser("https://study.example.com/", startLocation))
        assertFalse(StudyHostPolicy.opensInSystemBrowser("nurio://study.nurio.kr/", startLocation))
        assertFalse(StudyHostPolicy.opensInSystemBrowser("not a url", startLocation))
    }
}
