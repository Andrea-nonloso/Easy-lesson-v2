package it.easylesson.easy_lesson

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.plugin.common.MethodChannel

/**
 * 3.8: notifiche push dei messaggi ad app chiusa (Firebase Cloud Messaging).
 *
 * Firebase c'è solo se l'APK è stato costruito con google-services.json; altrimenti tutto qui restituisce null e
 * l'app si arrangia come prima (notifiche solo con l'app aperta o appena chiusa).
 * Il token si crea solo quando l'utente ha le notifiche dei messaggi accese (auto-init spento nel manifest).
 * Le notifiche arrivano già pronte dal server (testi fissi, canale "chat"): le mostra Android, non serve codice.
 */
object Push {
    private fun available(ctx: Context): Boolean = try {
        FirebaseApp.getApps(ctx).isNotEmpty() || FirebaseApp.initializeApp(ctx) != null
    } catch (e: Throwable) {
        false
    }

    /** Token di questo telefono (null = Firebase non c'è o non risponde). */
    fun token(ctx: Context, result: MethodChannel.Result) {
        if (!available(ctx)) return result.success(null)
        try {
            Reminders.ensureChannels(ctx)
            val fm = FirebaseMessaging.getInstance()
            fm.isAutoInitEnabled = true
            fm.token.addOnCompleteListener { t ->
                result.success(if (t.isSuccessful) t.result else null)
            }
        } catch (e: Throwable) {
            result.success(null)
        }
    }

    /** Notifiche dei messaggi spente: il token si cancella (Firebase non può più raggiungere il telefono). */
    fun off(ctx: Context, result: MethodChannel.Result) {
        if (!available(ctx)) return result.success(false)
        try {
            val fm = FirebaseMessaging.getInstance()
            fm.isAutoInitEnabled = false
            fm.deleteToken().addOnCompleteListener { result.success(it.isSuccessful) }
        } catch (e: Throwable) {
            result.success(false)
        }
    }
}
