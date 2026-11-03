package it.easylesson.easy_lesson

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Notifica "lezione in corso" (3.0): resta in tendina durante la lezione con materia, aula e
 * la barra del tempo; 10 minuti prima mostra la prossima. Su Android 16+ chiede di essere un
 * "Live Update" (notifica in evidenza, anche nella barra di stato e sulla schermata di blocco).
 * Usa gli stessi dati del widget (LessonWidget.compute). Si accende dalle impostazioni dell'app.
 */
object LiveLesson {
    private const val PREFS = "easylesson_live"
    private const val CHANNEL = "live"
    private const val ID = 4242
    const val ACTION = "it.easylesson.LIVE"

    fun enabled(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("on", false)

    fun setEnabled(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("on", on).apply()
        update(context)
    }

    private fun channel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Lezione in corso", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Materia, aula e tempo che manca, sempre in tendina durante la lezione"
                setShowBadge(false)
            }
        )
    }

    /** Ricalcola la notifica e programma il prossimo aggiornamento. */
    fun update(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!enabled(context) || !Reminders.allowed(context)) {
            nm.cancel(ID)
            cancelTick(context)
            return
        }
        val cal = Calendar.getInstance()
        val minute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val n = LessonWidget.compute(context, cal)
        val change = n.nextChange
        val now = n.label.startsWith("ADESSO")
        val soon = n.label.startsWith("PROSSIMA") && change != null && change - minute in 0..10
        if (!now && !soon) {
            nm.cancel(ID)
            // Si ricontrolla al prossimo cambio (10 minuti prima) o tra mezz'ora.
            scheduleTick(context, if (change != null) maxOf(1, change - minute - 10) else 30)
            return
        }
        channel(context)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val place = if (n.place.isNotEmpty()) " · ${n.place}" else ""
        builder
            .setSmallIcon(R.drawable.ic_stat_lesson)
            .setContentTitle(n.title)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(LessonWidget.openApp(context, 9, "easylesson://mine"))
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (now && change != null) {
            // Durata della lezione: dall'inizio (salvato al primo giro) alla fine.
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val key = "${LessonWidget.iso(cal)}-$change-${n.title}"
            val start = if (prefs.getString("key", "") == key) prefs.getInt("start", minute) else {
                prefs.edit().putString("key", key).putInt("start", minute).apply()
                minute
            }
            val total = maxOf(1, change - minOf(start, change - 1))
            val left = change - minute
            builder.setContentText("Fino alle ${n.time}$place · mancano $left min")
                .setProgress(total, total - left, false)
            if (n.next.isNotEmpty()) builder.setSubText(n.next)
            promote(builder, "$left min")
            scheduleTick(context, 1)
        } else {
            builder.setContentText("Alle ${n.time}$place · tra ${(change ?: minute) - minute} min")
            promote(builder, n.time)
            scheduleTick(context, 1)
        }
        nm.notify(ID, builder.build())
    }

    /** Android 16+: notifica "in evidenza" (Live Update). Con riflessione: funziona anche se si compila con un SDK più vecchio. */
    private fun promote(builder: Notification.Builder, chip: String) {
        if (Build.VERSION.SDK_INT < 36) return
        try {
            builder.javaClass.getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType).invoke(builder, true)
            builder.javaClass.getMethod("setShortCriticalText", String::class.java).invoke(builder, chip)
        } catch (e: Exception) {
            android.util.Log.w("LiveLesson", "Live Update non disponibile: $e")
        }
    }

    private fun tickIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, 11,
        Intent(context, ReminderReceiver::class.java).setAction(ACTION),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun scheduleTick(context: Context, minutes: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = Calendar.getInstance().apply {
            add(Calendar.MINUTE, minutes)
            set(Calendar.SECOND, 2)
        }.timeInMillis
        // Non esatta (niente permesso speciale): Android la può spostare di poco.
        if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC, at, tickIntent(context))
        else am.set(AlarmManager.RTC, at, tickIntent(context))
    }

    private fun cancelTick(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(tickIntent(context))
    }
}
