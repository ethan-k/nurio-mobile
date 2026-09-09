package com.nurio.android.webview.images

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CompleteSvgTest {
    @Test
    fun `complete SVG passes and incomplete or nonimage markup fails`() {
        assertTrue(CompleteSvg.isValid("<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0L1 1\"/></svg>".toByteArray()))
        assertTrue(CompleteSvg.isValid("<svg/>".toByteArray()))
        assertFalse(CompleteSvg.isValid("<svg><path/>".toByteArray()))
        assertFalse(CompleteSvg.isValid("<html><body>Error</body></html>".toByteArray()))
        assertFalse(CompleteSvg.isValid("<svg/><svg/>".toByteArray()))
    }

    @Test
    fun `SVG cannot resolve entities or retain active remote content`() {
        listOf(
            "<!DOCTYPE svg [<!ENTITY x 'expanded'>]><svg>&x;</svg>",
            "<svg><script>alert(1)</script></svg>",
            "<svg><image href=\"https://example.com/tracker.png\"/></svg>",
            "<svg onload=\"alert(1)\"/>"
        ).forEach { assertFalse(it, CompleteSvg.isValid(it.toByteArray())) }
        assertFalse(CompleteSvg.isValid("<?xml version=\"1.0\" encoding=\"UTF-16\"?><!DOCTYPE svg [<!ENTITY x 'expanded'>]><svg>&x;</svg>".toByteArray(Charsets.UTF_16)))
    }

    @Test
    fun `SVG rejects remote CSS in styles and presentation attributes including escapes`() {
        listOf(
            "<svg><style>@import 'https://example.com/style.css';</style></svg>",
            "<svg><style>@im/**/port 'https://example.com/style.css';</style></svg>",
            "<svg><style><![CDATA[path { fill: url(https://example.com/a.svg#paint); }]]></style></svg>",
            "<svg><path style=\"fill: url('https://example.com/a.svg#paint')\"/></svg>",
            "<svg><path fill=\"url(//example.com/a.svg#paint)\"/></svg>",
            "<svg><path fill=\"url(/a.svg#paint)\"/></svg>",
            "<svg><path style=\"fill: u\\72l(https://example.com/a.svg#paint)\"/></svg>",
            "<svg><style>path { background: image-set('/image.png' 1x); }</style></svg>",
            "<svg><path fill=\"url(https://example.com/unclosed\"/></svg>"
        ).forEach { assertFalse(it, CompleteSvg.isValid(it.toByteArray())) }
    }

    @Test
    fun `SVG local gradients and masks remain valid`() {
        listOf(
            "<?xml version=\"1.0\"?><svg><path fill=\"url(#gradient)\"/></svg>",
            "<svg><path style=\"mask: url('#mask'); fill: red\"/></svg>",
            "<svg><style>path { fill: url(\"#gradient\"); mask: URL( /*local*/ '#mask' ); }</style></svg>"
        ).forEach { assertTrue(it, CompleteSvg.isValid(it.toByteArray())) }
    }

    @Test
    fun `SVG rejects processing instructions outside and inside the root`() {
        listOf(
            "<?xml-stylesheet href=\"https://example.com/style.css\"?><svg/>",
            "<svg><?xml-stylesheet href=\"/style.css\"?></svg>",
            "<?custom data?><svg/>"
        ).forEach { assertFalse(it, CompleteSvg.isValid(it.toByteArray())) }
    }
}
