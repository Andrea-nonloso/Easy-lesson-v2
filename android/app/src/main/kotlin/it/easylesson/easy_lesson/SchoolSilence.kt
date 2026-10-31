package it.easylesson.easy_lesson

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import org.json.JSONArray

/**
 * "Silenzioso a scuola": all'inizio della prima ora il telefono va in Non disturbare
 * (solo priorità), alla fine dell'ultima torna come prima. Serve il permesso
 * "Accesso a Non disturbare", che l'utente dà dalle impostazioni di Android.
 */
object SchoolSilence {
    private const val PREFS = "easylesson_silence"
    private const val ACTION = "it.easylesson.SILENCE"

    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 23) return false
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    fun openSettings(context: Context) {
        if (Build.VERSION.SDK_INT < 23) return
        context.startActivity(
            Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    private fun pending(context: Context, id: Int, on: Boolean): PendingIntent {
        val i = Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION
            putExtra("on", on)
        }
        return PendingIntent.getBroadcast(context, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** [json] = [[inizio, fine], ...] in millisecondi. Sostituisce quelli di prima. */
    fun schedule(context: Context, json: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val count = prefs.getInt("count", 0)
        for (k in 0 until count) {
            am.cancel(pending(context, 6000 + k * 2, true))
            am.cancel(pending(context, 6001 + k * 2, false))
        }
        val now = System.currentTimeMillis()
        val list = JSONArray(json)
        var n = 0
        for (k in 0 until list.length()) {
            val w = list.getJSONArray(k)
            val start = w.getLong(0)
            val end = w.getLong(1)
            if (end <= now) continue
            if (start > now) set(am, start, pending(context, 6000 + n * 2, true))
            else apply(context, true) // siamo già a lezione
            set(am, end, pending(context, 6001 + n * 2, false))
            n++
        }
        // Spento del tutto: se l'avevamo messo noi, si toglie.
        if (n == 0) apply(context, false)
        prefs.edit().putInt("count", n).putString("json", json).apply()
    }

    private fun set(am: AlarmManager, at: Long, pi: PendingIntent) {
        if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        else am.set(AlarmManager.RTC_WAKEUP, at, pi)
    }

    fun restore(context: Context) {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("json", null) ?: return
        schedule(context, json)
    }

    /** Accende o spegne il Non disturbare (lo spegne solo se l'aveva acceso l'app). */
    fun apply(context: Context, on: Boolean) {
        if (Build.VERSION.SDK_INT < 23 || !allowed(context)) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (on) {
            if (nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL) {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                prefs.edit().putBoolean("ours", true).apply()
            }
        } else if (prefs.getBoolean("ours", false)) {
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            prefs.edit().putBoolean("ours", false).apply()
        }
    }

    fun isAction(intent: Intent) = intent.action == ACTION
}
