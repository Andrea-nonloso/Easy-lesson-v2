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
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Widget "Easy Lesson": lezione di adesso e la prossima.
 * Flutter salva l'orario della settimana in JSON (vedi lib/native.dart);
 * il widget calcola da solo cosa mostrare e si riaggiorna al cambio d'ora.
 * Lo stesso calcolo serve al widget piccolo (NextWidget) e al riquadro delle impostazioni rapide.
 *
 * JSON: {"name":"1A IT", "days":[[{"s":470,"e":520,"t":"Matematica","p":"🧪 W Chim"}, ...], ...],
 *        "off":[["2026-12-23","2027-01-06","🎄 Vacanze di Natale"], ...],
 *        "only":[["2026-11-03", 520, 750]]   (entrata/uscita: solo le ore tra 520 e 750; -1 = assente)
 *        "agenda":[["2026-11-03","📝 Verifica · Matematica"], ...]}
 * (giorni: 0 = lunedì; s/e = minuti dalla mezzanotte)
 */
class LessonWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    /** Cosa mostrare adesso. */
    data class Now(
        val header: String,
        val label: String,
        val title: String,
        val place: String,
        val next: String,
        val nextChange: Int?,
        val time: String,
    )

    companion object {
        private const val PREFS = "easylesson_widget"
        private val DAYS = arrayOf("Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom")

        fun save(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("json", json).apply()
        }

        fun data(context: Context): JSONObject? = try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("json", null)?.let { JSONObject(it) }
        } catch (e: Exception) {
            null
        }

        /** Aggiorna tutti i widget (grande, piccolo, agenda) e il riquadro rapido. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, LessonWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
            NextWidget.updateAll(context)
            AgendaWidget.updateAll(context)
            GradesWidget.updateAll(context)
            scheduleNext(context, compute(context, Calendar.getInstance()).nextChange, Calendar.getInstance())
            LiveLesson.update(context)
        }

        fun hm(m: Int) = String.format(Locale.ITALY, "%02d:%02d", m / 60, m % 60)

        fun iso(cal: Calendar) = String.format(
            Locale.ITALY, "%04d-%02d-%02d",
            cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH)
        )

        fun openApp(context: Context, code: Int, uri: String? = null): PendingIntent {
            val i = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (uri != null) {
                i.action = Intent.ACTION_VIEW
                i.data = android.net.Uri.parse(uri)
            }
            return PendingIntent.getActivity(context, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun compute(context: Context, cal: Calendar): Now {
            val minute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            val dow = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 // 0 = lunedì
            val today = iso(cal)
            var nextChange: Int? = null
            var header = "Easy Lesson"
            var label = ""
            var title = "Apri l'app per impostare il tuo orario"
            var place = ""
            var next = ""
            var time = ""
            try {
                val o = data(context)
                if (o != null) {
                    header = "${o.optString("name", "Easy Lesson")} · ${DAYS[dow]} ${cal.get(Calendar.DAY_OF_MONTH)}/${cal.get(Calendar.MONTH) + 1}"
                    var offName: String? = null
                    val off = o.optJSONArray("off")
                    if (off != null) {
                        for (k in 0 until off.length()) {
                            val r = off.getJSONArray(k)
                            if (today >= r.getString(0) && today <= r.getString(1)) offName = r.getString(2)
                        }
                    }
                    // Entrate posticipate / uscite anticipate / assenze già segnate.
                    var from = 0
                    var to = 24 * 60
                    var absent = false
                    val only = o.optJSONArray("only")
                    if (only != null) {
                        for (k in 0 until only.length()) {
                            val r = only.getJSONArray(k)
                            if (r.getString(0) != today) continue
                            if (r.getInt(2) < 0) absent = true else {
                                from = r.getInt(1)
                                to = r.getInt(2)
                            }
                        }
                    }
                    val days = o.optJSONArray("days")
                    val all = if (days != null && dow < days.length()) days.getJSONArray(dow) else null
                    val lessons = JSONArray()
                    if (all != null) {
                        for (k in 0 until all.length()) {
                            val l = all.getJSONObject(k)
                            if (l.getInt("s") >= from && l.getInt("e") <= to) lessons.put(l)
                        }
                    }
                    when {
                        offName != null -> {
                            label = "OGGI NIENTE SCUOLA"
                            title = offName
                        }
                        absent -> {
                            label = "OGGI"
                            title = "Oggi non vai a scuola 🏠"
                        }
                        lessons.length() == 0 -> {
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
                                time = hm(l.getInt("e"))
                                title = l.getString("t")
                                place = l.optString("p", "")
                                nextChange = l.getInt("e")
                            } else if (nxt >= 0) {
                                val l = lessons.getJSONObject(nxt)
                                label = "PROSSIMA · alle ${hm(l.getInt("s"))}"
                                time = hm(l.getInt("s"))
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
            return Now(header, label, title, place, next, nextChange, time)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.lesson_widget)
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context, 1))
            val n = compute(context, Calendar.getInstance())
            views.setTextViewText(R.id.widget_header, n.header)
            views.setTextViewText(R.id.widget_label, n.label)
            views.setViewVisibility(R.id.widget_label, if (n.label.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_title, n.title)
            views.setTextViewText(R.id.widget_place, n.place)
            views.setViewVisibility(R.id.widget_place, if (n.place.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_next, n.next)
            views.setViewVisibility(R.id.widget_next, if (n.next.isEmpty()) View.GONE else View.VISIBLE)
            manager.updateAppWidget(ids, views)
            scheduleNext(context, n.nextChange, Calendar.getInstance())
        }

        /** Riaggiorna i widget al prossimo cambio d'ora (o tra mezz'ora). */
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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Allo scatto della sveglia si aggiornano anche gli altri widget.
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            NextWidget.updateAll(context)
            AgendaWidget.updateAll(context)
        }
    }
}

/** Widget piccolo (1×1 / 2×1): solo la prossima ora. */
class NextWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = render(context, manager, ids)

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, NextWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val n = LessonWidget.compute(context, Calendar.getInstance())
            val views = RemoteViews(context.packageName, R.layout.next_widget)
            views.setOnClickPendingIntent(R.id.next_root, LessonWidget.openApp(context, 2, "easylesson://mine"))
            views.setTextViewText(R.id.next_time, if (n.time.isEmpty()) "—" else n.time)
            views.setTextViewText(R.id.next_title, n.title)
            views.setTextViewText(R.id.next_place, n.place)
            views.setViewVisibility(R.id.next_place, if (n.place.isEmpty()) View.GONE else View.VISIBLE)
            manager.updateAppWidget(ids, views)
        }
    }
}

/** Widget agenda: compiti e verifiche dei prossimi giorni. */
class AgendaWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = render(context, manager, ids)

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, AgendaWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.agenda_widget)
            views.setOnClickPendingIntent(R.id.agenda_root, LessonWidget.openApp(context, 3, "easylesson://agenda"))
            val today = LessonWidget.iso(Calendar.getInstance())
            val tomorrow = LessonWidget.iso(Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, 1) })
            val sb = StringBuilder()
            try {
                val list = LessonWidget.data(context)?.optJSONArray("agenda")
                if (list != null) {
                    for (k in 0 until list.length()) {
                        val r = list.getJSONArray(k)
                        val d = r.getString(0)
                        if (d < today) continue
                        val day = when (d) {
                            today -> "Oggi"
                            tomorrow -> "Domani"
                            else -> d.substring(8, 10) + "/" + d.substring(5, 7)
                        }
                        if (sb.isNotEmpty()) sb.append('\n')
                        sb.append(day).append(" · ").append(r.getString(1))
                    }
                }
            } catch (e: Exception) {
                // dati non leggibili: si mostra il messaggio vuoto
            }
            views.setTextViewText(R.id.agenda_list, if (sb.isEmpty()) "Niente in programma 🎉" else sb.toString())
            manager.updateAppWidget(ids, views)
        }
    }
}

/** Widget dei voti: media generale e medie per materia. */
class GradesWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = render(context, manager, ids)

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, GradesWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.grades_widget)
            views.setOnClickPendingIntent(R.id.grades_root, LessonWidget.openApp(context, 4, "easylesson://grades"))
            val sb = StringBuilder()
            var avg = ""
            try {
                val o = LessonWidget.data(context)
                avg = o?.optString("gradesAvg", "") ?: ""
                val list = o?.optJSONArray("grades")
                if (list != null) {
                    for (k in 0 until list.length()) {
                        val r = list.getJSONArray(k)
                        if (sb.isNotEmpty()) sb.append('\n')
                        sb.append(r.getString(1)).append("  ").append(r.getString(0))
                    }
                }
            } catch (e: Exception) {
                // dati non leggibili
            }
            views.setTextViewText(R.id.grades_avg, if (avg.isEmpty()) "—" else avg)
            views.setTextViewText(R.id.grades_list, if (sb.isEmpty()) "Nessun voto: aggiungili dall'app" else sb.toString())
            manager.updateAppWidget(ids, views)
        }
    }
}
