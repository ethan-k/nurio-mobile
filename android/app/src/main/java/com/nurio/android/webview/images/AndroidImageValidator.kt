package com.nurio.android.webview.images

import android.graphics.ImageDecoder
import java.nio.ByteBuffer
import java.io.IOException

class AndroidImageValidator : ImageValidator {
    override fun validatedMimeType(image: CachedImage): String? {
        if (image.mimeType == "image/svg+xml") {
            return image.mimeType.takeIf { CompleteSvg.isValid(image.bytes) }
        }
        return runCatching {
            var mime: String? = null
            val source = ImageDecoder.createSource(ByteBuffer.wrap(image.bytes))
            val bitmap = ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                mime = info.mimeType
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.setOnPartialImageListener { false }
                // Bound decoded memory while still asking the platform to reject incomplete input.
                val largestSide = maxOf(info.size.width, info.size.height)
                if (info.size.width <= 0 || info.size.height <= 0 || largestSide > 20_000 ||
                    info.size.width.toLong() * info.size.height > 80_000_000L
                ) {
                    throw IOException("Image dimensions out of bounds")
                }
                if (largestSide > 1024) decoder.setTargetSampleSize((largestSide + 1023) / 1024)
            }
            bitmap.recycle()
            mime?.takeIf { it.startsWith("image/") && completeContainer(image.bytes, it) }
        }.getOrNull()
    }

    private fun completeContainer(bytes: ByteArray, mime: String): Boolean = when (mime) {
        "image/jpeg" -> bytes.size >= 4 && bytes[bytes.lastIndex - 1] == 0xff.toByte() && bytes.last() == 0xd9.toByte()
        "image/gif" -> bytes.size >= 14 && bytes.last() == 0x3b.toByte()
        "image/png" -> bytes.size >= 20 && bytes.copyOfRange(bytes.size - 12, bytes.size)
            .contentEquals(byteArrayOf(0, 0, 0, 0, 73, 69, 78, 68, -82, 66, 96, -126))
        "image/webp" -> bytes.size >= 12 && (4..7).sumOf { index ->
            (bytes[index].toLong() and 0xff) shl ((index - 4) * 8)
        } + 8 == bytes.size.toLong()
        else -> true // ImageDecoder validates other platform-supported formats (e.g. AVIF).
    }
}
