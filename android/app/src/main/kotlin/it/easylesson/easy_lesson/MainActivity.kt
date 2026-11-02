package it.easylesson.easy_lesson

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Ponte tra Flutter e Android (canale "easylesson/native"):
 * notifiche delle lezioni, widget della schermata home e scorciatoie dell'icona.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** Scorciatoia con cui è stata aperta l'app (es. "mine"), letta da Flutter all'avvio. */
    private var pendingShortcut: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingShortcut = shortcutOf(intent)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "easylesson/native")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleNotifications" -> {
                        Reminders.schedule(this, call.arguments as? String ?: "[]")
                        result.success(true)
                    }
                    "notificationsAllowed" -> result.success(Reminders.allowed(this))
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 && !Reminders.allowed(this)) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 42)
                        }
                        result.success(Reminders.allowed(this))
                    }
                    "updateWidget" -> {
                        LessonWidget.save(this, call.arguments as? String ?: "{}")
                        LessonWidget.updateAll(this)
                        result.success(true)
                    }
                    "testNotification" -> {
                        val o = JSONObject(call.arguments as? String ?: "{}")
                        Reminders.show(
                            this, 999, o.optString("title", "Easy Lesson"), o.optString("body", ""),
                            o.optString("ch", "lezioni")
                        )
                        result.success(true)
                    }
                    "scheduleOne" -> {
                        val o = JSONObject(call.arguments as? String ?: "{}")
                        Reminders.one(this, o.getInt("id"), o.getLong("at"), o.optString("title"), o.optString("body"))
                        result.success(true)
                    }
                    "cancelOne" -> {
                        Reminders.cancelOne(this, (call.arguments as? Int) ?: 7000)
                        result.success(true)
                    }
                    "openNotificationSettings" -> {
                        val i = if (Build.VERSION.SDK_INT >= 26) {
                            Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(android.net.Uri.parse("package:$packageName"))
                        }
                        startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "keepScreenOn" -> {
                        if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(true)
                    }
                    "silenceNow" -> {
                        SchoolSilence.apply(this, call.arguments == true)
                        result.success(true)
                    }
                    "silenceAllowed" -> result.success(SchoolSilence.allowed(this))
                    "openSilenceSettings" -> {
                        SchoolSilence.openSettings(this)
                        result.success(true)
                    }
                    "scheduleSilence" -> {
                        SchoolSilence.schedule(this, call.arguments as? String ?: "[]")
                        result.success(true)
                    }
                    "getAppIcon" -> result.success(AppIcons.current(this))
                    "setAppIcon" -> {
                        AppIcons.set(this, call.arguments as? String ?: "default")
                        result.success(true)
                    }
                    "configureUpdates" -> {
                        UpdateCheck.configure(this, call.arguments as? String ?: "{}")
                        result.success(true)
                    }
                    "runUpdateCheck" -> {
                        Thread { UpdateCheck.run(applicationContext, force = true) }.start()
                        result.success(true)
                    }
                    "takeShortcut" -> {
                        result.success(pendingShortcut)
                        pendingShortcut = null
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native", e.message, null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val s = shortcutOf(intent) ?: return
        channel?.invokeMethod("shortcut", s)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 42) {
            val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            channel?.invokeMethod("notificationPermission", ok)
        }
    }

    private fun shortcutOf(intent: Intent?): String? {
        val data = intent?.data ?: return null
        if (data.scheme != "easylesson") return null
        // I codici condivisi con il QR arrivano interi (easylesson://import?d=...).
        return if (data.host == "import") data.toString() else data.host
    }
}
