package it.easylesson.easy_lesson

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Icona dell'app a scelta: ogni colore è un <activity-alias> nel manifest,
 * se ne tiene acceso uno solo. Il launcher può metterci qualche secondo ad aggiornarla.
 */
object AppIcons {
    val ids = listOf("default", "blue", "purple", "red", "orange", "pink", "black")

    private fun alias(id: String) = "it.easylesson.easy_lesson.Icon" + id.replaceFirstChar { it.uppercase() }

    fun current(context: Context): String {
        val pm = context.packageManager
        for (id in ids) {
            val state = pm.getComponentEnabledSetting(ComponentName(context.packageName, alias(id)))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return id
        }
        return "default"
    }

    fun set(context: Context, id: String) {
        if (id !in ids) return
        val pm = context.packageManager
        // Prima si accende la nuova, poi si spengono le altre (così c'è sempre un'icona).
        pm.setComponentEnabledSetting(
            ComponentName(context.packageName, alias(id)),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        for (other in ids) {
            if (other == id) continue
            pm.setComponentEnabledSetting(
                ComponentName(context.packageName, alias(other)),
                if (other == "default") PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}
