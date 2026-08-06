package mtk.flowscope.theme

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.mutableStateOf

/**
 * Single source of truth for every user-tunable preference outside the theme
 * palette: effect intensity, motion, timing, feedback and layout.
 *
 * Ported from `AppSettings.swift`. SwiftUI's `@AppStorage` is replaced with
 * SharedPreferences mirrored into Compose state, so reads stay synchronous and
 * writes recompose immediately.
 */

enum class EffectIntensity(val id: String, val label: String) {
    Off("off", "Off"),
    Subtle("subtle", "Subtle"),
    Balanced("balanced", "Balanced"),
    Intense("intense", "Intense"),
    Maximum("maximum", "Max");

    /** Multiplies particle opacity / stroke weight. */
    val opacityScale: Double
        get() = when (this) {
            Off -> 0.0
            Subtle -> 0.5
            Balanced -> 1.0
            Intense -> 1.45
            Maximum -> 1.9
        }

    /** Multiplies how many particles are drawn. */
    val densityScale: Double
        get() = when (this) {
            Off -> 0.0
            Subtle -> 0.6
            Balanced -> 1.0
            Intense -> 1.5
            Maximum -> 2.0
        }

    companion object {
        fun fromId(id: String?) = entries.firstOrNull { it.id == id } ?: Balanced
    }
}

enum class AnimationSpeed(val id: String, val label: String) {
    Calm("calm", "Calm"),
    Normal("normal", "Normal"),
    Fast("fast", "Fast");

    val scale: Double
        get() = when (this) {
            Calm -> 0.55
            Normal -> 1.0
            Fast -> 1.7
        }

    companion object {
        fun fromId(id: String?) = entries.firstOrNull { it.id == id } ?: Normal
    }
}

/** What the big ring on the Focus screen measures. */
enum class RingMode(val id: String, val label: String, val explanation: String) {
    Cycle(
        "cycle",
        "Focus Cycle",
        "Ring fills over one focus block, then resets and counts a lap.",
    ),
    SessionGoal(
        "sessionGoal",
        "Session Goal",
        "Ring fills once over your whole target session length.",
    ),
    Hidden("hidden", "Hidden", "No ring — just the timer.");

    companion object {
        fun fromId(id: String?) = entries.firstOrNull { it.id == id } ?: Cycle
    }
}

class AppSettings private constructor(context: Context) {

    private val prefs: SharedPreferences = context.applicationContext
        .getSharedPreferences("flowscope.settings", Context.MODE_PRIVATE)

    // Backing Compose state, seeded from disk.

    private fun boolState(key: String, default: Boolean) =
        mutableStateOf(prefs.getBoolean(key, default))

    private fun intState(key: String, default: Int) =
        mutableStateOf(prefs.getInt(key, default))

    private fun doubleState(key: String, default: Double) =
        mutableStateOf(prefs.getFloat(key, default.toFloat()).toDouble())

    private fun stringState(key: String, default: String) =
        mutableStateOf(prefs.getString(key, default) ?: default)

    private val intensityRaw = stringState("settings.effectIntensity", EffectIntensity.Balanced.id)
    private val speedRaw = stringState("settings.animationSpeed", AnimationSpeed.Normal.id)
    private val ringModeRaw = stringState("settings.ringMode", RingMode.Cycle.id)

    private val parallaxState = boolState("settings.parallaxEnabled", true)
    private val animatedDigitsState = boolState("settings.animatedDigits", true)
    private val glowState = boolState("settings.glowEnabled", true)
    private val backgroundBlurState = doubleState("settings.backgroundBlur", 0.0)

    private val cycleMinutesState = intState("settings.cycleMinutes", 25)
    private val goalMinutesState = intState("settings.goalMinutes", 90)

    private val hapticsState = boolState("settings.hapticsEnabled", true)
    private val soundState = boolState("settings.soundEnabled", true)
    private val soundVolumeState = doubleState("settings.soundVolume", 0.7)
    private val cycleAlertState = boolState("settings.cycleAlert", true)

    private val floatingControlState = boolState("settings.floatingControlEnabled", true)
    private val keepScreenAwakeState = boolState("settings.keepScreenAwake", false)
    private val liveActivityState = boolState("settings.liveActivityEnabled", true)
    private val hideStatusBarState = boolState("settings.hideStatusBar", true)

    // Public accessors — read/write like plain properties.

    var parallaxEnabled: Boolean
        get() = parallaxState.value
        set(v) { parallaxState.value = v; prefs.edit().putBoolean("settings.parallaxEnabled", v).apply() }

    var animatedDigits: Boolean
        get() = animatedDigitsState.value
        set(v) { animatedDigitsState.value = v; prefs.edit().putBoolean("settings.animatedDigits", v).apply() }

    var glowEnabled: Boolean
        get() = glowState.value
        set(v) { glowState.value = v; prefs.edit().putBoolean("settings.glowEnabled", v).apply() }

    /** 0–100%. Softens the animated background so foreground UI pops. */
    var backgroundBlur: Double
        get() = backgroundBlurState.value
        set(v) { backgroundBlurState.value = v; prefs.edit().putFloat("settings.backgroundBlur", v.toFloat()).apply() }

    var cycleMinutes: Int
        get() = cycleMinutesState.value
        set(v) { cycleMinutesState.value = v; prefs.edit().putInt("settings.cycleMinutes", v).apply() }

    var goalMinutes: Int
        get() = goalMinutesState.value
        set(v) { goalMinutesState.value = v; prefs.edit().putInt("settings.goalMinutes", v).apply() }

    var hapticsEnabled: Boolean
        get() = hapticsState.value
        set(v) { hapticsState.value = v; prefs.edit().putBoolean("settings.hapticsEnabled", v).apply() }

    var soundEnabled: Boolean
        get() = soundState.value
        set(v) { soundState.value = v; prefs.edit().putBoolean("settings.soundEnabled", v).apply() }

    var soundVolume: Double
        get() = soundVolumeState.value
        set(v) { soundVolumeState.value = v; prefs.edit().putFloat("settings.soundVolume", v.toFloat()).apply() }

    var cycleAlert: Boolean
        get() = cycleAlertState.value
        set(v) { cycleAlertState.value = v; prefs.edit().putBoolean("settings.cycleAlert", v).apply() }

    var floatingControlEnabled: Boolean
        get() = floatingControlState.value
        set(v) { floatingControlState.value = v; prefs.edit().putBoolean("settings.floatingControlEnabled", v).apply() }

    var keepScreenAwake: Boolean
        get() = keepScreenAwakeState.value
        set(v) { keepScreenAwakeState.value = v; prefs.edit().putBoolean("settings.keepScreenAwake", v).apply() }

    /**
     * iOS calls this "Live Activity"; on Android it controls the ongoing
     * foreground-service notification that keeps the timer alive and visible.
     */
    var liveActivityEnabled: Boolean
        get() = liveActivityState.value
        set(v) { liveActivityState.value = v; prefs.edit().putBoolean("settings.liveActivityEnabled", v).apply() }

    var hideStatusBar: Boolean
        get() = hideStatusBarState.value
        set(v) { hideStatusBarState.value = v; prefs.edit().putBoolean("settings.hideStatusBar", v).apply() }

    var effectIntensity: EffectIntensity
        get() = EffectIntensity.fromId(intensityRaw.value)
        set(v) { intensityRaw.value = v.id; prefs.edit().putString("settings.effectIntensity", v.id).apply() }

    var animationSpeed: AnimationSpeed
        get() = AnimationSpeed.fromId(speedRaw.value)
        set(v) { speedRaw.value = v.id; prefs.edit().putString("settings.animationSpeed", v.id).apply() }

    var ringMode: RingMode
        get() = RingMode.fromId(ringModeRaw.value)
        set(v) { ringModeRaw.value = v.id; prefs.edit().putString("settings.ringMode", v.id).apply() }

    /** Seconds. */
    val cycleLength: Double get() = cycleMinutes * 60.0
    val goalLength: Double get() = goalMinutes * 60.0

    fun resetAll() {
        effectIntensity = EffectIntensity.Balanced
        animationSpeed = AnimationSpeed.Normal
        parallaxEnabled = true
        animatedDigits = true
        glowEnabled = true
        backgroundBlur = 0.0
        cycleMinutes = 25
        goalMinutes = 90
        ringMode = RingMode.Cycle
        hapticsEnabled = true
        soundEnabled = true
        soundVolume = 0.7
        cycleAlert = true
        floatingControlEnabled = true
        keepScreenAwake = false
        liveActivityEnabled = true
        hideStatusBar = true
    }

    companion object {
        val cycleOptions = listOf(10, 15, 20, 25, 30, 45, 50, 60)
        val goalOptions = listOf(30, 45, 60, 90, 120, 180, 240)

        @Volatile
        private var instance: AppSettings? = null

        fun get(context: Context): AppSettings =
            instance ?: synchronized(this) {
                instance ?: AppSettings(context).also { instance = it }
            }
    }
}
