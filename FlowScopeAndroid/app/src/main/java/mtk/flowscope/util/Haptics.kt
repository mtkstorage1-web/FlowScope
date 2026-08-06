package mtk.flowscope.util

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import mtk.flowscope.theme.AppSettings

/**
 * Ported from `HapticManager.swift`. UIKit's feedback generators map onto
 * Android's predefined effects where they exist, falling back to short
 * one-shot amplitudes elsewhere.
 */
class HapticManager private constructor(private val context: Context) {

    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(VibratorManager::class.java)
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun enabled() = AppSettings.get(context).hapticsEnabled

    private fun oneShot(millis: Long, amplitude: Int) {
        if (!enabled()) return
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        v.vibrate(VibrationEffect.createOneShot(millis, amplitude))
    }

    private fun predefined(effect: Int, fallbackMillis: Long, fallbackAmplitude: Int) {
        if (!enabled()) return
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            v.vibrate(VibrationEffect.createPredefined(effect))
        } else {
            v.vibrate(VibrationEffect.createOneShot(fallbackMillis, fallbackAmplitude))
        }
    }

    fun lightImpact() = predefined(VibrationEffect.EFFECT_TICK, 10, 60)

    fun mediumImpact() = predefined(VibrationEffect.EFFECT_CLICK, 20, 140)

    fun heavyImpact() = predefined(VibrationEffect.EFFECT_HEAVY_CLICK, 30, 255)

    /** Two quick taps — the closest thing to UINotificationFeedbackGenerator.success. */
    fun successFeedback() {
        if (!enabled()) return
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        v.vibrate(
            VibrationEffect.createWaveform(
                longArrayOf(0, 18, 60, 28),
                intArrayOf(0, 160, 0, 220),
                -1,
            ),
        )
    }

    fun selectionFeedback() = oneShot(8, 40)

    companion object {
        @Volatile
        private var instance: HapticManager? = null

        fun get(context: Context): HapticManager =
            instance ?: synchronized(this) {
                instance ?: HapticManager(context.applicationContext).also { instance = it }
            }
    }
}
