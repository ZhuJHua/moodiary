package cn.yooss.moodiary_native

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context

class HtmlClipboard(private val context: Context) : HtmlClipboardApi {
    private val clipboard get() = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    override suspend fun read(): HtmlClipboardContent? {
        val clip = clipboard.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val item = clip.getItemAt(0)
        // Do not coerce image URIs to text: image transfer owns their permissions/IO.
        if (item.text == null && item.htmlText == null) return null
        return HtmlClipboardContent(item.text?.toString() ?: "", item.htmlText)
    }
    override fun write(content: HtmlClipboardContent) {
        clipboard.setPrimaryClip(content.html?.let {
            ClipData.newHtmlText("", content.text, it)
        } ?: ClipData.newPlainText("", content.text))
    }
}
