package com.nurio.android.webview.images

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

class PersistentImageCacheTest {
    @get:Rule val temporary = TemporaryFolder()
    private val url = "https://images.example.com/event.png?v=1"
    private val image = CachedImage("complete image".toByteArray(), "image/png")
    private val validator = ImageValidator { it.mimeType.takeIf { _ -> it.bytes.contentEquals(image.bytes) } }

    @Test
    fun `loaded bytes survive cache recreation and never revalidate over the network`() {
        val directory = temporary.newFolder()
        val fetches = AtomicInteger()
        val fetcher = ImageFetcher { _, _ -> fetches.incrementAndGet(); image }
        val first = PersistentImageCache(directory, fetcher, validator)
        assertArrayEquals(image.bytes, first.load(url).bytes)
        assertArrayEquals(image.bytes, first.load(url).bytes)
        directory.listFiles()!!.forEach { it.setLastModified(1) }
        val recreated = PersistentImageCache(directory, ImageFetcher { _, _ -> throw IOException("Offline") }, validator)
        assertArrayEquals(image.bytes, recreated.load(url).bytes)
        assertEquals(1, fetches.get())
    }

    @Test
    fun `failed and invalid first downloads are not saved and can recover on the next attempt`() {
        val directory = temporary.newFolder()
        val fetches = AtomicInteger()
        val cache = PersistentImageCache(directory, ImageFetcher { _, _ ->
            when (fetches.incrementAndGet()) {
                1 -> throw IOException("Offline")
                2 -> CachedImage("truncated".toByteArray(), "image/png")
                else -> image
            }
        }, validator)
        assertThrows(IOException::class.java) { cache.load(url) }
        assertEquals(0, directory.listFiles()!!.size)
        assertThrows(IOException::class.java) { cache.load(url) }
        assertEquals(0, directory.listFiles()!!.size)
        assertArrayEquals(image.bytes, cache.load(url).bytes)
        assertArrayEquals(image.bytes, cache.load(url).bytes)
        assertEquals(3, fetches.get())
    }

    @Test
    fun `a changed image URL downloads new bytes including changes only in query`() {
        val fetched = mutableListOf<String>()
        val cache = PersistentImageCache(temporary.newFolder(), ImageFetcher { request, _ ->
            fetched.add(request); image
        }, validator)
        cache.load(url)
        cache.load(url.replace("v=1", "v=2"))
        cache.load(url)
        assertEquals(listOf(url, url.replace("v=1", "v=2")), fetched)
    }

    @Test
    fun `corrupted and truncated persisted files are evicted and downloaded again`() {
        val directory = temporary.newFolder()
        val fetches = AtomicInteger()
        val cache = PersistentImageCache(directory, ImageFetcher { _, _ -> fetches.incrementAndGet(); image }, validator)
        cache.load(url)
        val file = directory.listFiles()!!.single()
        val corrupt = file.readBytes().also { it[it.lastIndex] = (it.last() + 1).toByte() }
        file.writeBytes(corrupt)
        assertArrayEquals(image.bytes, cache.load(url).bytes)
        file.writeBytes(byteArrayOf(0))
        assertArrayEquals(image.bytes, cache.load(url).bytes)
        assertEquals(3, fetches.get())
    }

    @Test
    fun `concurrent requests share a single download`() {
        val enteredFetch = CountDownLatch(1)
        val finishFetch = CountDownLatch(1)
        val fetches = AtomicInteger()
        val cache = PersistentImageCache(temporary.newFolder(), ImageFetcher { _, _ ->
            fetches.incrementAndGet()
            enteredFetch.countDown()
            check(finishFetch.await(5, TimeUnit.SECONDS))
            image
        }, validator)
        val executor = Executors.newFixedThreadPool(8)
        try {
            val requests = (1..8).map { executor.submit<CachedImage> { cache.load(url) } }
            assertTrue(enteredFetch.await(5, TimeUnit.SECONDS))
            finishFetch.countDown()
            requests.forEach { assertArrayEquals(image.bytes, it.get(5, TimeUnit.SECONDS).bytes) }
            assertEquals(1, fetches.get())
        } finally {
            finishFetch.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun `eviction removes least recently viewed images and enforces the total disk budget`() {
        val directory = temporary.newFolder()
        val clock = AtomicLong(1_000_000L)
        val fetched = mutableListOf<String>()
        val cache = PersistentImageCache(directory, ImageFetcher { request, _ ->
            fetched.add(request); CachedImage(ByteArray(200), "image/png")
        }, ImageValidator { "image/png" }, maxBytes = 550L, clock = { clock.incrementAndGet() })
        val a = "$url&a=1"
        val b = "$url&b=1"
        val c = "$url&c=1"
        cache.load(a)
        cache.load(b)
        cache.load(a)
        cache.load(c)
        cache.load(a)
        assertEquals(listOf(a, b, c), fetched)
        assertTrue(directory.listFiles()!!.sumOf(File::length) <= 550L)
        cache.load(b)
        assertEquals(listOf(a, b, c, b), fetched)
    }

    @Test
    fun `oversized image bodies and interrupted writes do not create entries`() {
        val directory = temporary.newFolder()
        File(directory, "interrupted.tmp").writeBytes(byteArrayOf(1))
        val cache = PersistentImageCache(directory, ImageFetcher { _, _ -> image }, validator, maxImageBytes = 2)
        assertThrows(IOException::class.java) { cache.load(url) }
        assertEquals(0, directory.listFiles()!!.size)
    }
}
