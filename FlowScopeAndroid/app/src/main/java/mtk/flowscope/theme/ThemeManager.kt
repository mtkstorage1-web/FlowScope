package mtk.flowscope.theme

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import mtk.flowscope.data.SharedThemePalette
import mtk.flowscope.data.SharedThemeStore
import mtk.flowscope.util.toHexString

/**
 * Holds theme *state* only — all styling logic is injected via a [ThemeEngine],
 * so this type never branches on the theme itself. Ported from `ThemeManager.swift`.
 */
class ThemeManager private constructor(private val context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences("flowscope.theme", Context.MODE_PRIVATE)

    private val customStore = ThemeCustomizationStore.get(context)

    private val engine: ThemeEngine = ThemeProvider { customStore.customization(it) }

    var currentTheme: AppTheme by mutableStateOf(
        AppTheme.fromId(prefs.getString(KEY_THEME, null)),
    )
        private set

    init {
        publishPaletteToWidgets()
    }

    /** The active configuration — every screen reads its styling from here. */
    val configuration: ThemeConfiguration
        get() {
            // Touching the store's revision makes Compose re-read the config
            // after the user recolours a theme.
            @Suppress("UNUSED_EXPRESSION")
            customStore.revision
            return engine.configuration(currentTheme)
        }

    fun configuration(theme: AppTheme): ThemeConfiguration {
        @Suppress("UNUSED_EXPRESSION")
        customStore.revision
        return engine.configuration(theme)
    }

    fun switchTheme(theme: AppTheme) {
        currentTheme = theme
        prefs.edit().putString(KEY_THEME, theme.id).apply()
        publishPaletteToWidgets()
    }

    fun resetToDefault() = switchTheme(AppTheme.Flame)

    /** Re-publishes the palette after a customisation edit. */
    fun refreshPalette() = publishPaletteToWidgets()

    /**
     * Mirrors the active palette into shared storage so the home-screen widgets
     * and the ongoing notification all render in the same theme.
     */
    private fun publishPaletteToWidgets() {
        val c = engine.configuration(currentTheme)
        SharedThemeStore.write(
            context,
            SharedThemePalette(
                themeId = c.theme.id,
                displayName = c.theme.displayName,
                primaryHex = c.primary.toHexString(),
                secondaryHex = c.secondary.toHexString(),
                backgroundTopHex = c.backgroundTop.toHexString(),
                backgroundBottomHex = c.backgroundBottom.toHexString(),
                textPrimaryHex = c.textPrimary.toHexString(),
                textSecondaryHex = c.textSecondary.toHexString(),
                surfaceHex = c.surface.toHexString(),
                cornerRadius = c.cornerRadius.value.toDouble(),
            ),
        )
    }

    companion object {
        private const val KEY_THEME = "theme.selectedTheme"

        @Volatile
        private var instance: ThemeManager? = null

        fun get(context: Context): ThemeManager =
            instance ?: synchronized(this) {
                instance ?: ThemeManager(context.applicationContext).also { instance = it }
            }
    }
}
