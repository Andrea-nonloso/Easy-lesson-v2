package it.easylesson.easy_lesson

import android.app.Activity
import android.content.ClipData
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File

/**
 * 3.9: condivide un'immagine (riepilogo della settimana, Wrapped) o un PDF (scanner) con il menu "Condividi" di Android.
 * Il file sta in cache/share e lo serve [ShareProvider], solo in lettura e solo a chi riceve il permesso
 * dall'intent (niente librerie in più).
 */
object ShareImage {
    private val SAFE = Regex("[A-Za-z0-9_.-]{1,80}")

    fun dir(activity: Activity) = File(activity.cacheDir, "share")

    fun mimeOf(name: String) = if (name.endsWith(".pdf")) "application/pdf" else "image/png"

    fun share(activity: Activity, bytes: ByteArray, name: String, text: String?) {
        require(SAFE.matches(name)) { "nome non valido" }
        val dir = dir(activity).apply { mkdirs() }
        // Si tiene solo l'ultima immagine condivisa.
        dir.listFiles()?.forEach { it.delete() }
        File(dir, name).writeBytes(bytes)
        val uri = Uri.parse("content://${activity.packageName}.share/$name")
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mimeOf(name)
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!text.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            clipData = ClipData.newRawUri("", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
    }

    fun isSafe(name: String) = SAFE.matches(name)
}

class ShareProvider : ContentProvider() {
    override fun onCreate() = true

    private fun fileOf(uri: Uri): File? {
        val ctx = context ?: return null
        val name = uri.lastPathSegment ?: return null
        if (uri.pathSegments.size != 1 || !ShareImage.isSafe(name)) return null
        val f = File(File(ctx.cacheDir, "share"), name)
        return if (f.isFile) f else null
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        if (mode != "r") return null
        val f = fileOf(uri) ?: return null
        return ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri) = ShareImage.mimeOf(uri.lastPathSegment ?: "")

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? {
        val f = fileOf(uri) ?: return null
        return MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)).apply { addRow(arrayOf<Any>(f.name, f.length())) }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0
}
