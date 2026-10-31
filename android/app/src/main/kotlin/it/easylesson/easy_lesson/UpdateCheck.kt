package it.easylesson.easy_lesson

import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject

/**
 * Controllo aggiornamenti in background: ogni 6 ore (con internet) guarda le
 * release su GitHub e, se c'è una versione più nuova di quella installata,
 * manda una notifica. Toccandola si apre il download dell'APK.
 */
object UpdateCheck {
    private const val PREFS = "easylesson_updates"
    private const val JOB_ID = 4242
    private const val PERIOD = 6L * 60 * 60 * 1000

    /** Impostazioni mandate da Flutter: {enabled, beta, current, repo}. */
    fun configure(context: Context, json: String) {
        val o = JSONObject(json)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("enabled", o.optBoolean("enabled", true))
            .putBoolean("beta", o.optBoolean("beta", false))
            .putString("current", o.optString("current", ""))
            .putString("repo", o.optString("repo", ""))
            .apply()
        ensureScheduled(context)
    }

    /** Programma il controllo periodico (o lo toglie se spento). */
    fun ensureScheduled(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        val enabled = prefs.getBoolean("enabled", false) && !prefs.getString("repo", "").isNullOrEmpty()
        val scheduled = js.allPendingJobs.any { it.id == JOB_ID }
        if (!enabled) {
            if (scheduled) js.cancel(JOB_ID)
            return
        }
        if (scheduled) return // già programmato: non si riparte da zero
        val info = JobInfo.Builder(JOB_ID, ComponentName(context, UpdateCheckJob::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setPeriodic(PERIOD)
            .setPersisted(true)
            .build()
        js.schedule(info)
    }

    private fun get(url: String): String {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 15000
        c.readTimeout = 15000
        c.setRequestProperty("Accept", "application/vnd.github+json")
        c.setRequestProperty("User-Agent", "EasyLesson-Android")
        try {
            if (c.responseCode != 200) throw IllegalStateException("HTTP ${c.responseCode}")
            return c.inputStream.bufferedReader().use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    /** Fa il controllo (in un thread, mai sul principale). [force] = notifica anche se già fatto. */
    fun run(context: Context, force: Boolean = false) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val repo = prefs.getString("repo", "") ?: ""
            val current = prefs.getString("current", "") ?: ""
            if (repo.isEmpty() || current.isEmpty()) return
            if (!force && !prefs.getBoolean("enabled", false)) return
            val beta = prefs.getBoolean("beta", false)
            var best: JSONObject? = null
            if (beta) {
                val list = JSONArray(get("https://api.github.com/repos/$repo/releases?per_page=20"))
                for (k in 0 until list.length()) {
                    val r = list.getJSONObject(k)
                    if (r.optBoolean("draft")) continue
                    if (best == null || compareVersions(tag(r), tag(best)) > 0) best = r
                }
            } else {
                best = JSONObject(get("https://api.github.com/repos/$repo/releases/latest"))
            }
            val r = best ?: return
            val latest = tag(r)
            if (latest.isEmpty() || compareVersions(latest, current) <= 0) return
            if (!force && prefs.getString("notified", "") == latest) return
            prefs.edit().putString("notified", latest).apply()

            var url = r.optString("html_url", "https://github.com/$repo/releases")
            val assets = r.optJSONArray("assets")
            if (assets != null) {
                for (k in 0 until assets.length()) {
                    val a = assets.getJSONObject(k)
                    if (a.optString("name").lowercase().endsWith(".apk")) {
                        url = a.optString("browser_download_url", url)
                        break
                    }
                }
            }
            val open = PendingIntent.getActivity(
                context, 77,
                Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val pre = if (r.optBoolean("prerelease")) " (beta)" else ""
            Reminders.show(
                context, 77,
                "È uscito Easy Lesson $latest$pre 🎉",
                "Tocca per scaricare l'aggiornamento (hai la $current)",
                "aggiornamenti", open
            )
        } catch (e: Exception) {
            // Niente internet o GitHub non risponde: si riprova al prossimo giro.
        }
    }

    private fun tag(r: JSONObject): String = r.optString("tag_name", "").removePrefix("v")

    /** Come compareVersions in updater.dart: "2.5.0-beta.1" < "2.5.0-beta.2" < "2.5.0". */
    fun compareVersions(a: String, b: String): Int {
        fun core(v: String) = v.substringBefore('+').substringBefore('-')
        fun pre(v: String): String {
            val s = v.substringBefore('+')
            val i = s.indexOf('-')
            return if (i < 0) "" else s.substring(i + 1)
        }
        val pa = core(a).split('.').map { it.toIntOrNull() ?: 0 }
        val pb = core(b).split('.').map { it.toIntOrNull() ?: 0 }
        for (i in 0 until 3) {
            val x = pa.getOrElse(i) { 0 }
            val y = pb.getOrElse(i) { 0 }
            if (x != y) return x.compareTo(y)
        }
        val ra = pre(a)
        val rb = pre(b)
        if (ra == rb) return 0
        if (ra.isEmpty()) return 1
        if (rb.isEmpty()) return -1
        val xa = ra.split('.')
        val xb = rb.split('.')
        for (i in 0 until minOf(xa.size, xb.size)) {
            val na = xa[i].toIntOrNull()
            val nb = xb[i].toIntOrNull()
            val c = if (na != null && nb != null) na.compareTo(nb) else xa[i].compareTo(xb[i])
            if (c != 0) return c
        }
        return xa.size.compareTo(xb.size)
    }
}

class UpdateCheckJob : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        Thread {
            UpdateCheck.run(applicationContext)
            jobFinished(params, false)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true
}
