package cn.yooss.moodiary_native

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.graphics.RectF
import android.net.Uri
import android.provider.OpenableColumns
import android.view.DragEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ImageTransfer(private val context: Context, messenger: BinaryMessenger) : ImageTransferApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val client = ImageTransferClient(messenger)
    private var disposed = false
    private var view: View? = null
    private var target: Long? = null
    private var bounds = RectF()
    var activity: Activity? = null
        set(value) {
            view?.setOnDragListener(null)
            field = value
            view = value?.window?.decorView?.let { findFlutterView(it) }
            installListener()
        }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) {
            findFlutterView(view.getChildAt(i))?.let { return it }
        }
        return null
    }

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

    override fun setDropTarget(target: Long, left: Double, top: Double, width: Double, height: Double) {
        this.target = target
        bounds = RectF(left.toFloat(), top.toFloat(), (left + width).toFloat(), (top + height).toFloat())
        // Activity attachment can precede FlutterView attachment.
        if (view == null) view = activity?.window?.decorView?.let { findFlutterView(it) }
        installListener()
    }

    override fun clearDropTarget(target: Long) {
        if (this.target != target) return
        this.target = null
        view?.setOnDragListener(null)
    }

    private fun installListener() {
        view?.setOnDragListener(if (target == null) null else View.OnDragListener { v, event ->
            val density = v.resources.displayMetrics.density
            val x = event.x / density
            val y = event.y / density
            when (event.action) {
                DragEvent.ACTION_DRAG_STARTED -> event.clipDescription?.let {
                    it.hasMimeType("image/*") || it.hasMimeType("text/uri-list") || it.hasMimeType("application/octet-stream")
                } ?: false
                DragEvent.ACTION_DRAG_LOCATION -> bounds.contains(x, y)
                DragEvent.ACTION_DROP -> {
                    val id = target
                    if (id == null || !bounds.contains(x, y)) false else {
                        val permission = activity?.requestDragAndDropPermissions(event)
                        val clip = event.clipData
                        val uris = (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
                        scope.launch {
                            try {
                                val images = withContext(Dispatchers.IO) {
                                    uris.mapNotNull { uri -> runCatching { readImage(uri) }.getOrNull() }
                                }
                                if (!disposed && target == id && images.isNotEmpty()) {
                                    runCatching { client.onDrop(ImageDrop(id, x.toDouble(), y.toDouble(), images)) }
                                }
                            } finally { permission?.release() }
                        }
                        true
                    }
                }
                DragEvent.ACTION_DRAG_ENDED, DragEvent.ACTION_DRAG_ENTERED, DragEvent.ACTION_DRAG_EXITED -> true
                else -> false
            }
        })
    }

    fun dispose() {
        disposed = true
        view?.setOnDragListener(null)
        scope.cancel()
    }
}
