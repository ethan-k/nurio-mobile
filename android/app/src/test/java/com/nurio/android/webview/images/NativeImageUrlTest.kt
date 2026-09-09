package com.nurio.android.webview.images

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeImageUrlTest {
    @Test
    fun `mapping preserves the complete signed path and query`() {
        assertEquals(
            "https://nurio.kr/rails/active_storage/blobs/proxy/abc/photo%20name.png?signature=a%2Fb%3D&size=960",
            NativeImageUrl.original("nurio-image://nurio.kr/rails/active_storage/blobs/proxy/abc/photo%20name.png?signature=a%2Fb%3D&size=960")
        )
        assertEquals("https://images.example.com:443/photo.webp?v=2", NativeImageUrl.original("nurio-image://images.example.com:443/photo.webp?v=2"))
        assertTrue(NativeImageUrl.isAllowedHttps("https://8.8.8.8/image.png"))
        assertTrue(NativeImageUrl.isAllowedHttps("https://[2606:4700:4700::1111]/image.png"))
    }

    @Test
    fun `normal page and payment requests are never mapped`() {
        listOf("https://nurio.kr/events/42", "intent://pay", "nurio://payment-complete", "http://nurio.kr/image.png").forEach {
            assertFalse(it, NativeImageUrl.isImageRequest(it))
            assertNull(it, NativeImageUrl.original(it))
        }
    }

    @Test
    fun `private and credentialed destinations are rejected for downloads and redirects`() {
        listOf(
            "http://images.example.com/photo.png", "https://user:secret@images.example.com/p.png",
            "https://images.example.com:8443/p.png", "https://localhost/p.png", "https://localhost./p.png",
            "https://app.localhost/p.png", "https://printer.local/p.png", "https://intranet/p.png",
            "https://127.0.0.1/p.png", "https://127.1/p.png", "https://0177.0.0.1/p.png",
            "https://0x7f000001/p.png", "https://0x7f.0.0.1/p.png", "https://2130706433/p.png",
            "https://10.0.0.1/p.png", "https://172.16.0.1/p.png", "https://192.168.1.1/p.png",
            "https://169.254.169.254/p.png", "https://100.64.0.1/p.png", "https://0.0.0.0/p.png",
            "https://[::1]/p.png", "https://[::]/p.png", "https://[fe80::1]/p.png",
            "https://[fc00::1]/p.png", "https://[::ffff:127.0.0.1]/p.png", "https://[::ffff:10.0.0.1]/p.png"
        ).forEach { assertFalse(it, NativeImageUrl.isAllowedHttps(it)) }
    }
}
