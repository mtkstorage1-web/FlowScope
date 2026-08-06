package mtk.flowscope.theme

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Per-theme user overrides, ported from `ThemeCustomization.swift`.
 *
 * Lets you recolour any theme without losing its identity — Flame at +210° hue
 * becomes blue fire and keeps the embers, the heavy digits and the breathing glow.
 */

// MARK: - Ring design

/**
 * The shape language of the progress ring. Deliberately no dashed/dotted
 * options — those read as cheap at this size.
 */
enum class RingDesign(val id: String, val label: String) {
    SolidGlow("solidGlow", "Solid Glow"),
    NeonTube("neonTube", "Neon Tube"),
    CometTrail("cometTrail", "Comet"),
    DoubleOrbit("doubleOrbit", "Orbit"),
    SegmentedArc("segmentedArc", "Segments"),
    TaperedArc("taperedArc", "Tapered"),
    Hairline("hairline", "Hairline"),
    PulseRing("pulseRing", "Pulse"),
    RadarSweep("radarSweep", "Radar");

    companion object {
        fun fromId(id: String?): RingDesign? = entries.firstOrNull { it.id == id }
    }
}

// MARK: - Customization

@Serializable
data class ThemeCustomization(
    /** Degrees, -180..180. This is what turns red fire into blue fire. */
    val hueShift: Double = 0.0,
    /** Multiplier, 0..1.6. */
    val saturation: Double = 1.0,
    /** Multiplier, 0.6..1.5. */
    val brightness: Double = 1.0,
    /** Overrides the theme's default ring design when set. */
    val ringDesignId: String? = null,
) {
    val ringDesign: RingDesign? get() = RingDesign.fromId(ringDesignId)

    val isCustomized: Boolean get() = this != None

    companion object {
        val None = ThemeCustomization()
    }
}

// MARK: - Store

/**
 * Persists overrides per theme. Backed by SharedPreferences and mirrored into
 * Compose state so recolouring updates the UI immediately.
 */
class ThemeCustomizationStore private constructor(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences("flowscope.theme", Context.MODE_PRIVATE)

    private val json = Json { ignoreUnknownKeys = true }

    /** Bumped on every write so Compose recomposes anything reading a config. */
    var revision by mutableStateOf(0)
        private set

    private var cache: MutableMap<String, ThemeCustomization> = runCatching {
        val raw = prefs.getString(KEY, null) ?: return@runCatching mutableMapOf()
        json.decodeFromString<Map<String, ThemeCustomization>>(raw).toMutableMap()
    }.getOrElse { mutableMapOf() }

    fun customization(theme: AppTheme): ThemeCustomization =
        cache[theme.id] ?: ThemeCustomization.None

    fun set(customization: ThemeCustomization, theme: AppTheme) {
        cache[theme.id] = customization
        persist()
    }

    fun reset(theme: AppTheme) {
        cache.remove(theme.id)
        persist()
    }

    fun resetAll() {
        cache.clear()
        persist()
    }

    private fun persist() {
        prefs.edit().putString(KEY, json.encodeToString(cache as Map<String, ThemeCustomization>)).apply()
        revision++
    }

    companion object {
        private const val KEY = "theme.customizations"

        @Volatile
        private var instance: ThemeCustomizationStore? = null

        fun get(context: Context): ThemeCustomizationStore =
            instance ?: synchronized(this) {
                instance ?: ThemeCustomizationStore(context).also { instance = it }
            }
    }
}
