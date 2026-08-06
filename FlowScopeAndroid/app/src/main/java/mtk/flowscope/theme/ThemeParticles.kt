package mtk.flowscope.theme

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * High-fidelity Canvas effect renderer, ported from `ThemeParticles.swift`.
 *
 * The cinematic look comes from three techniques, no external libraries:
 *  1. Additive blending ([BlendMode.Plus]) so overlapping light accumulates and
 *     blows out to white — the way real HDR bloom behaves.
 *  2. Multi-pass strokes: a wide dim halo, a mid glow, then a thin white hot
 *     core. That layering is what reads as *emitted light* rather than a drawn
 *     line.
 *  3. Gradient shading instead of flat fills, so every particle has falloff
 *     rather than a hard edge.
 */

// MARK: - Deterministic RNG

private class SeededGenerator(seed: Int) {
    private var state: Long = (seed.toLong() or 1L)

    fun next(): Long {
        state = state xor (state shl 13)
        state = state xor (state ushr 7)
        state = state xor (state shl 17)
        return state
    }

    /** Uniform float in [from, until). */
    fun nextFloat(from: Float, until: Float): Float {
        val v = (next() ushr 11).toDouble() / (1L shl 53).toDouble()
        return (from + (until - from) * v).toFloat()
    }

    fun nextDouble(from: Double, until: Double): Double {
        val v = (next() ushr 11).toDouble() / (1L shl 53).toDouble()
        return from + (until - from) * v
    }
}

private data class Particle(
    val x: Float,
    val y: Float,
    val size: Float,
    val speed: Double,
    val phase: Double,
)

/** Stable pseudo-random value in 0..<1 from any pair of numbers. */
private fun noise(a: Double, b: Double = 0.0): Double =
    abs(sin(a * 12.9898 + b * 78.233) * 43758.5453) % 1.0

private fun buildParticles(seed: Int): List<Particle> {
    val rng = SeededGenerator(seed)
    return (0 until 90).map {
        Particle(
            x = rng.nextFloat(0f, 1f),
            y = rng.nextFloat(0f, 1f),
            size = rng.nextFloat(2f, 7f),
            speed = rng.nextDouble(0.4, 1.6),
            phase = rng.nextDouble(0.0, 2 * PI),
        )
    }
}

private fun ParticleConfiguration.seedKey(): Int = when (this) {
    is ParticleConfiguration.Embers -> 1 + (if (rising) 10 else 0) + (if (fade) 100 else 0)
    ParticleConfiguration.LightningBolts -> 2
    ParticleConfiguration.NeonGrid -> 3
    ParticleConfiguration.Scanlines -> 4
    ParticleConfiguration.GlassOrbs -> 5
    ParticleConfiguration.AuroraCurtains -> 6
    ParticleConfiguration.EmberBed -> 7
    ParticleConfiguration.Stars -> 8
    ParticleConfiguration.LavaCracks -> 9
    ParticleConfiguration.RetroGrid -> 10
    ParticleConfiguration.Sparkles -> 11
}

// MARK: - Composable

@Composable
fun ThemeParticles(
    configuration: ParticleConfiguration,
    primary: Color,
    secondary: Color,
    modifier: Modifier = Modifier,
    depth: Double = 1.0,
    intensity: Double = 1.0,
    speed: Double = 1.0,
    reduceMotion: Boolean = false,
) {
    val particles = remember(configuration, depth) {
        buildParticles(configuration.seedKey() * 977 + (depth * 977).toInt())
    }

    var time by remember { mutableFloatStateOf(0f) }

    if (!reduceMotion) {
        LaunchedEffect(configuration) {
            val start = withFrameNanos { it }
            while (true) {
                withFrameNanos { now ->
                    time = (now - start) / 1_000_000_000f
                }
            }
        }
    }

    Canvas(modifier = modifier.fillMaxSize()) {
        if (intensity <= 0.01) return@Canvas
        val t = time.toDouble() * (0.45 + 0.55 * depth) * speed
        val ctx = ParticleContext(this, primary, secondary, depth, intensity, particles)

        when (configuration) {
            is ParticleConfiguration.Embers ->
                ctx.drawEmbers(t, configuration.rising, configuration.fade)

            ParticleConfiguration.LightningBolts -> ctx.drawLightning(t)
            ParticleConfiguration.NeonGrid -> ctx.drawNeonGrid(t)
            ParticleConfiguration.Scanlines -> ctx.drawScanlines(t)
            ParticleConfiguration.GlassOrbs -> ctx.drawOrbs(t)
            ParticleConfiguration.AuroraCurtains -> ctx.drawAuroraCurtains(t)
            ParticleConfiguration.EmberBed -> ctx.drawEmberBed(t)
            ParticleConfiguration.Stars -> ctx.drawStars(t)
            ParticleConfiguration.LavaCracks -> ctx.drawLava(t)
            ParticleConfiguration.RetroGrid -> ctx.drawRetroGrid(t)
            ParticleConfiguration.Sparkles -> ctx.drawSparkles(t)
        }
    }
}

// MARK: - Draw context

/**
 * Holds everything the draw routines need. The Swift original used points;
 * [pt] converts those to pixels so the effects keep their intended scale on
 * any density.
 */
private class ParticleContext(
    val scope: DrawScope,
    val primary: Color,
    val secondary: Color,
    val depth: Double,
    val intensity: Double,
    val particles: List<Particle>,
) {
    val size: Size get() = scope.size
    val w: Float get() = scope.size.width
    val h: Float get() = scope.size.height

    /** Swift points → device pixels. */
    fun pt(v: Float): Float = v * scope.density

    fun count(base: Int): Int =
        max(1, (base * min(2.0, max(0.2, intensity)) * (0.6 + 0.4 * depth)).toInt())

    val alphaScale: Double get() = intensity * (0.4 + 0.6 * depth)

    fun take(n: Int): List<Particle> = particles.take(min(n, particles.size))

    // MARK: Draw helpers

    /** Wide halo → mid glow → bright body → thin white core. */
    fun bloomStroke(
        path: Path,
        color: Color,
        width: Float,
        alpha: Double,
        core: Boolean = true,
    ) {
        if (alpha <= 0.004) return
        fun stroke(w: Float) = Stroke(width = w, cap = StrokeCap.Round, join = StrokeJoin.Round)

        scope.drawPath(path, color.copy(alpha = (alpha * 0.13).toFloat().coerceIn(0f, 1f)),
            style = stroke(width * 5.5f), blendMode = BlendMode.Plus)
        scope.drawPath(path, color.copy(alpha = (alpha * 0.26).toFloat().coerceIn(0f, 1f)),
            style = stroke(width * 2.7f), blendMode = BlendMode.Plus)
        scope.drawPath(path, color.copy(alpha = (alpha * 0.72).toFloat().coerceIn(0f, 1f)),
            style = stroke(width), blendMode = BlendMode.Plus)
        if (core) {
            scope.drawPath(path, Color.White.copy(alpha = (alpha * 0.9).toFloat().coerceIn(0f, 1f)),
                style = stroke(max(pt(0.6f), width * 0.34f)), blendMode = BlendMode.Plus)
        }
    }

    /** Soft radial particle with falloff — no hard circle edges. */
    fun bloomDot(
        center: Offset,
        radius: Float,
        color: Color,
        alpha: Double,
        hotCore: Boolean = true,
    ) {
        if (alpha <= 0.004 || radius <= pt(0.5f)) return
        val a = alpha.toFloat().coerceIn(0f, 1f)

        scope.drawCircle(
            brush = Brush.radialGradient(
                colorStops = arrayOf(
                    0f to color.copy(alpha = a),
                    0.35f to color.copy(alpha = (a * 0.42f).coerceIn(0f, 1f)),
                    1f to color.copy(alpha = 0f),
                ),
                center = center,
                radius = radius,
            ),
            radius = radius,
            center = center,
            blendMode = BlendMode.Plus,
        )
        if (hotCore) {
            scope.drawCircle(
                color = Color.White.copy(alpha = (a * 0.85f).coerceIn(0f, 1f)),
                radius = radius * 0.2f,
                center = center,
                blendMode = BlendMode.Plus,
            )
        }
    }

    /** Full-screen additive flash — lightning strikes, cycle pulses. */
    fun flash(color: Color, alpha: Double) {
        if (alpha <= 0.002) return
        scope.drawRect(
            color = color.copy(alpha = alpha.toFloat().coerceIn(0f, 1f)),
            blendMode = BlendMode.Plus,
        )
    }

    fun vignette(strength: Double) {
        scope.drawRect(
            brush = Brush.radialGradient(
                colors = listOf(Color.Transparent, Color.Black.copy(alpha = strength.toFloat())),
                center = Offset(w / 2, h / 2),
                radius = max(w, h) * 0.75f,
            ),
        )
    }
}

// MARK: - Flame / Burning Ember

private fun ParticleContext.drawEmbers(t: Double, rising: Boolean, fade: Boolean) {
    for (p in take(count(16))) {
        val travel = (t * 0.055 * p.speed + p.phase) % 1.0
        val progress = travel.toFloat()
        val y = if (rising) h * (1 - progress) else h * progress
        // Turbulent sway that widens as the ember rises through hot air.
        val sway = (sin(t * 1.1 + p.phase) + 0.4 * sin(t * 2.7 + p.phase)).toFloat() *
            pt(8f + 16f * progress)
        val x = p.x * w + sway

        val life = if (fade) (1 - progress).toDouble() else 1.0
        val flicker = 0.65 + 0.35 * noise(floor(t * 12), p.phase)
        val alpha = life * flicker * 0.95 * alphaScale
        val radius = pt(p.size * (2.2f - 0.9f * progress) * 2.6f)
        val color = if (p.phase > 3) secondary else primary

        bloomDot(Offset(x, y), radius, color, alpha)

        // Motion-blur tail on the faster embers.
        if (p.speed > 1.0) {
            val tail = Path().apply {
                moveTo(x, y)
                lineTo(x - sway * 0.15f, y + if (rising) pt(18f) else pt(-18f))
            }
            bloomStroke(tail, color, pt(1.4f), alpha * 0.45, core = false)
        }
    }
}

// MARK: - Lightning — branching, tapered, with strike flash

/**
 * Recursively builds a forked bolt. Real lightning branches; a single zig-zag
 * polyline is exactly what makes bolts look like sticks.
 */
private fun ParticleContext.boltPath(
    start: Offset,
    angle: Double,
    length: Float,
    seed: Double,
    depthLeft: Int,
    into: MutableList<Pair<Path, Float>>,
) {
    if (depthLeft <= 0 || length <= pt(8f)) return

    val path = Path().apply { moveTo(start.x, start.y) }

    var point = start
    var heading = angle
    val segments = 5
    val segLength = length / segments

    // Clamp toward straight-down. Without this the accumulated jitter can
    // rotate a bolt past horizontal, so strikes drift sideways instead of
    // falling from the sky.
    val downward = PI / 2
    for (i in 0 until segments) {
        heading += (noise(seed + i * 3.1, depthLeft.toDouble()) - 0.5) * 0.8
        heading = min(max(heading, downward - 0.55), downward + 0.55)
        point = Offset(
            point.x + cos(heading).toFloat() * segLength,
            point.y + sin(heading).toFloat() * segLength,
        )
        path.lineTo(point.x, point.y)

        // Fork off a thinner, shorter tributary.
        if (depthLeft > 1 && noise(seed + i * 7.7, 2.0) > 0.7) {
            boltPath(
                start = point,
                angle = heading + (noise(seed + i, 5.0) - 0.5) * 1.1,
                length = length * 0.45f,
                seed = seed + i * 13.3,
                depthLeft = depthLeft - 1,
                into = into,
            )
        }
    }
    // Trunk thick, branches thin.
    into += path to pt(depthLeft * 2.1f)
}

private fun ParticleContext.drawLightning(t: Double) {
    var totalFlash = 0.0

    for (p in take(count(4))) {
        val period = 1.6 + p.speed
        val cycle = (t * 0.9 + p.phase) % period
        val window = 0.42
        if (cycle >= window) continue

        // Multi-flicker envelope: strike, dip, re-strike, decay.
        val u = cycle / window
        val envelope = (1 - u) * (0.55 + 0.45 * abs(sin(u * 18)))
        val alpha = envelope * alphaScale

        // Re-seed per strike so every bolt is a different shape.
        val strikeIndex = floor((t * 0.9 + p.phase) / period)
        val seed = p.phase * 31 + strikeIndex * 7.13

        val paths = mutableListOf<Pair<Path, Float>>()
        boltPath(
            start = Offset(p.x * w, pt(-20f)),
            angle = PI / 2 + (noise(seed) - 0.5) * 0.5,
            length = h * 0.85f,
            seed = seed,
            depthLeft = 3,
            into = paths,
        )

        for ((path, width) in paths) bloomStroke(path, primary, width, alpha)
        totalFlash += envelope * 0.10
    }

    flash(primary, min(0.22, totalFlash) * alphaScale)
}

// MARK: - Laser — glowing neon grid

private fun ParticleContext.drawNeonGrid(t: Double) {
    val pulse = 0.62 + 0.3 * sin(t * 1.6)
    val cols = 8
    val rows = 8

    for (i in 0..cols) {
        val x = w * i / cols
        val a = pulse * (0.55 + 0.45 * sin(t * 2 + i)) * alphaScale
        val path = Path().apply { moveTo(x, 0f); lineTo(x, h) }
        bloomStroke(path, primary, pt(1.1f), a, core = false)
    }
    for (j in 0..rows) {
        val y = h * j / rows
        val a = pulse * (0.55 + 0.45 * sin(t * 2 + j * 1.3)) * alphaScale
        val path = Path().apply { moveTo(0f, y); lineTo(w, y) }
        bloomStroke(path, secondary, pt(1.1f), a, core = false)
    }

    // Bright nodes where beams cross.
    for (i in 0..cols) {
        for (j in 0..rows) {
            if ((i + j) % 2 != 0) continue
            val point = Offset(w * i / cols, h * j / rows)
            val a = pulse * (0.4 + 0.6 * noise(i * 3.0 + j, floor(t * 2))) * alphaScale
            bloomDot(point, pt(7f), primary, a * 0.7, hotCore = false)
        }
    }
    vignette(0.35)
}

// MARK: - Cyberpunk — CRT scanlines, sweep band, RGB split

private fun ParticleContext.drawScanlines(t: Double) {
    val spacing = pt(4f)
    val offset = ((t * 22) % spacing.toDouble()).toFloat()
    var y = -spacing + offset
    while (y < h) {
        scope.drawLine(
            color = Color.White.copy(alpha = (0.11 * alphaScale).toFloat().coerceIn(0f, 1f)),
            start = Offset(0f, y),
            end = Offset(w, y),
            strokeWidth = pt(1f),
        )
        y += spacing
    }

    // CRT refresh band sweeping down the screen, with a soft-edged falloff so it
    // reads as a refresh sweep rather than a hard rectangle.
    val bandY = ((t * 0.22) % 1.0).toFloat() * h
    val bandSpread = pt(170f)
    scope.drawRect(
        brush = Brush.verticalGradient(
            colorStops = arrayOf(
                0f to Color.Transparent,
                0.35f to primary.copy(alpha = (0.05 * alphaScale).toFloat().coerceIn(0f, 1f)),
                0.5f to primary.copy(alpha = (0.14 * alphaScale).toFloat().coerceIn(0f, 1f)),
                0.65f to primary.copy(alpha = (0.05 * alphaScale).toFloat().coerceIn(0f, 1f)),
                1f to Color.Transparent,
            ),
            startY = bandY - bandSpread,
            endY = bandY + bandSpread,
        ),
        topLeft = Offset(0f, bandY - bandSpread),
        size = Size(w, bandSpread * 2),
        blendMode = BlendMode.Plus,
    )

    // RGB-split glitch bars.
    for (p in take(count(8))) {
        val cycle = (t * 1.7 + p.phase) % 1.4
        if (cycle >= 0.16) continue
        val gy = p.y * h
        val shift = pt((6 + 10 * noise(p.phase, floor(t * 8))).toFloat())
        scope.drawRect(
            color = primary.copy(alpha = (0.6 * alphaScale).toFloat().coerceIn(0f, 1f)),
            topLeft = Offset(-shift, gy), size = Size(w, pt(5f)), blendMode = BlendMode.Plus,
        )
        scope.drawRect(
            color = secondary.copy(alpha = (0.5 * alphaScale).toFloat().coerceIn(0f, 1f)),
            topLeft = Offset(shift, gy + pt(3f)), size = Size(w, pt(3f)), blendMode = BlendMode.Plus,
        )
        scope.drawRect(
            color = Color.White.copy(alpha = (0.35 * alphaScale).toFloat().coerceIn(0f, 1f)),
            topLeft = Offset(0f, gy + pt(1f)), size = Size(w, pt(2f)), blendMode = BlendMode.Plus,
        )
    }
    vignette(0.45)
}

// MARK: - Glass orbs

private fun ParticleContext.drawOrbs(t: Double) {
    for (i in 0 until 3) {
        val phase = t * 0.12 + i * 1.9
        val path = Path()
        path.moveTo(0f, h * 0.32f + pt(i * 60f))
        var x = 0f
        while (x <= w) {
            val y = h * (0.32f + 0.12f * sin(x / pt(110f) + phase).toFloat()) + pt(i * 60f)
            path.lineTo(x, y)
            x += pt(18f)
        }
        bloomStroke(
            path,
            if (i % 2 == 0) primary else secondary,
            pt(26f),
            0.10 * alphaScale,
            core = false,
        )
    }

    take(count(7)).forEachIndexed { i, p ->
        val angle = t * 0.11 * p.speed + p.phase
        val c = Offset(
            p.x * w + cos(angle).toFloat() * pt(70f),
            p.y * h + sin(angle * 0.8).toFloat() * pt(70f),
        )
        bloomDot(
            c,
            pt(90f + p.size * 16f),
            if (i % 2 == 0) primary else secondary,
            0.30 * alphaScale,
            hotCore = false,
        )
    }
}

// MARK: - Aurora — borealis curtains over a star field

/**
 * Real aurora reads as vertical ribbons of light hanging from the sky, not
 * blurred blobs. Each ribbon is a filled band whose edges wave independently,
 * shaded green→cyan→violet and faded at the bottom so it dissolves into night.
 */
private fun ParticleContext.drawAuroraCurtains(t: Double) {
    // Night sky behind the curtains.
    for (p in take(count(30))) {
        val twinkle = 0.25 + 0.5 * abs(sin(t * 0.7 * p.speed + p.phase))
        bloomDot(
            Offset(p.x * w, p.y * h * 0.75f),
            pt(p.size * 0.7f),
            Color.White,
            twinkle * 0.5 * alphaScale,
            hotCore = false,
        )
    }

    val ribbons = max(3, count(5))
    for (i in 0 until ribbons) {
        val phase = i * 1.7 + t * 0.22
        val baseX = w * (i + 0.5f) / ribbons
        val width = w * 0.22f
        val topY = h * 0.02f
        val bottomY = h * (0.55f + 0.18f * sin(phase * 0.6).toFloat())

        // A closed band with independently waving left/right edges.
        val band = Path()
        val steps = 16
        band.moveTo(baseX, topY)
        for (s in 0..steps) {
            val f = s.toFloat() / steps
            val y = topY + (bottomY - topY) * f
            val wobble = sin(f * 3.4 + phase).toFloat() * pt(26f) * f
            band.lineTo(baseX + wobble + width * 0.5f * f, y)
        }
        for (s in steps downTo 0) {
            val f = s.toFloat() / steps
            val y = topY + (bottomY - topY) * f
            val wobble = sin(f * 3.4 + phase).toFloat() * pt(26f) * f
            band.lineTo(baseX + wobble - width * 0.5f * f, y)
        }
        band.close()

        scope.drawPath(
            path = band,
            brush = Brush.verticalGradient(
                colorStops = arrayOf(
                    0f to primary.copy(alpha = (0.42 * alphaScale).toFloat().coerceIn(0f, 1f)),
                    0.35f to primary.copy(alpha = (0.30 * alphaScale).toFloat().coerceIn(0f, 1f)),
                    0.75f to secondary.copy(alpha = (0.22 * alphaScale).toFloat().coerceIn(0f, 1f)),
                    1f to Color.Transparent,
                ),
                startY = topY,
                endY = bottomY,
            ),
            blendMode = BlendMode.Plus,
        )

        // Bright filament running down the spine of each ribbon.
        val spine = Path()
        spine.moveTo(baseX, topY)
        for (s in 0..steps) {
            val f = s.toFloat() / steps
            val y = topY + (bottomY - topY) * f
            spine.lineTo(baseX + sin(f * 3.4 + phase).toFloat() * pt(26f) * f, y)
        }
        bloomStroke(spine, primary, pt(2.2f), 0.35 * alphaScale, core = false)
    }
}

// MARK: - Burning Ember — coal bed + falling ash

/**
 * A *dying* fire, deliberately inverted from Flame: the heat lives in a glowing
 * bed at the bottom and cool grey ash falls down through it.
 */
private fun ParticleContext.drawEmberBed(t: Double) {
    val bedY = h * 0.9f

    // Radiant heat haze rising off the coal bed.
    scope.drawRect(
        brush = Brush.verticalGradient(
            colorStops = arrayOf(
                0f to Color.Transparent,
                0.55f to primary.copy(alpha = (0.10 * alphaScale).toFloat().coerceIn(0f, 1f)),
                1f to primary.copy(alpha = (0.26 * alphaScale).toFloat().coerceIn(0f, 1f)),
            ),
            startY = bedY - h * 0.34f,
            endY = bedY + h * 0.1f,
        ),
        topLeft = Offset(0f, bedY - h * 0.34f),
        size = Size(w, h * 0.44f),
        blendMode = BlendMode.Plus,
    )

    // Coals: each breathes on its own phase, some flaring hot.
    for (p in take(count(14))) {
        val breathe = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 0.8 * p.speed + p.phase))
        val flare = if (noise(floor(t * 0.5), p.phase) > 0.86) 1.7 else 1.0
        val x = p.x * w
        val y = bedY + sin(p.phase).toFloat() * pt(16f)
        bloomDot(
            Offset(x, y),
            pt((10f + p.size * 4f) * flare.toFloat()),
            primary,
            breathe * 0.85 * flare * alphaScale,
        )
    }

    // Ash: cool grey flakes tumbling downward — the visual opposite of Flame's
    // rising orange sparks.
    for (p in take(count(22))) {
        val fall = (t * 0.045 * p.speed + p.phase) % 1.0
        val y = h * fall.toFloat()
        val sway = sin(t * 0.9 + p.phase * 2).toFloat() * pt(22f)
        val x = p.x * w + sway
        // Fades as it nears the hot bed, as if consumed.
        val alpha = (1 - fall * 0.75) * 0.5 * alphaScale
        bloomDot(Offset(x, y), pt(p.size * 1.1f), secondary, alpha, hotCore = false)
    }
}

// MARK: - Dark Matter — stars with diffraction spikes

private fun ParticleContext.drawStars(t: Double) {
    val drift = (t * 1.6).toFloat() * scope.density
    for (p in take(count(46))) {
        var x = (p.x * w + drift) % w
        var y = (p.y * h + drift * 0.6f) % h
        if (x < 0) x += w
        if (y < 0) y += h
        val point = Offset(x, y)

        val twinkle = 0.35 + 0.65 * abs(sin(t * 0.9 * p.speed + p.phase))
        val alpha = twinkle * 0.9 * alphaScale
        bloomDot(point, pt(p.size * 1.5f), Color.White, alpha * 0.8)

        // Camera-style diffraction spikes on the brightest stars.
        if (p.size > 5) {
            val len = pt(p.size * 5f) * twinkle.toFloat()
            val spikes = Path().apply {
                moveTo(x - len, y); lineTo(x + len, y)
                moveTo(x, y - len); lineTo(x, y + len)
            }
            bloomStroke(spikes, Color.White, pt(0.8f), alpha * 0.55, core = false)
        }
    }
}

// MARK: - Lava — molten cracks with travelling hot nodes

private fun ParticleContext.drawLava(t: Double) {
    take(count(7)).forEachIndexed { i, p ->
        val baseY = p.y * h
        val path = Path()
        path.moveTo(pt(-20f), baseY)
        var x = pt(-20f)
        var step = 0
        while (x < w + pt(20f)) {
            x += w / 7
            val wobble = sin(t * 0.45 + step * 0.9 + p.phase).toFloat() * pt(26f) +
                sin(t * 0.17 + step * 2.2).toFloat() * pt(12f)
            path.lineTo(x, baseY + wobble)
            step++
        }

        val heat = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 0.75 + p.phase))
        val color = if (i % 2 == 0) primary else secondary
        bloomStroke(path, color, pt(3.4f), heat * alphaScale, core = false)

        val travel = (t * 0.09 * p.speed + p.phase) % 1.0
        val nx = travel.toFloat() * w
        val ny = baseY + sin(t * 0.45 + travel * 6 + p.phase).toFloat() * pt(26f)
        bloomDot(Offset(nx, ny), pt(16f), color, heat * 0.9 * alphaScale)
    }
}

// MARK: - Neon 80s — synthwave horizon with sliced sun

private fun ParticleContext.drawRetroGrid(t: Double) {
    val horizon = h * 0.55f
    val opacity = (0.5 + 0.16 * sin(t * 1.2)) * alphaScale

    val sunR = w * 0.26f
    val sunC = Offset(w / 2, horizon - sunR * 0.45f)
    scope.drawCircle(
        brush = Brush.verticalGradient(
            colors = listOf(
                secondary.copy(alpha = (0.75 * alphaScale).toFloat().coerceIn(0f, 1f)),
                primary.copy(alpha = (0.85 * alphaScale).toFloat().coerceIn(0f, 1f)),
            ),
            startY = sunC.y - sunR,
            endY = sunC.y + sunR,
        ),
        radius = sunR,
        center = sunC,
        blendMode = BlendMode.Plus,
    )
    // Classic horizontal slices through the lower half of the sun.
    var slice = pt(6f)
    while (slice < sunR * 1.1f) {
        scope.drawRect(
            color = Color.Black.copy(alpha = 0.85f),
            topLeft = Offset(sunC.x - sunR, sunC.y + slice),
            size = Size(sunR * 2, slice * 0.16f + pt(1.5f)),
        )
        slice *= 1.32f
    }

    for (i in -6..6) {
        val path = Path().apply {
            moveTo(w / 2, horizon)
            lineTo(w / 2 + i * w / 5, h)
        }
        bloomStroke(path, secondary, pt(1f), opacity * 0.8, core = false)
    }

    val scroll = ((t * 0.4) % 1.0).toFloat()
    for (i in 0 until 11) {
        val f = (i + scroll) / 11
        val y = horizon + (h - horizon) * f * f
        if (y > h) continue
        val path = Path().apply { moveTo(0f, y); lineTo(w, y) }
        bloomStroke(path, secondary, pt(1f), opacity * (0.35 + f), core = false)
    }

    val hz = Path().apply { moveTo(0f, horizon); lineTo(w, horizon) }
    bloomStroke(hz, primary, pt(2f), 0.7 * alphaScale)
}

// MARK: - Galaxy — nebula clouds + star flares

private fun ParticleContext.drawSparkles(t: Double) {
    for (i in 0 until 3) {
        val a = t * 0.05 + i * 2.2
        val c = Offset(
            w * (0.25f + 0.5f * (0.5f + 0.5f * sin(a).toFloat())),
            h * (0.3f + 0.4f * (0.5f + 0.5f * cos(a * 0.7).toFloat())),
        )
        bloomDot(
            c,
            w * 0.42f,
            if (i % 2 == 0) primary else secondary,
            0.13 * alphaScale,
            hotCore = false,
        )
    }

    for (p in take(count(52))) {
        val twinkle = 0.25 + 0.75 * abs(sin(t * 1.25 * p.speed + p.phase))
        val point = Offset(p.x * w, p.y * h)
        val alpha = twinkle * alphaScale
        val color = if (p.phase > 3.2) primary else Color.White

        bloomDot(point, pt(p.size * 1.4f), color, alpha * 0.85)

        if (twinkle > 0.75) {
            val len = pt(p.size * 4f) * twinkle.toFloat()
            val star = Path().apply {
                moveTo(point.x - len, point.y); lineTo(point.x + len, point.y)
                moveTo(point.x, point.y - len); lineTo(point.x, point.y + len)
            }
            bloomStroke(star, color, pt(0.9f), alpha * 0.7, core = false)
        }
    }
}

// MARK: - Themed background

/** Gradient + parallax particle planes for the current theme. */
@Composable
fun ThemedBackground(
    configuration: ThemeConfiguration,
    settings: AppSettings,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(
                brush = Brush.verticalGradient(
                    colors = configuration.backgroundColors,
                    startY = 0f,
                    endY = size.height,
                ),
            )
        }

        if (settings.effectIntensity != EffectIntensity.Off) {
            val blur = (settings.backgroundBlur * 0.28).toFloat()

            if (settings.parallaxEnabled) {
                ThemeParticles(
                    configuration = configuration.particles,
                    primary = configuration.primary,
                    secondary = configuration.secondary,
                    modifier = Modifier
                        .fillMaxSize()
                        .androidBlur(blur + 2.5f)
                        .scaleBy(1.3f),
                    depth = 0.3,
                    intensity = settings.effectIntensity.opacityScale,
                    speed = settings.animationSpeed.scale,
                )
            }

            ThemeParticles(
                configuration = configuration.particles,
                primary = configuration.primary,
                secondary = configuration.secondary,
                modifier = Modifier.fillMaxSize().androidBlur(blur),
                depth = 1.0,
                intensity = settings.effectIntensity.opacityScale,
                speed = settings.animationSpeed.scale,
            )
        }
    }
}

/** Scales a layer around its centre, for the parallax plane. */
private fun Modifier.scaleBy(factor: Float): Modifier = this.scale(factor)

/**
 * Compose's blur modifier is a no-op below API 31, so on older devices the
 * background simply renders sharp rather than crashing or clipping.
 */
private fun Modifier.androidBlur(radiusDp: Float): Modifier =
    if (radiusDp <= 0.01f || android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.S) {
        this
    } else {
        this.blur(androidx.compose.ui.unit.Dp(radiusDp))
    }
