package cn.yooss.moodiary_native

import android.Manifest
import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.nio.channels.Channels
import java.nio.channels.FileChannel
import java.nio.file.FileAlreadyExistsException
import java.nio.file.Files
import java.nio.file.LinkOption
import java.nio.file.StandardOpenOption
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal class LegacyExport(private val context: Context) : LegacyExportApi,
    PluginRegistry.RequestPermissionsResultListener {
    var activity: Activity? = null
    private var pendingPermission: CompletableDeferred<Boolean>? = null

    override fun availableCacheBytes(): Long = StatFs(context.cacheDir.path).availableBytes

    override suspend fun saveToDownloads(srcPath: String, displayName: String): SavedFile {
        require(displayName.endsWith(".zip") && displayName == File(displayName).name)
        val source = File(srcPath).canonicalFile
        require(source.toPath().startsWith(context.cacheDir.canonicalFile.toPath()) && source.isFile)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return withContext(Dispatchers.IO) { saveWithMediaStore(source, displayName) }
        }
        check(requestWritePermission()) { "Downloads permission denied" }
        return withContext(Dispatchers.IO) { saveLegacyDownload(source, displayName) }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveWithMediaStore(source: File, name: String): SavedFile {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "application/zip")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = checkNotNull(resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values))
        try {
            val size = source.length()
            checkNotNull(resolver.openOutputStream(uri)).use { output ->
                source.inputStream().use { input -> check(input.copyTo(output) == size) }
            }
            val savedSize = checkNotNull(resolver.openFileDescriptor(uri, "r")).use { it.statSize }
            check(savedSize == size) { "Saved archive size mismatch" }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            check(resolver.update(uri, values, null, null) == 1)
            val savedName = checkNotNull(resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)).use { cursor ->
                check(cursor.moveToFirst())
                cursor.getString(0)
            }
            return SavedFile(uri.toString(), savedSize, savedName)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacyDownload(source: File, name: String): SavedFile = synchronized(legacyDownloadLock) {
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        check(downloads.isDirectory || downloads.mkdirs())
        val manager = checkNotNull(context.getSystemService(DownloadManager::class.java))
        val staged = File(downloads, ".${context.packageName}.legacy-export.part")
        val stagePath = staged.toPath()
        check(!Files.isDirectory(stagePath, LinkOption.NOFOLLOW_LINKS)) { "Archive staging path is a directory" }
        Files.deleteIfExists(stagePath)
        val channel = FileChannel.open(stagePath, StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE)
        try {
            val size = channel.use {
                val expectedSize = source.length()
                val output = Channels.newOutputStream(it)
                source.inputStream().use { input -> check(input.copyTo(output) == expectedSize) }
                it.force(true)
                expectedSize
            }
            check(staged.length() == size) { "Saved archive size mismatch" }
            var destination = File(downloads, name)
            var suffix = 1
            while (true) {
                try {
                    Files.move(stagePath, destination.toPath())
                    break
                } catch (_: FileAlreadyExistsException) {
                    destination = File(downloads, "${name.removeSuffix(".zip")} (${suffix++}).zip")
                }
            }
            var downloadId: Long? = null
            try {
                val id = manager.addCompletedDownload(destination.name, destination.name, false,
                    "application/zip", destination.path, size, true)
                downloadId = id
                val uri = checkNotNull(manager.getUriForDownloadedFile(id))
                SavedFile(uri.toString(), size, destination.name)
            } catch (error: Exception) {
                try {
                    downloadId?.let { manager.remove(it) }
                } finally {
                    destination.delete()
                }
                throw error
            }
        } finally {
            staged.delete()
        }
    }

    private suspend fun requestWritePermission(): Boolean {
        val permission = Manifest.permission.WRITE_EXTERNAL_STORAGE
        if (context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) return true
        val host = activity ?: return false
        pendingPermission?.let { return it.await() }
        val result = CompletableDeferred<Boolean>()
        pendingPermission = result
        try {
            host.requestPermissions(arrayOf(permission), REQUEST_CODE)
            return result.await()
        } finally {
            if (pendingPermission === result) pendingPermission = null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.complete(grantResults.getOrNull(permissions.indexOf(Manifest.permission.WRITE_EXTERNAL_STORAGE)) == PackageManager.PERMISSION_GRANTED)
        return true
    }

    fun detach() { pendingPermission?.complete(false) }

    private companion object {
        const val REQUEST_CODE = 0x4d53
        val legacyDownloadLock = Any()
    }
}
