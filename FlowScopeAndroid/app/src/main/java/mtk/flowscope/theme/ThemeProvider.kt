package mtk.flowscope.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.util.IOSColors
import mtk.flowscope.util.adjusted
import mtk.flowscope.util.colorFromHex

/**
 * Concrete [ThemeEngine]. All ten visual specifications live here, ported
 * one-for-one from `ThemeProvider` in ThemeEngine.swift.
 */
class ThemeProvider(
    private val customizationFor: (AppTheme) -> ThemeCustomization = { ThemeCustomization.None },
) : ThemeEngine {

    /** Applies the user's per-theme overrides on top of the designed palette. */
    override fun configuration(theme: AppTheme): ThemeConfiguration {
        val config = baseConfiguration(theme)
        val custom = customizationFor(theme)
        if (!custom.isCustomized) return config

        fun adj(c: Color) = c.adjusted(custom.hueShift, custom.saturation, custom.brightness)
        fun adjShadow(s: ThemeShadow) = s.copy(color = adj(s.color))

        return config.copy(
            primary = adj(config.primary),
            secondary = adj(config.secondary),
            backgroundTop = adj(config.backgroundTop),
            backgroundBottom = adj(config.backgroundBottom),
            textSecondary = adj(config.textSecondary),
            surface = adj(config.surface),
            chartColors = config.chartColors.map(::adj),
            digits = config.digits.copy(
                gradientColors = config.digits.gradientColors.map(::adj),
                shadows = config.digits.shadows.map(::adjShadow),
            ),
            ring = config.ring.copy(
                colors = config.ring.colors.map(::adj),
                trackColor = adj(config.ring.trackColor),
                glow = config.ring.glow?.let(::adjShadow),
                design = custom.ringDesign ?: config.ring.design,
            ),
            button = config.button.copy(
                backgroundColors = config.button.backgroundColors.map(::adj),
                iconColor = adj(config.button.iconColor),
                borderColor = config.button.borderColor?.let(::adj),
                shadow = config.button.shadow?.let(::adjShadow),
            ),
            tabs = config.tabs.copy(
                selectedColors = config.tabs.selectedColors.map(::adj),
                unselectedColor = adj(config.tabs.unselectedColor),
            ),
        )
    }

    private fun baseConfiguration(theme: AppTheme): ThemeConfiguration = when (theme) {
        AppTheme.Flame -> flame
        AppTheme.Lightning -> lightning
        AppTheme.Laser -> laser
        AppTheme.Cyberpunk -> cyberpunk
        AppTheme.Aurora -> aurora
        AppTheme.DarkMatter -> darkMatter
        AppTheme.Lava -> lava
        AppTheme.Neon80s -> neon80s
        AppTheme.Galaxy -> galaxy
        AppTheme.BurningEmber -> burningEmber
    }

    // MARK: 1. Flame

    private val flame = ThemeConfiguration(
        theme = AppTheme.Flame,
        fontDesign = FontDesign.Default,
        fontWeight = FontWeight.Black,
        cornerRadius = 14.dp,
        primary = colorFromHex("#FF6B1A"),
        secondary = colorFromHex("#FFC300"),
        backgroundTop = colorFromHex("#3B0A02"),
        backgroundBottom = colorFromHex("#1A0B04"),
        textPrimary = Color.White,
        textSecondary = colorFromHex("#FFB088"),
        surface = colorFromHex("#2A0D05"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Black,
            fontDesign = FontDesign.Default,
            gradientColors = listOf(IOSColors.Red, IOSColors.Orange, IOSColors.Yellow),
            shadows = listOf(ThemeShadow(IOSColors.Orange.copy(alpha = 0.8f), 30.dp)),
            animation = DigitAnimationStyle.Breathing(period = 0.2, min = 0.95),
        ),
        ring = RingStyle(
            lineWidth = 12.dp,
            colors = listOf(IOSColors.Red, IOSColors.Orange, IOSColors.Yellow, IOSColors.Red),
            usesAngularGradient = true,
            design = RingDesign.SolidGlow,
            glow = ThemeShadow(IOSColors.Orange, 10.dp),
            trackColor = IOSColors.Orange.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Circle,
            backgroundColors = listOf(IOSColors.Orange, IOSColors.Red),
            iconColor = IOSColors.Yellow,
            shadow = ThemeShadow(IOSColors.Orange, 25.dp),
            pulse = true,
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(IOSColors.Yellow, IOSColors.Red),
            unselectedColor = IOSColors.Orange,
            backgroundTint = IOSColors.Red.copy(alpha = 0.15f),
        ),
        particles = ParticleConfiguration.Embers(rising = true, fade = true),
        transition = ThemeTransitionStyle.Crossfade,
        chartColors = listOf(IOSColors.Red, IOSColors.Orange, IOSColors.Yellow),
    )

    // MARK: 2. Lightning

    private val lightning = ThemeConfiguration(
        theme = AppTheme.Lightning,
        fontDesign = FontDesign.Default,
        fontWeight = FontWeight.Light,
        cornerRadius = 4.dp,
        primary = colorFromHex("#00E5FF"),
        secondary = colorFromHex("#2B6BFF"),
        backgroundTop = colorFromHex("#0A1230"),
        backgroundBottom = Color.Black,
        textPrimary = Color.White,
        textSecondary = colorFromHex("#7FD8FF"),
        surface = colorFromHex("#0D1838"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Light,
            fontDesign = FontDesign.Default,
            gradientColors = listOf(colorFromHex("#00A6FF"), Color.White),
            shadows = listOf(ThemeShadow(IOSColors.Cyan.copy(alpha = 0.9f), 40.dp)),
            animation = DigitAnimationStyle.Flicker(min = 20.dp, max = 45.dp),
        ),
        ring = RingStyle(
            lineWidth = 6.dp,
            colors = listOf(IOSColors.Cyan, IOSColors.Blue),
            design = RingDesign.CometTrail,
            glow = ThemeShadow(IOSColors.Cyan, 8.dp),
            trackColor = IOSColors.Cyan.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Circle,
            backgroundColors = listOf(colorFromHex("#0091AD"), colorFromHex("#00C2E0")),
            iconColor = Color.White,
            shadow = ThemeShadow(IOSColors.Cyan, 20.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(Color.White),
            unselectedColor = IOSColors.Cyan.copy(alpha = 0.5f),
            backgroundTint = IOSColors.Blue.copy(alpha = 0.12f),
        ),
        particles = ParticleConfiguration.LightningBolts,
        transition = ThemeTransitionStyle.FlashCut,
        chartColors = listOf(IOSColors.Cyan, colorFromHex("#2B6BFF"), Color.White),
    )

    // MARK: 3. Laser

    private val laser = ThemeConfiguration(
        theme = AppTheme.Laser,
        fontDesign = FontDesign.Default,
        fontWeight = FontWeight.Medium,
        cornerRadius = 2.dp,
        primary = colorFromHex("#39FF14"),
        secondary = colorFromHex("#FF3EC9"),
        backgroundTop = colorFromHex("#050A12"),
        backgroundBottom = Color.Black,
        textPrimary = Color.White,
        textSecondary = colorFromHex("#8FFF7A"),
        surface = colorFromHex("#0A1018"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Medium,
            fontDesign = FontDesign.Default,
            gradientColors = listOf(colorFromHex("#39FF14"), colorFromHex("#FF3EC9")),
            gradientDirection = GradientDirection.LeadingToTrailing,
            shadows = listOf(ThemeShadow(colorFromHex("#FF3EC9"), 35.dp)),
            animation = DigitAnimationStyle.GradientWave(period = 3.0),
        ),
        ring = RingStyle(
            lineWidth = 4.dp,
            colors = listOf(colorFromHex("#39FF14")),
            design = RingDesign.SegmentedArc,
            glow = ThemeShadow(colorFromHex("#39FF14"), 8.dp),
            trackColor = IOSColors.Green.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Circle,
            backgroundColors = listOf(colorFromHex("#FF3EC9")),
            iconColor = colorFromHex("#39FF14"),
            shadow = ThemeShadow(colorFromHex("#39FF14"), 15.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(colorFromHex("#39FF14")),
            unselectedColor = colorFromHex("#4A4A4A"),
            backgroundTint = IOSColors.Green.copy(alpha = 0.08f),
        ),
        particles = ParticleConfiguration.NeonGrid,
        transition = ThemeTransitionStyle.Glitch,
        chartColors = listOf(colorFromHex("#39FF14"), colorFromHex("#FF3EC9"), IOSColors.Cyan),
    )

    // MARK: 4. Cyberpunk

    private val cyberpunk = ThemeConfiguration(
        theme = AppTheme.Cyberpunk,
        fontDesign = FontDesign.Monospaced,
        fontWeight = FontWeight.SemiBold,
        cornerRadius = 6.dp,
        primary = colorFromHex("#00E5FF"),
        secondary = colorFromHex("#B026FF"),
        backgroundTop = colorFromHex("#1A0033"),
        backgroundBottom = Color.Black,
        textPrimary = Color.White,
        textSecondary = colorFromHex("#C79BFF"),
        surface = colorFromHex("#200A3A"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.SemiBold,
            fontDesign = FontDesign.Monospaced,
            gradientColors = listOf(IOSColors.Cyan, colorFromHex("#B026FF")),
            shadows = listOf(
                ThemeShadow(IOSColors.Cyan, 0.dp, (-3).dp, (-3).dp),
                ThemeShadow(IOSColors.Red, 0.dp, 3.dp, 3.dp),
            ),
            animation = DigitAnimationStyle.None,
        ),
        ring = RingStyle(
            lineWidth = 8.dp,
            colors = listOf(IOSColors.Cyan),
            design = RingDesign.RadarSweep,
            glow = ThemeShadow(IOSColors.Cyan, 6.dp),
            trackColor = IOSColors.Purple.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Hexagon,
            backgroundColors = listOf(colorFromHex("#3B0A5E")),
            iconColor = IOSColors.Cyan,
            borderColor = IOSColors.Cyan,
            borderWidth = 1.5.dp,
            shadow = ThemeShadow(colorFromHex("#B026FF"), 18.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(IOSColors.Cyan),
            unselectedColor = colorFromHex("#B026FF"),
            backgroundTint = IOSColors.Purple.copy(alpha = 0.18f),
        ),
        particles = ParticleConfiguration.Scanlines,
        transition = ThemeTransitionStyle.Glitch,
        chartColors = listOf(IOSColors.Cyan, colorFromHex("#B026FF"), colorFromHex("#FF2079")),
    )

    // MARK: 5. Aurora

    private val aurora = ThemeConfiguration(
        theme = AppTheme.Aurora,
        fontDesign = FontDesign.Rounded,
        fontWeight = FontWeight.Medium,
        cornerRadius = 26.dp,
        primary = colorFromHex("#4ADE80"),
        secondary = colorFromHex("#8B5CF6"),
        backgroundTop = colorFromHex("#04121C"),
        backgroundBottom = colorFromHex("#0A0620"),
        textPrimary = Color.White,
        textSecondary = colorFromHex("#B8E8E0"),
        surface = Color.White.copy(alpha = 0.06f),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Medium,
            fontDesign = FontDesign.Rounded,
            gradientColors = listOf(
                colorFromHex("#4ADE80"),
                colorFromHex("#22D3EE"),
                colorFromHex("#8B5CF6"),
            ),
            blur = 0.5.dp,
            shadows = listOf(ThemeShadow(Color.White.copy(alpha = 0.4f), 50.dp)),
            animation = DigitAnimationStyle.Breathing(period = 4.0, min = 0.9),
        ),
        ring = RingStyle(
            lineWidth = 20.dp,
            colors = listOf(Color.White.copy(alpha = 0.55f), Color.White.copy(alpha = 0.25f)),
            design = RingDesign.TaperedArc,
            glow = ThemeShadow(Color.White.copy(alpha = 0.5f), 5.dp),
            trackColor = Color.White.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Capsule,
            backgroundColors = listOf(Color.Transparent),
            usesMaterial = true,
            iconColor = colorFromHex("#4ADE80"),
            borderColor = Color.White.copy(alpha = 0.25f),
            borderWidth = 1.dp,
            shadow = ThemeShadow(Color.White.copy(alpha = 0.25f), 20.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(colorFromHex("#4ADE80")),
            unselectedColor = Color.White.copy(alpha = 0.55f),
            backgroundTint = Color.White.copy(alpha = 0.06f),
        ),
        particles = ParticleConfiguration.AuroraCurtains,
        transition = ThemeTransitionStyle.Dissolve,
        chartColors = listOf(
            colorFromHex("#4ADE80"),
            colorFromHex("#22D3EE"),
            colorFromHex("#8B5CF6"),
        ),
    )

    // MARK: 6. Dark Matter

    private val darkMatter = ThemeConfiguration(
        theme = AppTheme.DarkMatter,
        fontDesign = FontDesign.Default,
        fontWeight = FontWeight.Normal,
        cornerRadius = 10.dp,
        primary = Color.White,
        secondary = colorFromHex("#9CA3AF"),
        backgroundTop = Color.Black,
        backgroundBottom = Color.Black,
        textPrimary = Color.White,
        textSecondary = colorFromHex("#6B7280"),
        surface = colorFromHex("#0E0E0E"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Normal,
            fontDesign = FontDesign.Default,
            gradientColors = listOf(Color.White, Color.White),
            shadows = emptyList(),
            animation = DigitAnimationStyle.None,
        ),
        ring = RingStyle(
            lineWidth = 3.dp,
            colors = listOf(IOSColors.Gray.copy(alpha = 0.5f)),
            design = RingDesign.Hairline,
            glow = null,
            trackColor = IOSColors.Gray.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Circle,
            backgroundColors = listOf(Color.Black),
            iconColor = Color.White,
            borderColor = Color.White,
            borderWidth = 1.dp,
            shadow = null,
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(Color.White),
            unselectedColor = colorFromHex("#4B5563"),
            backgroundTint = Color.Transparent,
        ),
        particles = ParticleConfiguration.Stars,
        transition = ThemeTransitionStyle.Dissolve,
        chartColors = listOf(Color.White, colorFromHex("#9CA3AF"), colorFromHex("#6B7280")),
    )

    // MARK: 7. Lava

    private val lava = ThemeConfiguration(
        theme = AppTheme.Lava,
        fontDesign = FontDesign.Default,
        fontWeight = FontWeight.Bold,
        cornerRadius = 8.dp,
        primary = colorFromHex("#DC143C"),
        secondary = colorFromHex("#FF4500"),
        backgroundTop = colorFromHex("#1F1F1F"),
        backgroundBottom = Color.Black,
        textPrimary = Color.White,
        textSecondary = colorFromHex("#A66A5E"),
        surface = colorFromHex("#171717"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Bold,
            fontDesign = FontDesign.Default,
            gradientColors = listOf(colorFromHex("#7A0A1E"), colorFromHex("#FF2D2D")),
            shadows = listOf(ThemeShadow(colorFromHex("#8B0000"), 25.dp)),
            animation = DigitAnimationStyle.Breathing(period = 1.2, min = 0.82),
        ),
        ring = RingStyle(
            lineWidth = 15.dp,
            colors = listOf(colorFromHex("#DC143C")),
            design = RingDesign.PulseRing,
            glow = ThemeShadow(colorFromHex("#DC143C"), 12.dp),
            trackColor = IOSColors.Red.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Jagged,
            backgroundColors = listOf(Color.Black, colorFromHex("#1A0000")),
            iconColor = IOSColors.Orange,
            borderColor = colorFromHex("#8B0000"),
            borderWidth = 1.5.dp,
            shadow = ThemeShadow(colorFromHex("#8B0000"), 22.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(colorFromHex("#FF2D2D")),
            unselectedColor = colorFromHex("#5C3A2E"),
            backgroundTint = IOSColors.Red.copy(alpha = 0.1f),
        ),
        particles = ParticleConfiguration.LavaCracks,
        transition = ThemeTransitionStyle.Crossfade,
        chartColors = listOf(
            colorFromHex("#DC143C"),
            colorFromHex("#FF4500"),
            colorFromHex("#8B0000"),
        ),
    )

    // MARK: 8. Neon 80s

    private val neon80s = ThemeConfiguration(
        theme = AppTheme.Neon80s,
        fontDesign = FontDesign.Default,
        fontWeight = FontWeight.Normal,
        cornerRadius = 0.dp,
        primary = colorFromHex("#FF2D95"),
        secondary = colorFromHex("#00E5FF"),
        backgroundTop = colorFromHex("#12005E"),
        backgroundBottom = Color.Black,
        textPrimary = Color.White,
        textSecondary = colorFromHex("#00E5FF"),
        surface = colorFromHex("#1A0A4A"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Normal,
            fontDesign = FontDesign.Default,
            gradientColors = listOf(colorFromHex("#FF2D95"), IOSColors.Cyan),
            shadows = listOf(ThemeShadow(IOSColors.Cyan, 35.dp)),
            animation = DigitAnimationStyle.None,
        ),
        ring = RingStyle(
            lineWidth = 6.dp,
            colors = listOf(IOSColors.Yellow),
            design = RingDesign.NeonTube,
            glow = ThemeShadow(IOSColors.Yellow, 10.dp),
            trackColor = IOSColors.Cyan.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Circle,
            backgroundColors = listOf(IOSColors.Yellow),
            iconColor = colorFromHex("#FF2D95"),
            shadow = ThemeShadow(colorFromHex("#FF2D95"), 20.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(colorFromHex("#FF2D95")),
            unselectedColor = colorFromHex("#2B3A9E"),
            backgroundTint = IOSColors.Blue.copy(alpha = 0.2f),
        ),
        particles = ParticleConfiguration.RetroGrid,
        transition = ThemeTransitionStyle.Glitch,
        chartColors = listOf(colorFromHex("#FF2D95"), IOSColors.Cyan, IOSColors.Yellow),
    )

    // MARK: 9. Galaxy

    private val galaxy = ThemeConfiguration(
        theme = AppTheme.Galaxy,
        fontDesign = FontDesign.Rounded,
        fontWeight = FontWeight.Thin,
        cornerRadius = 22.dp,
        primary = colorFromHex("#A78BFA"),
        secondary = colorFromHex("#3B4FA8"),
        backgroundTop = colorFromHex("#0B1030"),
        backgroundBottom = colorFromHex("#05061A"),
        textPrimary = Color.White,
        textSecondary = colorFromHex("#9AA6E0"),
        surface = colorFromHex("#111740"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Thin,
            fontDesign = FontDesign.Rounded,
            gradientColors = listOf(colorFromHex("#A78BFA"), colorFromHex("#1E3A8A")),
            blur = 1.dp,
            shadows = listOf(ThemeShadow(IOSColors.Purple.copy(alpha = 0.5f), 40.dp)),
            animation = DigitAnimationStyle.Breathing(period = 5.0, min = 0.88),
        ),
        ring = RingStyle(
            lineWidth = 2.dp,
            colors = listOf(colorFromHex("#A78BFA"), Color.White),
            design = RingDesign.DoubleOrbit,
            glow = ThemeShadow(IOSColors.Purple.copy(alpha = 0.6f), 8.dp),
            trackColor = Color.White.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.Circle,
            backgroundColors = listOf(Color.White.copy(alpha = 0.2f)),
            iconColor = colorFromHex("#C4B5FD"),
            borderColor = Color.White.copy(alpha = 0.2f),
            borderWidth = 1.dp,
            shadow = ThemeShadow(IOSColors.Purple.copy(alpha = 0.5f), 25.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(colorFromHex("#C4B5FD")),
            unselectedColor = colorFromHex("#4C3B87"),
            backgroundTint = IOSColors.Purple.copy(alpha = 0.12f),
        ),
        particles = ParticleConfiguration.Sparkles,
        transition = ThemeTransitionStyle.Dissolve,
        chartColors = listOf(
            colorFromHex("#A78BFA"),
            colorFromHex("#60A5FA"),
            colorFromHex("#F472B6"),
        ),
    )

    // MARK: 10. Burning Ember

    private val burningEmber = ThemeConfiguration(
        theme = AppTheme.BurningEmber,
        fontDesign = FontDesign.Default,
        fontWeight = FontWeight.Bold,
        cornerRadius = 12.dp,
        primary = colorFromHex("#E2551B"),
        secondary = colorFromHex("#6E6A66"),
        backgroundTop = colorFromHex("#171514"),
        backgroundBottom = Color.Black,
        textPrimary = colorFromHex("#E8E0DA"),
        textSecondary = colorFromHex("#8A8078"),
        surface = colorFromHex("#1C1A18"),
        digits = DigitStyle(
            fontSize = 72.sp,
            fontWeight = FontWeight.Bold,
            fontDesign = FontDesign.Default,
            gradientColors = listOf(colorFromHex("#3A3A3A"), colorFromHex("#C2762E")),
            shadows = listOf(ThemeShadow(colorFromHex("#C25A2E").copy(alpha = 0.7f), 20.dp)),
            animation = DigitAnimationStyle.FadingStutter(period = 2.4),
        ),
        ring = RingStyle(
            lineWidth = 12.dp,
            colors = listOf(colorFromHex("#3F3F3F")),
            design = RingDesign.SolidGlow,
            glow = ThemeShadow(colorFromHex("#C25A2E").copy(alpha = 0.4f), 8.dp),
            trackColor = Color.White.copy(alpha = 0.30f),
        ),
        button = ButtonStyleConfig(
            shape = ThemeButtonShapeStyle.RoundedSquare(26.dp),
            backgroundColors = listOf(colorFromHex("#2E2C2A")),
            iconColor = colorFromHex("#C2762E"),
            borderColor = colorFromHex("#3F3B38"),
            borderWidth = 1.dp,
            shadow = ThemeShadow(colorFromHex("#C25A2E").copy(alpha = 0.35f), 16.dp),
        ),
        tabs = TabStyleConfig(
            selectedColors = listOf(colorFromHex("#C2762E")),
            unselectedColor = colorFromHex("#4A4A4A"),
            backgroundTint = Color.Black.copy(alpha = 0.3f),
        ),
        particles = ParticleConfiguration.EmberBed,
        transition = ThemeTransitionStyle.Dissolve,
        chartColors = listOf(
            colorFromHex("#C2762E"),
            colorFromHex("#8A5A3A"),
            colorFromHex("#4A4A4A"),
        ),
    )
}
