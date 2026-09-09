package com.nurio.android.webview.images

import java.net.InetAddress
import java.net.URI

/** Only image URLs explicitly emitted by a capable Rails page use this transport. */
object NativeImageUrl {
    const val SCHEME = "nurio-image"

    fun isImageRequest(value: String): Boolean =
        value.startsWith("$SCHEME:", ignoreCase = true)

    fun original(value: String): String? {
        if (!isImageRequest(value)) return null
        val original = "https" + value.substring(value.indexOf(':'))
        return original.takeIf(::isAllowedHttps)
    }

    fun isAllowedHttps(value: String): Boolean = runCatching {
        val uri = URI(value)
        if (!uri.scheme.equals("https", ignoreCase = true) || uri.rawUserInfo != null ||
            uri.port !in listOf(-1, 443)
        ) return false

        val host = uri.host?.lowercase()?.removeSuffix(".") ?: return false
        if (host.isBlank() || host == "localhost" || host.endsWith(".localhost") ||
            host.endsWith(".local") || '%' in host
        ) return false

        val literal = host.removePrefix("[").removeSuffix("]")
        if (':' in literal) {
            val address = InetAddress.getByName(literal)
            if (address.isAnyLocalAddress || address.isLoopbackAddress ||
                address.isLinkLocalAddress || address.isSiteLocalAddress || address.isMulticastAddress
            ) return false
            if (address.address.size == 16 && (address.address[0].toInt() and 0xfe) == 0xfc) return false
            if (address.address.size == 4 && !publicIpv4(address.address.map { it.toInt() and 0xff })) return false
        } else if (host.all { it.isDigit() || it == '.' }) {
            val parts = host.split('.').map { it.toIntOrNull() ?: return false }
            if (parts.size != 4 || parts.any { it !in 0..255 } ||
                host.split('.').any { it.length > 1 && it.startsWith('0') }
            ) return false
            if (!publicIpv4(parts)) return false
        } else if ('.' !in host || host.startsWith("0x") ||
            host.split('.').all { it.matches(Regex("(?:0[xX][0-9a-fA-F]+|[0-9]+)")) }
        ) return false

        true
    }.getOrDefault(false)

    private fun publicIpv4(parts: List<Int>): Boolean {
        val a = parts[0]
        val b = parts[1]
        return a !in listOf(0, 10, 127) && a < 224 &&
            !(a == 169 && b == 254) && !(a == 172 && b in 16..31) &&
            !(a == 192 && b == 168) && !(a == 100 && b in 64..127)
    }
}
