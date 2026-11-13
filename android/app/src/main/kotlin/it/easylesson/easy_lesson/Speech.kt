package it.easylesson.easy_lesson

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

/**
 * 3.9: lettura ad alta voce con il motore TTS del telefono (niente rete, niente librerie).
 * Si crea alla prima frase e resta pronto finché l'app è aperta.
 */
object Speech {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: Triple<String, String, Float>? = null

    fun speak(ctx: Context, text: String, lang: String, rate: Float) {
        val t = tts
        if (t == null) {
            pending = Triple(text, lang, rate)
            tts = TextToSpeech(ctx.applicationContext) { status ->
                ready = status == TextToSpeech.SUCCESS
                pending?.let { (a, b, c) -> if (ready) say(a, b, c) }
                pending = null
            }
            return
        }
        if (!ready) {
            pending = Triple(text, lang, rate)
            return
        }
        say(text, lang, rate)
    }

    private fun say(text: String, lang: String, rate: Float) {
        val t = tts ?: return
        t.language = Locale.forLanguageTag(lang)
        t.setSpeechRate(rate.coerceIn(0.5f, 1.5f))
        t.speak(text.take(TextToSpeech.getMaxSpeechInputLength() - 1), TextToSpeech.QUEUE_FLUSH, null, "el")
    }

    fun stop() {
        tts?.stop()
    }

    fun shutdown() {
        tts?.shutdown()
        tts = null
        ready = false
    }
}
