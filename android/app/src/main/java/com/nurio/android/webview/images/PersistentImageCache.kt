package com.nurio.android.webview.images

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Semaphore

data class CachedImage(val bytes: ByteArray, val mimeType: String)

fun interface ImageFetcher {
    fun fetch(url: String, maxBytes: Int): CachedImage
}

fun interface ImageValidator {
    /** Returns the decoded MIME type, or null for incomplete/unsupported images. */
    fun validatedMimeType(image: CachedImage): String?
}

/** Durable app-private files, with no expiry. URL changes are the invalidation mechanism. */
class PersistentImageCache(
    private val directory: File,
    private val fetcher: ImageFetcher,
    private val validator: ImageValidator,
    private val maxBytes: Long = 256L * 1024 * 1024,
    private val maxImageBytes: Int = 20 * 1024 * 1024,
    private val clock: () -> Long = System::currentTimeMillis
) {
    private val diskLock = Any()
    private val inFlight = ConcurrentHashMap<String, CompletableFuture<CachedImage>>()
    private val downloads = Semaphore(4)

    init {
        synchronized(diskLock) {
            if (!directory.isDirectory && !directory.mkdirs()) throw IOException("Image directory unavailable")
            directory.listFiles()?.filter { it.extension == "tmp" }?.forEach { it.delete() }
            evictToFit()
        }
    }

    fun load(url: String): CachedImage {
        if (!NativeImageUrl.isAllowedHttps(url)) throw IOException("Unsupported image URL")
        val key = sha256(url.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
        synchronized(diskLock) { read(key)?.let { return it } }

        val pending = CompletableFuture<CachedImage>()
        val existing = inFlight.putIfAbsent(key, pending)
        if (existing != null) return existing.get()
        try {
            // The previous owner may have persisted the file between our first read and registration.
            synchronized(diskLock) { read(key) }?.let {
                pending.complete(it)
                return it
            }
            downloads.acquire()
            val image = try {
                val downloaded = fetcher.fetch(url, maxImageBytes)
                if (downloaded.bytes.isEmpty() || downloaded.bytes.size > maxImageBytes) {
                    throw IOException("Image size out of bounds")
                }
                val mime = validator.validatedMimeType(downloaded)
                    ?: throw IOException("Incomplete or unsupported image")
                downloaded.copy(mimeType = mime)
            } finally {
                downloads.release()
            }
            synchronized(diskLock) { write(key, image) }
            pending.complete(image)
            return image
        } catch (failure: Exception) {
            pending.completeExceptionally(failure)
            throw failure
        } finally {
            inFlight.remove(key, pending)
        }
    }

    private fun read(key: String): CachedImage? {
        val file = File(directory, "$key.image")
        if (!file.isFile) return null
        return try {
            if (file.length() > maxImageBytes.toLong() + 512L) throw IOException("Invalid stored size")
            val image = DataInputStream(file.inputStream().buffered()).use { input ->
                if (input.readInt() != FILE_VERSION) throw IOException("Unknown cache format")
                val mime = input.readUTF()
                if (!mime.startsWith("image/") || mime.length > 100) throw IOException("Invalid stored MIME")
                val size = input.readInt()
                if (size !in 1..maxImageBytes) throw IOException("Invalid stored size")
                val digest = ByteArray(32).also(input::readFully)
                val bytes = ByteArray(size).also(input::readFully)
                if (input.read() != -1 || !MessageDigest.isEqual(digest, sha256(bytes))) {
                    throw IOException("Stored image checksum mismatch")
                }
                CachedImage(bytes, mime)
            }
            // These bytes were decoded before the atomic write; the digest detects later corruption.
            file.setLastModified(clock())
            image
        } catch (_: IOException) {
            file.delete()
            null
        }
    }

    private fun write(key: String, image: CachedImage) {
        val target = File(directory, "$key.image")
        val temporary = File.createTempFile("$key-", ".tmp", directory)
        try {
            FileOutputStream(temporary).use { stream ->
                val output = DataOutputStream(stream.buffered())
                output.writeInt(FILE_VERSION)
                output.writeUTF(image.mimeType)
                output.writeInt(image.bytes.size)
                output.write(sha256(image.bytes))
                output.write(image.bytes)
                output.flush()
                stream.fd.sync()
            }
            if (temporary.length() > maxBytes) throw IOException("Image exceeds disk budget")
            if (!temporary.renameTo(target)) throw IOException("Unable to persist image")
            target.setLastModified(clock())
            evictToFit(protectedFile = target)
        } finally {
            temporary.delete()
        }
    }

    private fun evictToFit(protectedFile: File? = null) {
        val files = directory.listFiles()?.filter { it.extension == "image" } ?: return
        var size = files.sumOf { it.length() }
        for (file in files.filter { it != protectedFile }.sortedBy { it.lastModified() }) {
            if (size <= maxBytes) break
            val length = file.length()
            if (file.delete()) size -= length
        }
    }

    private fun sha256(bytes: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(bytes)

    private companion object {
        const val FILE_VERSION = 0x4e494301
    }
}
