package mtk.flowscope.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import mtk.flowscope.theme.DigitAnimationStyle
import mtk.flowscope.theme.RingDesign
import mtk.flowscope.theme.ThemeButtonShapeStyle
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.theme.ThemeShadow
import mtk.flowscope.theme.GradientDirection
import mtk.flowscope.theme.AppSettings
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * The themed building blocks — digits, progress ring, icon button — ported from
 * `View+Theme.swift`. All theme branching lives here so screens stay declarative.
 */

/** Drives per-frame animations without recomposing the whole tree. */
@Composable
fun rememberAnimationClock(enabled: Boolean = true): Float {
    var time by remember { mutableFloatStateOf(0f) }
    if (enabled) {
        LaunchedEffect(Unit) {
            val start = withFrameNanos { it }
            while (true) {
                withFrameNanos { now -> time = (now - start) / 1_000_000_000f }
            }
        }
    }
    return time
}

// MARK: - Themed shapes

/** Hexagon used by the Cyberpunk theme. */
val HexagonShape = object : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density) =
        Outline.Generic(
            Path().apply {
                val cx = size.width / 2
                val cy = size.height / 2
                val r = min(size.width, size.height) / 2
                for (i in 0 until 6) {
                    val angle = i * (PI / 3) - PI / 2
                    val x = cx + r * cos(angle).toFloat()
                    val y = cy + r * sin(angle).toFloat()
                    if (i == 0) moveTo(x, y) else lineTo(x, y)
                }
                close()
            },
        )
}

/** Irregular cracked-rock silhouette used by the Lava theme. */
val JaggedShape = object : Shape {
    // Fixed peaks/valleys so the silhouette is stable, not jittering.
    private val radii = floatArrayOf(
        1.0f, 0.78f, 0.95f, 0.72f, 1.0f, 0.8f, 0.92f, 0.75f, 1.0f, 0.83f, 0.9f, 0.76f,
    )

    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density) =
        Outline.Generic(
            Path().apply {
                val cx = size.width / 2
                val cy = size.height / 2
                val r = min(size.width, size.height) / 2
                radii.forEachIndexed { i, factor ->
                    val angle = i.toDouble() / radii.size * 2 * PI - PI / 2
                    val rr = r * factor
                    val x = cx + rr * cos(angle).toFloat()
                    val y = cy + rr * sin(angle).toFloat()
                    if (i == 0) moveTo(x, y) else lineTo(x, y)
                }
                close()
            },
        )
}

/** Resolves a [ThemeButtonShapeStyle] into a concrete Compose shape. */
fun themeButtonShape(style: ThemeButtonShapeStyle): Shape = when (style) {
    ThemeButtonShapeStyle.Circle -> CircleShape
    ThemeButtonShapeStyle.Capsule -> RoundedCornerShape(percent = 50)
    ThemeButtonShapeStyle.SharpSquare -> RoundedCornerShape(0.dp)
    is ThemeButtonShapeStyle.RoundedSquare -> RoundedCornerShape(style.radius)
    ThemeButtonShapeStyle.Hexagon -> HexagonShape
    ThemeButtonShapeStyle.Jagged -> JaggedShape
}

// MARK: - Themed surface

/** Themed card surface — background, corner radius and hairline border. */
fun Modifier.themedSurface(config: ThemeConfiguration): Modifier = this
    .clip(RoundedCornerShape(config.cornerRadius))
    .background(config.surface)
    .border(1.dp, config.primary.copy(alpha = 0.25f), RoundedCornerShape(config.cornerRadius))

// MARK: - Themed digits

/**
 * The big timer readout: gradient fill, stacked shadows, per-theme animation.
 *
 * Compose's TextStyle carries only one shadow, so the stacked glows (including
 * Cyberpunk's chromatic aberration) are drawn as offset copies behind the text.
 */
@Composable
fun ThemedDigits(
    text: String,
    config: ThemeConfiguration,
    settings: AppSettings,
    modifier: Modifier = Modifier,
) {
    val animate = settings.animatedDigits &&
        config.digits.animation != DigitAnimationStyle.None
    val t = rememberAnimationClock(enabled = animate).toDouble()

    val opacity = digitOpacity(config, settings, t)
    val shadows = digitShadows(config, settings, t)

    val gradient = when (config.digits.gradientDirection) {
        GradientDirection.LeadingToTrailing -> Brush.horizontalGradient(config.digits.gradientColors)
        GradientDirection.TopLeadingToBottomTrailing ->
            Brush.linearGradient(config.digits.gradientColors)
    }

    val baseStyle = TextStyle(
        fontSize = config.digits.fontSize,
        fontWeight = config.digits.fontWeight,
        fontFamily = config.digits.fontDesign.fontFamily,
        textAlign = TextAlign.Center,
    )

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        // Glow / aberration layers.
        shadows.forEach { shadow ->
            Text(
                text = text,
                style = baseStyle.copy(color = shadow.color.copy(alpha = shadow.color.alpha * opacity.toFloat())),
                modifier = Modifier
                    .offset(shadow.x, shadow.y)
                    .then(
                        // Unbounded, or the blur clips to the text's own box and
                        // the glow reads as a hard-edged rectangle behind it.
                        if (shadow.radius > 0.dp) {
                            Modifier.blur(shadow.radius, BlurredEdgeTreatment.Unbounded)
                        } else {
                            Modifier
                        },
                    ),
            )
        }
        // Main gradient text.
        Text(
            text = text,
            style = baseStyle.copy(brush = gradient, alpha = opacity.toFloat()),
            modifier = if (config.digits.blur > 0.dp) {
                Modifier.blur(config.digits.blur, BlurredEdgeTreatment.Unbounded)
            } else {
                Modifier
            },
        )
    }
}

private fun digitOpacity(
    config: ThemeConfiguration,
    settings: AppSettings,
    t: Double,
): Double {
    if (!settings.animatedDigits) return 1.0
    return when (val a = config.digits.animation) {
        DigitAnimationStyle.None,
        is DigitAnimationStyle.Flicker,
        is DigitAnimationStyle.GradientWave,
        -> 1.0

        is DigitAnimationStyle.Breathing -> {
            val wave = (sin(t * (2 * PI / a.period)) + 1) / 2
            a.min + (1 - a.min) * wave
        }

        is DigitAnimationStyle.FadingStutter -> {
            // Slow fade with an abrupt "stutter" restart.
            val phase = (t % a.period) / a.period
            if (phase < 0.15) 0.55 else 0.72 + 0.28 * (1 - phase)
        }
    }
}

private fun digitShadows(
    config: ThemeConfiguration,
    settings: AppSettings,
    t: Double,
): List<ThemeShadow> {
    if (!settings.glowEnabled) return emptyList()
    if (!settings.animatedDigits) return config.digits.shadows
    return when (val a = config.digits.animation) {
        is DigitAnimationStyle.Flicker -> {
            // Deterministic pseudo-random radius that changes ~10x/sec.
            val tick = floor(t * 10)
            val noise = abs(sin(tick * 12.9898) * 43758.5453) % 1.0
            val radius = a.min + (a.max - a.min) * noise.toFloat()
            config.digits.shadows.map { it.copy(radius = radius) }
        }

        else -> config.digits.shadows
    }
}

// MARK: - Themed progress ring

/**
 * Ring renderer. Each theme gets a distinct shape language — no dashed or
 * dotted strokes, which read as cheap at this diameter.
 *
 * Compose can't attach a shadow to a drawn arc, so the glow is built the same
 * way the particle field builds its bloom: wider, dimmer passes underneath.
 */
@Composable
fun ThemedProgressRing(
    progress: Float,
    config: ThemeConfiguration,
    modifier: Modifier = Modifier,
    diameter: androidx.compose.ui.unit.Dp = 280.dp,
    animated: Boolean = true,
) {
    val t = rememberAnimationClock(enabled = animated).toDouble()

    Canvas(modifier = modifier.size(diameter)) {
        val lineWidth = config.ring.lineWidth.toPx()
        val inset = lineWidth / 2
        val arcSize = Size(size.width - lineWidth, size.height - lineWidth)
        val topLeft = Offset(inset, inset)

        // Track
        drawArc(
            color = config.ring.trackColor,
            startAngle = 0f,
            sweepAngle = 360f,
            useCenter = false,
            topLeft = topLeft,
            size = arcSize,
            style = Stroke(width = lineWidth, cap = StrokeCap.Round),
        )

        val ringCtx = RingContext(this, config, progress.coerceIn(0f, 1f), lineWidth, topLeft, arcSize)
        when (config.ring.design) {
            RingDesign.SolidGlow -> ringCtx.solidGlow()
            RingDesign.NeonTube -> ringCtx.neonTube()
            RingDesign.CometTrail -> ringCtx.cometTrail()
            RingDesign.DoubleOrbit -> ringCtx.doubleOrbit(t)
            RingDesign.SegmentedArc -> ringCtx.segmentedArc()
            RingDesign.TaperedArc -> ringCtx.taperedArc()
            RingDesign.Hairline -> ringCtx.hairline()
            RingDesign.PulseRing -> ringCtx.pulseRing(t)
            RingDesign.RadarSweep -> ringCtx.radarSweep(t)
        }
    }
}

private class RingContext(
    val scope: DrawScope,
    val config: ThemeConfiguration,
    val progress: Float,
    val lineWidth: Float,
    val topLeft: Offset,
    val arcSize: Size,
) {
    val center get() = scope.center
    val radius get() = arcSize.width / 2

    val brush: Brush
        get() = when {
            config.ring.usesAngularGradient ->
                Brush.sweepGradient(config.ring.colors + config.ring.colors.first(), center)

            config.ring.colors.size > 1 -> Brush.sweepGradient(config.ring.colors, center)
            else -> {
                val c = config.ring.colors.firstOrNull() ?: config.primary
                Brush.linearGradient(listOf(c, c))
            }
        }

    /**
     * Draws the progress arc. The canvas is rotated rather than the start angle
     * offset, so sweep gradients rotate with the arc the way SwiftUI's
     * `rotationEffect` moved the AngularGradient with the view.
     */
    fun arc(
        trim: Float,
        width: Float,
        brush: Brush,
        alpha: Float = 1f,
        rotationDegrees: Float = 0f,
        startFraction: Float = 0f,
    ) {
        val sweep = (trim.coerceIn(0.0001f, 1f)) * 360f
        scope.rotate(-90f + rotationDegrees, center) {
            drawArc(
                brush = brush,
                startAngle = startFraction * 360f,
                sweepAngle = sweep,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = width, cap = StrokeCap.Round),
                alpha = alpha,
            )
        }
    }

    /** A dot orbiting the ring at [fraction] of a turn. */
    fun orbitDot(fraction: Float, dotRadius: Float, color: Color, glowColor: Color? = null) {
        val angle = (fraction * 360f - 90f) * PI / 180
        val point = Offset(
            center.x + radius * cos(angle).toFloat(),
            center.y + radius * sin(angle).toFloat(),
        )
        glowColor?.let {
            scope.drawCircle(it.copy(alpha = 0.55f), dotRadius * 2.6f, point)
            scope.drawCircle(it.copy(alpha = 0.35f), dotRadius * 1.7f, point)
        }
        scope.drawCircle(color, dotRadius, point)
    }

    /** Wide dim pass under the arc, standing in for SwiftUI's shadow. */
    fun glowPass(trim: Float, widthScale: Float = 2.4f, alpha: Float = 0.28f) {
        val glow = config.ring.glow ?: return
        arc(trim, lineWidth * widthScale, Brush.linearGradient(listOf(glow.color, glow.color)), alpha)
    }

    // MARK: Designs

    fun solidGlow() {
        glowPass(progress, 2.6f, 0.30f)
        arc(progress, lineWidth * 1.6f, brush, 0.35f)
        arc(progress, lineWidth, brush)
    }

    /** Thick outer tube with a bright thin inner highlight — real neon. */
    fun neonTube() {
        arc(progress, lineWidth * 2.2f, brush, 0.28f)
        arc(progress, lineWidth, brush)
        arc(
            progress,
            max(1f, lineWidth * 0.3f),
            Brush.linearGradient(listOf(Color.White, Color.White)),
            0.9f,
        )
    }

    /** Arc that fades toward its tail with a bright head — reads as speed. */
    fun cometTrail() {
        val head = progress
        val tail = max(0f, head - 0.42f)
        val span = head - tail
        if (span > 0.0001f) {
            scope.rotate(-90f, center) {
                drawArc(
                    brush = Brush.sweepGradient(
                        colorStops = arrayOf(
                            0f to config.primary.copy(alpha = 0f),
                            (span * 0.7f).coerceIn(0.001f, 0.999f) to config.primary.copy(alpha = 0.55f),
                            span.coerceIn(0.002f, 1f) to Color.White,
                            1f to config.primary.copy(alpha = 0f),
                        ),
                        center = center,
                    ),
                    startAngle = tail * 360f,
                    sweepAngle = span * 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = lineWidth, cap = StrokeCap.Round),
                )
            }
        }
        orbitDot(head, lineWidth * 0.75f, Color.White, config.primary)
    }

    /** Two concentric arcs turning opposite ways. */
    fun doubleOrbit(t: Double) {
        arc(progress, lineWidth * 1.6f, brush, rotationDegrees = (t * 12).toFloat())
        val inner = config.secondary.copy(alpha = 0.8f)
        scope.rotate(-90f - (t * 20).toFloat(), center) {
            scope.scale(0.86f, center) {
                drawArc(
                    brush = Brush.linearGradient(listOf(inner, inner)),
                    startAngle = 0f,
                    sweepAngle = (progress * 0.7f).coerceIn(0.0001f, 1f) * 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = lineWidth, cap = StrokeCap.Round),
                )
            }
        }
    }

    /** Chunky gauge segments — precise and technical, never dotty. */
    fun segmentedArc() {
        val segments = 36
        val filled = (progress * segments).toInt()
        for (i in 0 until segments) {
            val on = i < filled
            val angle = (i.toDouble() / segments) * 2 * PI - PI / 2
            val point = Offset(
                center.x + radius * cos(angle).toFloat(),
                center.y + radius * sin(angle).toFloat(),
            )
            val h = if (on) scope.run { 16.dp.toPx() } else scope.run { 10.dp.toPx() }
            val w = lineWidth * 1.6f
            scope.rotate((i.toFloat() / segments) * 360f, point) {
                if (on) {
                    // Bloom under the lit segments.
                    drawRoundRect(
                        color = config.primary.copy(alpha = 0.5f),
                        topLeft = Offset(point.x - w, point.y - h),
                        size = Size(w * 2, h * 2),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(w),
                    )
                }
                drawRoundRect(
                    brush = if (on) {
                        Brush.linearGradient(config.accentColors)
                    } else {
                        Brush.linearGradient(
                            listOf(
                                config.primary.copy(alpha = 0.12f),
                                config.primary.copy(alpha = 0.12f),
                            ),
                        )
                    },
                    topLeft = Offset(point.x - w / 2, point.y - h / 2),
                    size = Size(w, h),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(w / 2),
                )
            }
        }
    }

    /** Sweep that grows from hairline to full width. */
    fun taperedArc() {
        val steps = 28
        val color = config.ring.colors.firstOrNull() ?: config.primary
        for (i in 0 until steps) {
            val f = i.toFloat() / steps
            val seg = progress / steps
            val start = f * progress
            val end = min(f * progress + seg * 1.4f, 1f)
            if (end <= start) continue
            scope.rotate(-90f, center) {
                drawArc(
                    color = color,
                    startAngle = start * 360f,
                    sweepAngle = (end - start) * 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(
                        width = lineWidth * (0.25f + 0.75f * f),
                        cap = StrokeCap.Round,
                    ),
                    alpha = 0.35f + 0.65f * f,
                )
            }
        }
    }

    fun hairline() {
        arc(progress, lineWidth, brush)
        orbitDot(progress, lineWidth * 1.2f, config.primary)
    }

    fun pulseRing(t: Double) {
        // The bloom breathes: a wider, dimmer pass whose width and opacity
        // rise and fall, standing in for SwiftUI's scaling blurred shadow.
        val wave = ((sin(t * (2 * PI / 2)) + 1) / 2).toFloat()
        arc(progress, lineWidth * (2.2f + 0.4f * wave), brush, 0.35f + 0.4f * wave)
        arc(progress, lineWidth, brush)
    }

    fun radarSweep(t: Double) {
        arc(progress, lineWidth, brush)
        val angle = ((t / 4) % 1.0).toFloat()
        scope.rotate(-90f + angle * 360f, center) {
            drawArc(
                brush = Brush.sweepGradient(
                    colorStops = arrayOf(
                        0f to config.primary.copy(alpha = 0f),
                        0.12f to Color.White,
                        0.13f to config.primary.copy(alpha = 0f),
                        1f to config.primary.copy(alpha = 0f),
                    ),
                    center = center,
                ),
                startAngle = 0f,
                sweepAngle = 43f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = lineWidth, cap = StrokeCap.Round),
            )
        }
        orbitDot(angle + 43f / 360f, lineWidth * 0.6f, Color.White, config.primary)
    }
}

// MARK: - Themed icon button

/** The play / pause / stop control, styled entirely from the configuration. */
@Composable
fun ThemedIconButton(
    icon: ImageVector,
    contentDescription: String,
    config: ThemeConfiguration,
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = 76.dp,
    onClick: () -> Unit,
) {
    val t = rememberAnimationClock(enabled = config.button.pulse).toDouble()
    val pulseScale = if (config.button.pulse) {
        (1 + 0.05 * ((sin(t * (2 * PI / 3)) + 1) / 2)).toFloat()
    } else {
        1f
    }

    val shape = themeButtonShape(config.button.shape)
    val background = if (config.button.usesMaterial) {
        // Compose has no UIKit material; a translucent white scrim reads the
        // same way against these dark palettes.
        Brush.linearGradient(
            listOf(Color.White.copy(alpha = 0.14f), Color.White.copy(alpha = 0.06f)),
        )
    } else {
        val colors = config.button.backgroundColors
        Brush.linearGradient(if (colors.size > 1) colors else listOf(colors.first(), colors.first()))
    }

    Box(
        modifier = modifier
            .size(size)
            .scale(pulseScale)
            .then(
                // Glow, drawn as a soft halo behind the shape.
                config.button.shadow?.let { shadow ->
                    Modifier.drawGlow(shadow, shape)
                } ?: Modifier,
            )
            .clip(shape)
            .background(background)
            .then(
                if (config.button.borderColor != null && config.button.borderWidth > 0.dp) {
                    Modifier.border(config.button.borderWidth, config.button.borderColor!!, shape)
                } else {
                    Modifier
                },
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = config.button.iconColor,
            modifier = Modifier.size(size * 0.38f),
        )
    }
}

/** Approximates SwiftUI's coloured drop shadow with concentric soft passes. */
private fun Modifier.drawGlow(shadow: ThemeShadow, shape: Shape): Modifier =
    this.drawBehind {
        val outline = shape.createOutline(size, layoutDirection, this)
        val spread = shadow.radius.toPx() / size.minDimension
        val passes = 3
        for (i in passes downTo 1) {
            val f = i.toFloat() / passes
            val alpha = shadow.color.alpha * 0.18f * (1 - f + 0.3f)
            val tint = shadow.color.copy(alpha = alpha.coerceIn(0f, 1f))
            scale(1f + f * spread) {
                when (outline) {
                    is Outline.Generic -> drawPath(outline.path, tint)
                    is Outline.Rounded ->
                        drawPath(Path().apply { addRoundRect(outline.roundRect) }, tint)

                    is Outline.Rectangle -> drawRect(tint)
                }
            }
        }
    }
