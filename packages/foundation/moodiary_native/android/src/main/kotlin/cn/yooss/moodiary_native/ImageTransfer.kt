package cn.yooss.moodiary_native

import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class ImageTransfer(private val context: Context) : ImageTransferApi {
    private fun readImage(uri: Uri): TransferredImage? {
        val resolver = context.contentResolver
        val mime = resolver.getType(uri)
            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(uri.lastPathSegment?.substringAfterLast('.')?.lowercase())
            ?: return null
        if (!mime.startsWith("image/")) return null
        var name = "image.${mime.substringAfter('/')}"
        runCatching {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) name = it.getString(0) ?: name
            }
        }
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        return TransferredImage(bytes, mime, name)
    }

    override suspend fun readContentUri(uri: String): ByteArray? = withContext(Dispatchers.IO) {
        val parsed = Uri.parse(uri)
        if (parsed.scheme == "content") readImage(parsed)?.bytes else null
    }

    override suspend fun readClipboardImage(): TransferredImage? {
        // Clipboard access must happen while the app is focused, on the UI thread.
        val clip = (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).primaryClip
        val uris = if (clip == null) emptyList() else (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
        return withContext(Dispatchers.IO) { uris.firstNotNullOfOrNull { readImage(it) } }
    }
}
