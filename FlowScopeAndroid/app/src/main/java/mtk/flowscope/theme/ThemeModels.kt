package mtk.flowscope.theme

import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.BlurOn
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.StarRate
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.Layers
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * The data layer of the Dynamic Theme Engine, ported from `ThemeEngine.swift`.
 *
 * `ThemeConfiguration` is the app's set of "CSS variables" — screens never
 * branch on the theme, they read values from here.
 */

// MARK: - App Theme

enum class AppTheme(val id: String, val displayName: String) {
    Flame("flame", "Flame"),
    Lightning("lightning", "Lightning"),
    Laser("laser", "Laser"),
    Cyberpunk("cyberpunk", "Cyberpunk"),
    Aurora("aurora", "Aurora"),
    DarkMatter("darkMatter", "Dark Matter"),
    Lava("lava", "Lava"),
    Neon80s("neon80s", "Neon 80s"),
    Galaxy("galaxy", "Galaxy"),
    BurningEmber("burningEmber", "Burning Ember");

    /** Closest Material equivalent of each theme's SF Symbol. */
    val icon: ImageVector
        get() = when (this) {
            Flame -> Icons.Filled.LocalFireDepartment
            Lightning -> Icons.Filled.Bolt
            Laser -> Icons.Filled.GridOn
            Cyberpunk -> Icons.Filled.Layers
            Aurora -> Icons.Filled.AutoAwesome
            DarkMatter -> Icons.Filled.NightsStay
            Lava -> Icons.Filled.Terrain
            Neon80s -> Icons.Filled.GridView
            Galaxy -> Icons.Filled.StarRate
            BurningEmber -> Icons.Filled.BlurOn
        }

    companion object {
        fun fromId(id: String?): AppTheme = entries.firstOrNull { it.id == id } ?: Flame
    }
}

// MARK: - Style value types

/** A shadow layer. Themes can stack several (Cyberpunk's chromatic aberration). */
data class ThemeShadow(
    val color: Color,
    val radius: Dp,
    val x: Dp = 0.dp,
    val y: Dp = 0.dp,
)

/** Shapes a themed button can take. Resolved in `ThemeButtonShape`. */
sealed interface ThemeButtonShapeStyle {
    data object Circle : ThemeButtonShapeStyle
    data class RoundedSquare(val radius: Dp) : ThemeButtonShapeStyle
    data object SharpSquare : ThemeButtonShapeStyle
    data object Capsule : ThemeButtonShapeStyle
    data object Hexagon : ThemeButtonShapeStyle
    data object Jagged : ThemeButtonShapeStyle
}

/** How the digits animate. */
sealed interface DigitAnimationStyle {
    data object None : DigitAnimationStyle
    data class Breathing(val period: Double, val min: Double) : DigitAnimationStyle
    data class Flicker(val min: Dp, val max: Dp) : DigitAnimationStyle
    data class GradientWave(val period: Double) : DigitAnimationStyle
    data class FadingStutter(val period: Double) : DigitAnimationStyle
}

/**
 * How a theme animates in when selected. Lightning should snap and Aurora
 * should dissolve — one shared crossfade made all ten feel identical.
 */
enum class ThemeTransitionStyle {
    FlashCut, Dissolve, Crossfade, Glitch;

    fun <T> animation(): AnimationSpec<T> = when (this) {
        FlashCut -> tween(280)
        Dissolve -> tween(1100)
        Crossfade -> tween(800)
        Glitch -> spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMedium)
    }

    val durationMillis: Int
        get() = when (this) {
            FlashCut -> 280
            Dissolve -> 1100
            Crossfade -> 800
            Glitch -> 320
        }
}

/** Which Canvas particle field the background renders. */
sealed interface ParticleConfiguration {
    data class Embers(val rising: Boolean, val fade: Boolean) : ParticleConfiguration
    data object LightningBolts : ParticleConfiguration
    data object NeonGrid : ParticleConfiguration
    data object Scanlines : ParticleConfiguration
    data object GlassOrbs : ParticleConfiguration
    data object AuroraCurtains : ParticleConfiguration
    data object EmberBed : ParticleConfiguration
    data object Stars : ParticleConfiguration
    data object LavaCracks : ParticleConfiguration
    data object RetroGrid : ParticleConfiguration
    data object Sparkles : ParticleConfiguration
}

/**
 * Font "design" families. Android has no SF Rounded equivalent, so Rounded
 * falls back to the system sans — the weight and corner radius still carry
 * each theme's character.
 */
enum class FontDesign {
    Default, Monospaced, Rounded;

    val fontFamily: FontFamily
        get() = when (this) {
            Default -> FontFamily.Default
            Monospaced -> FontFamily.Monospace
            Rounded -> FontFamily.SansSerif
        }
}

enum class GradientDirection { TopLeadingToBottomTrailing, LeadingToTrailing }

// MARK: - Sub-configurations

data class DigitStyle(
    val fontSize: androidx.compose.ui.unit.TextUnit,
    val fontWeight: FontWeight,
    val fontDesign: FontDesign,
    val gradientColors: List<Color>,
    val gradientDirection: GradientDirection = GradientDirection.TopLeadingToBottomTrailing,
    val blur: Dp = 0.dp,
    val shadows: List<ThemeShadow>,
    val animation: DigitAnimationStyle,
)

data class RingStyle(
    val lineWidth: Dp,
    val colors: List<Color>,
    val usesAngularGradient: Boolean = false,
    val design: RingDesign = RingDesign.SolidGlow,
    val glow: ThemeShadow?,
    val trackColor: Color,
)

data class ButtonStyleConfig(
    val shape: ThemeButtonShapeStyle,
    val backgroundColors: List<Color>,
    val usesMaterial: Boolean = false,
    val iconColor: Color,
    val borderColor: Color? = null,
    val borderWidth: Dp = 0.dp,
    val shadow: ThemeShadow? = null,
    val pulse: Boolean = false,
)

data class TabStyleConfig(
    val selectedColors: List<Color>,
    val unselectedColor: Color,
    val backgroundTint: Color = Color.Transparent,
)

// MARK: - Theme Configuration

/** Holds *all* styling properties for a theme. */
data class ThemeConfiguration(
    val theme: AppTheme,
    val fontDesign: FontDesign,
    val fontWeight: FontWeight,
    val cornerRadius: Dp,
    val primary: Color,
    val secondary: Color,
    val backgroundTop: Color,
    val backgroundBottom: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val surface: Color,
    val digits: DigitStyle,
    val ring: RingStyle,
    val button: ButtonStyleConfig,
    val tabs: TabStyleConfig,
    val particles: ParticleConfiguration,
    val transition: ThemeTransitionStyle,
    /** Palette used for chart marks. */
    val chartColors: List<Color>,
) {
    val backgroundColors: List<Color> get() = listOf(backgroundTop, backgroundBottom)
    val accentColors: List<Color> get() = listOf(primary, secondary)
}

/** Abstracts the enum → configuration mapping so ThemeManager holds state only. */
interface ThemeEngine {
    fun configuration(theme: AppTheme): ThemeConfiguration
}
