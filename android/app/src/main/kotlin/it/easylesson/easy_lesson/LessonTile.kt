package it.easylesson.easy_lesson

import android.annotation.TargetApi
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import java.util.Calendar

/** Riquadro nelle impostazioni rapide (tendina): la lezione di adesso o la prossima. */
@TargetApi(24)
class LessonTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val n = LessonWidget.compute(this, Calendar.getInstance())
        tile.label = if (n.time.isEmpty()) "Easy Lesson" else n.title
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when {
                n.time.isEmpty() -> n.title
                n.label.startsWith("ADESSO") -> "fino alle ${n.time}"
                else -> "alle ${n.time}"
            }
        }
        tile.state = if (n.time.isEmpty()) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.updateTile()
    }

    @Suppress("DEPRECATION")
    override fun onClick() {
        super.onClick()
        val i = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(
                android.app.PendingIntent.getActivity(
                    this, 5, i,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
            )
        } else {
            startActivityAndCollapse(i)
        }
    }
}
