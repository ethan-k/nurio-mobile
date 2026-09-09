package com.nurio.android.webview.images

import org.xml.sax.InputSource
import org.xml.sax.SAXException
import org.xml.sax.helpers.DefaultHandler
import org.xml.sax.ext.DefaultHandler2
import java.io.ByteArrayInputStream
import javax.xml.parsers.SAXParserFactory

internal object CompleteSvg {
    fun isValid(bytes: ByteArray): Boolean = runCatching {
        // No document type/entity expansion, scripts or remote subresources in durable SVGs.
        val text = bytes.toString(Charsets.UTF_8)
        if (Regex("<!\\s*(DOCTYPE|ENTITY)", RegexOption.IGNORE_CASE).containsMatchIn(text)) return false
        var rootSeen = false
        val factory = SAXParserFactory.newInstance().apply { isNamespaceAware = true }
        val reader = factory.newSAXParser().xmlReader
        reader.entityResolver = org.xml.sax.EntityResolver { _, _ -> throw SAXException("External entity") }
        reader.setProperty("http://xml.org/sax/properties/lexical-handler", object : DefaultHandler2() {
            override fun startDTD(name: String?, publicId: String?, systemId: String?) {
                throw SAXException("Document types are not image content")
            }
        })
        reader.contentHandler = object : DefaultHandler() {
            private var styleText: StringBuilder? = null

            override fun processingInstruction(target: String?, data: String?) {
                throw SAXException("Processing instructions are not image content")
            }

            override fun startElement(uri: String?, localName: String?, qName: String?, attributes: org.xml.sax.Attributes) {
                if (styleText != null) throw SAXException("Markup inside SVG style")
                if (!rootSeen) {
                    if (localName != "svg" || uri !in listOf("", "http://www.w3.org/2000/svg")) {
                        throw SAXException("Not SVG")
                    }
                    rootSeen = true
                }
                if (localName == "script" || localName == "foreignObject") throw SAXException("Active SVG")
                for (index in 0 until attributes.length) {
                    val name = attributes.getLocalName(index).lowercase()
                    val value = attributes.getValue(index).trim()
                    if (name.startsWith("on") ||
                        (name in listOf("href", "src") && value.isNotEmpty() && !value.startsWith('#') && !value.startsWith("data:image/"))
                    ) throw SAXException("External SVG content")
                    // Presentation attributes such as fill/filter can contain URLs too.
                    if (!hasOnlyLocalCssResources(value)) throw SAXException("External SVG CSS")
                }
                if (localName == "style") styleText = StringBuilder()
            }

            override fun characters(ch: CharArray, start: Int, length: Int) {
                styleText?.append(ch, start, length)
            }

            override fun endElement(uri: String?, localName: String?, qName: String?) {
                if (localName == "style") {
                    if (!hasOnlyLocalCssResources(styleText.toString())) throw SAXException("External SVG CSS")
                    styleText = null
                }
            }
        }
        reader.errorHandler = object : DefaultHandler() {
            override fun error(e: org.xml.sax.SAXParseException) { throw e }
            override fun fatalError(e: org.xml.sax.SAXParseException) { throw e }
        }
        reader.parse(InputSource(ByteArrayInputStream(bytes)))
        rootSeen
    }.getOrDefault(false)

    private fun hasOnlyLocalCssResources(value: String): Boolean {
        val css = value.replace(Regex("/\\*[\\s\\S]*?\\*/"), "")
        // Reject escapes rather than trying to emulate every CSS tokenizer escape rule.
        // image()/image-set()/src() can load string URLs without a url() expression.
        if ('\\' in css || Regex("@\\s*import|(?:-webkit-)?(?:image-set|image|src)\\s*\\(", RegexOption.IGNORE_CASE).containsMatchIn(css)) {
            return false
        }
        val urls = Regex("url\\s*\\(([^)]*)\\)", RegexOption.IGNORE_CASE)
        for (match in urls.findAll(css)) {
            val target = match.groupValues[1].trim()
            if (!Regex("(?:#[^\\s'\"()]+|'#[^'()]+'|\"#[^\"()]+\")").matches(target)) return false
        }
        // A malformed/unclosed URL must not slip past the matches above.
        return !Regex("url\\s*\\(", RegexOption.IGNORE_CASE).containsMatchIn(css.replace(urls, ""))
    }
}
