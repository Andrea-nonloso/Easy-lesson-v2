package it.easylesson.easy_lesson

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Widget "Easy Lesson": lezione di adesso e la prossima.
 * Flutter salva l'orario della settimana in JSON (vedi lib/native.dart);
 * il widget calcola da solo cosa mostrare e si riaggiorna al cambio d'ora.
 *
 * JSON: {"name":"1A IT", "days":[[{"s":470,"e":520,"t":"Matematica","p":"🧪 W Chim"}, ...], ...],
 *        "off":[["2026-12-23","2027-01-06","🎄 Vacanze di Natale"], ...]}
 * (giorni: 0 = lunedì; s/e = minuti dalla mezzanotte)
 */
class LessonWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    companion object {
        private const val PREFS = "easylesson_widget"
        private val DAYS = arrayOf("Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom")

        fun save(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("json", json).apply()
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, LessonWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun hm(m: Int) = String.format(Locale.ITALY, "%02d:%02d", m / 60, m % 60)

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.lesson_widget)
            val open = PendingIntent.getActivity(
                context, 1,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)

            val cal = Calendar.getInstance()
            val minute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            val dow = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 // 0 = lunedì
            val today = String.format(
                Locale.ITALY, "%04d-%02d-%02d",
                cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH)
            )
            var nextChange: Int? = null

            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("json", null)
            var header = "Easy Lesson"
            var label = ""
            var title = "Apri l'app per impostare il tuo orario"
            var place = ""
            var next = ""
            try {
                if (raw != null) {
                    val o = JSONObject(raw)
                    header = "${o.optString("name", "Easy Lesson")} · ${DAYS[dow]} ${cal.get(Calendar.DAY_OF_MONTH)}/${cal.get(Calendar.MONTH) + 1}"
                    var offName: String? = null
                    val off = o.optJSONArray("off")
                    if (off != null) {
                        for (k in 0 until off.length()) {
                            val r = off.getJSONArray(k)
                            if (today >= r.getString(0) && today <= r.getString(1)) offName = r.getString(2)
                        }
                    }
                    val days = o.optJSONArray("days")
                    val lessons = if (days != null && dow < days.length()) days.getJSONArray(dow) else null
                    when {
                        offName != null -> {
                            label = "OGGI NIENTE SCUOLA"
                            title = offName
                        }
                        lessons == null || lessons.length() == 0 -> {
                            label = "OGGI"
                            title = "Nessuna lezione 🎉"
                        }
                        else -> {
                            var cur = -1
                            var nxt = -1
                            for (k in 0 until lessons.length()) {
                                val l = lessons.getJSONObject(k)
                                val s = l.getInt("s")
                                val e = l.getInt("e")
                                if (minute in s until e) cur = k
                                if (s > minute && nxt < 0) nxt = k
                            }
                            if (cur >= 0) {
                                val l = lessons.getJSONObject(cur)
                                label = "ADESSO · fino alle ${hm(l.getInt("e"))}"
                                title = l.getString("t")
                                place = l.optString("p", "")
                                nextChange = l.getInt("e")
                            } else if (nxt >= 0) {
                                val l = lessons.getJSONObject(nxt)
                                label = "PROSSIMA · alle ${hm(l.getInt("s"))}"
                                title = l.getString("t")
                                place = l.optString("p", "")
                                nextChange = l.getInt("s")
                            } else {
                                label = "OGGI"
                                title = "Lezioni finite! 🎉"
                            }
                            val after = if (cur >= 0) nxt.takeIf { it > cur } ?: -1 else if (nxt >= 0 && nxt + 1 < lessons.length()) nxt + 1 else -1
                            if (after >= 0) {
                                val l = lessons.getJSONObject(after)
                                next = "Poi: ${l.getString("t")} alle ${hm(l.getInt("s"))}"
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                title = "Apri l'app per aggiornare"
            }

            views.setTextViewText(R.id.widget_header, header)
            views.setTextViewText(R.id.widget_label, label)
            views.setViewVisibility(R.id.widget_label, if (label.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_place, place)
            views.setViewVisibility(R.id.widget_place, if (place.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_next, next)
            views.setViewVisibility(R.id.widget_next, if (next.isEmpty()) View.GONE else View.VISIBLE)
            manager.updateAppWidget(ids, views)

            scheduleNext(context, nextChange, cal)
        }

        /** Riaggiorna il widget al prossimo cambio d'ora (o tra mezz'ora). */
        private fun scheduleNext(context: Context, minuteOfDay: Int?, now: Calendar) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val i = Intent(context, LessonWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val ids = AppWidgetManager.getInstance(context)
                    .getAppWidgetIds(ComponentName(context, LessonWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            val pi = PendingIntent.getBroadcast(
                context, 7, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val at = (now.clone() as Calendar).apply {
                if (minuteOfDay != null) {
                    set(Calendar.HOUR_OF_DAY, minuteOfDay / 60)
                    set(Calendar.MINUTE, minuteOfDay % 60)
                    set(Calendar.SECOND, 5)
                } else {
                    add(Calendar.MINUTE, 30)
                }
            }.timeInMillis
            am.set(AlarmManager.RTC, at, pi)
        }
    }
}
