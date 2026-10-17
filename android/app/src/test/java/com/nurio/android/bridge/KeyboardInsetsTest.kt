package com.nurio.android.bridge

import org.junit.Assert.assertEquals
import org.junit.Test

class KeyboardInsetsTest {
    @Test
    fun `converts the keyboard overlap from device pixels to css pixels`() {
        assertEquals(300, KeyboardInsets.cssPixels(imeBottomPx = 900, density = 3f))
    }

    @Test
    fun `rounds fractional densities to the nearest css pixel`() {
        assertEquals(292, KeyboardInsets.cssPixels(imeBottomPx = 802, density = 2.75f))
    }

    @Test
    fun `reports zero when the keyboard is hidden or the density is unusable`() {
        assertEquals(0, KeyboardInsets.cssPixels(imeBottomPx = 0, density = 2f))
        assertEquals(0, KeyboardInsets.cssPixels(imeBottomPx = -12, density = 2f))
        assertEquals(0, KeyboardInsets.cssPixels(imeBottomPx = 600, density = 0f))
    }
}
