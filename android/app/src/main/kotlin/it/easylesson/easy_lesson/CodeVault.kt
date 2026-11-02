package it.easylesson.easy_lesson

import android.content.Context
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.BlockstoreClient
import com.google.android.gms.auth.blockstore.DeleteBytesRequest
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import com.google.android.gms.auth.blockstore.StoreBytesData

/**
 * Codici dell'account Easy Lesson nel "Block Store" di Google Play Services.
 *
 * Google tiene questi pochi byte nel backup del telefono (cifrato end-to-end se c'è un blocco
 * schermo) e li rimette da soli quando si configura un telefono nuovo con lo stesso account Google.
 * Senza Play Services (o se qualcosa va storto) si risponde false/null: l'app continua normalmente.
 */
object CodeVault {
    // Si usa la chiave predefinita del Block Store (un solo dato: il JSON con i codici, < 4 KB).
    private val KEY = BlockstoreClient.DEFAULT_BYTES_DATA_KEY

    fun save(context: Context, data: String, done: (Boolean) -> Unit) {
        try {
            val client = Blockstore.getClient(context)
            client.isEndToEndEncryptionAvailable()
                .addOnCompleteListener { e2e ->
                    val cloud = e2e.isSuccessful && e2e.result == true
                    val req = StoreBytesData.Builder()
                        .setBytes(data.toByteArray(Charsets.UTF_8))
                        .setShouldBackupToCloud(cloud)
                        .build()
                    client.storeBytes(req)
                        .addOnSuccessListener { done(true) }
                        .addOnFailureListener { done(false) }
                }
        } catch (e: Exception) {
            done(false)
        }
    }

    fun read(context: Context, done: (String?) -> Unit) {
        try {
            val req = RetrieveBytesRequest.Builder().setKeys(listOf(KEY)).build()
            Blockstore.getClient(context).retrieveBytes(req)
                .addOnSuccessListener { res ->
                    val bytes = res.blockstoreDataMap[KEY]?.bytes
                    done(bytes?.toString(Charsets.UTF_8))
                }
                .addOnFailureListener { done(null) }
        } catch (e: Exception) {
            done(null)
        }
    }

    fun delete(context: Context, done: (Boolean) -> Unit) {
        try {
            val req = DeleteBytesRequest.Builder().setKeys(listOf(KEY)).build()
            Blockstore.getClient(context).deleteBytes(req)
                .addOnSuccessListener { done(it == true) }
                .addOnFailureListener { done(false) }
        } catch (e: Exception) {
            done(false)
        }
    }
}
