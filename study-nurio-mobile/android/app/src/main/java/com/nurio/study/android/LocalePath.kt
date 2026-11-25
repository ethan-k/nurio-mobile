package com.nurio.study.android

internal object LocalePath {
    fun strip(path: String): String {
        val prefix = path.take(3)
        if (prefix.any { it > '\u007f' }) return path
        val locale = prefix.lowercase()
        if (locale != "/en" && locale != "/ko") return path

        val remainder = path.drop(3)
        return when (remainder.firstOrNull()) {
            '/' -> "/" + remainder.trimStart('/')
            null, '?', '#' -> "/$remainder"
            else -> path
        }
    }
}
