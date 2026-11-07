package it.easylesson.easy_lesson

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 3.8 "Importa da WhatsApp": apre il selettore di cartelle di Android già su
 * Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers. L'utente dà il permesso (una volta per quella cartella)
 * e qui si copiano gli sticker (.webp, .png, .gif, max 1 MB ciascuno, max 300) nella cache dell'app.
 * A Dart arrivano i percorsi dei file copiati; li sistema lui nella raccolta degli sticker.
 * Niente permessi speciali: solo quello che l'utente sceglie nel selettore.
 */
object StickerImport {
    private const val REQUEST = 4711
    private const val MAX_FILES = 300
    private const val MAX_BYTES = 1024L * 1024L
    private var pending: MethodChannel.Result? = null

    private val WHATSAPP = Uri.parse(
        "content://com.android.externalstorage.documents/document/" +
            "primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2FWhatsApp%20Stickers"
    )

    fun start(activity: Activity, result: MethodChannel.Result) {
        pending?.success(emptyList<String>())
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        if (Build.VERSION.SDK_INT >= 26) intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, WHATSAPP)
        try {
            activity.startActivityForResult(intent, REQUEST)
        } catch (e: Exception) {
            pending = null
            result.error("no_picker", "Selettore di cartelle non disponibile: ${e.message}", null)
        }
    }

    /** true = era la risposta del selettore. */
    fun onResult(activity: Activity, requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(emptyList<String>())
            return true
        }
        Thread {
            val out = ArrayList<String>()
            try {
                val dir = File(activity.cacheDir, "wa_stickers").apply { deleteRecursively(); mkdirs() }
                val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                val cols = arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_SIZE,
                )
                activity.contentResolver.query(children, cols, null, null, null)?.use { c ->
                    while (c.moveToNext() && out.size < MAX_FILES) {
                        val id = c.getString(0) ?: continue
                        val name = c.getString(1) ?: continue
                        val size = if (c.isNull(2)) 0L else c.getLong(2)
                        val ext = name.substringAfterLast('.', "").lowercase()
                        if (ext !in setOf("webp", "png", "gif") || size <= 0 || size > MAX_BYTES) continue
                        val src = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                        val dst = File(dir, "${out.size}.$ext")
                        activity.contentResolver.openInputStream(src)?.use { inp -> dst.outputStream().use { inp.copyTo(it) } }
                        if (dst.length() in 1..MAX_BYTES) out.add(dst.absolutePath) else dst.delete()
                    }
                }
                activity.runOnUiThread { result.success(out) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("import", "Non riesco a leggere la cartella: ${e.message}", null) }
            }
        }.start()
        return true
    }
}
