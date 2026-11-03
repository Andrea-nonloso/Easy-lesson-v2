package it.easylesson.easy_lesson

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray

/**
 * Notifiche "tra 5 minuti: Matematica". Flutter manda l'elenco delle prossime
 * lezioni (circa 3 settimane, già senza vacanze); qui si programmano le sveglie.
 */
object Reminders {
    private const val PREFS = "easylesson_reminders"
    private const val CHANNEL = "lezioni"

    fun allowed(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun pending(context: Context, id: Int, title: String?, body: String?, ch: String? = null): PendingIntent {
        val i = Intent(context, ReminderReceiver::class.java).apply {
            action = "it.easylesson.REMINDER"
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("ch", ch)
        }
        return PendingIntent.getBroadcast(
            context, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Sostituisce tutte le notifiche programmate con quelle di [json]. */
    fun schedule(context: Context, json: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Via le vecchie
        val old = prefs.getString("ids", "") ?: ""
        for (s in old.split(",")) {
            val id = s.toIntOrNull() ?: continue
            am.cancel(pending(context, id, null, null))
        }
        val now = System.currentTimeMillis()
        val ids = mutableListOf<Int>()
        val list = JSONArray(json)
        for (k in 0 until list.length()) {
            val o = list.getJSONObject(k)
            val at = o.getLong("at")
            if (at <= now) continue
            val id = o.getInt("id")
            val pi = pending(context, id, o.optString("title"), o.optString("body"), o.optString("ch", CHANNEL))
            if (Build.VERSION.SDK_INT >= 23) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
            }
            ids.add(id)
        }
        prefs.edit().putString("ids", ids.joinToString(",")).putString("json", json).apply()
    }

    /** Una notifica sola a un'ora precisa (timer di studio). */
    fun one(context: Context, id: Int, at: Long, title: String, body: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(context, id, title, body, "giorno")
        if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        else am.set(AlarmManager.RTC_WAKEUP, at, pi)
    }

    fun cancelOne(context: Context, id: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(context, id, null, null, "giorno"))
    }

    /** Dopo un riavvio del telefono le sveglie spariscono: si rimettono. */
    fun restore(context: Context) {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("json", null) ?: return
        schedule(context, json)
    }

    /** Canali delle notifiche (si possono spegnere uno per uno dalle impostazioni di Android). */
    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Prossima lezione", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Avviso qualche minuto prima di ogni lezione"
            }
        )
        nm.createNotificationChannel(
            NotificationChannel("giorno", "La tua giornata", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Riepilogo della sera, buongiorno, ricreazione, fine della scuola, vacanze"
            }
        )
        nm.createNotificationChannel(
            NotificationChannel("aggiornamenti", "Aggiornamenti dell'app", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Quando su GitHub esce una nuova versione di Easy Lesson"
            }
        )
    }

    fun show(context: Context, id: Int, title: String, body: String, channel: String = CHANNEL, open: PendingIntent? = null) {
        if (!allowed(context)) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannels(context)
        val tap = open ?: PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val n = builder
            .setSmallIcon(R.drawable.ic_stat_lesson)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        nm.notify(id, n)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, "android.intent.action.MY_PACKAGE_REPLACED" -> {
                Reminders.restore(context)
                SchoolSilence.restore(context)
                LessonWidget.updateAll(context)
                UpdateCheck.ensureScheduled(context)
                LiveLesson.update(context)
            }
            LiveLesson.ACTION -> LiveLesson.update(context)
            else -> if (SchoolSilence.isAction(intent)) {
                SchoolSilence.apply(context, intent.getBooleanExtra("on", false))
            } else Reminders.show(
                context,
                intent.getIntExtra("id", 0),
                intent.getStringExtra("title") ?: "Easy Lesson",
                intent.getStringExtra("body") ?: "",
                intent.getStringExtra("ch")?.takeIf { it.isNotEmpty() } ?: "lezioni"
            )
        }
    }
}
