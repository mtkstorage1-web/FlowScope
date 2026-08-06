package mtk.flowscope.util

import androidx.compose.ui.graphics.Color
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Colour helpers ported from `Color+Extensions.swift` and the HSB transform in
 * `ThemeCustomization.swift`.
 */

/** Builds a colour from "#RRGGBB", "RRGGBB" or "#RRGGBBAA". */
fun colorFromHex(hex: String): Color {
    val cleaned = hex.trim().removePrefix("#")
    val value = cleaned.toLongOrNull(16) ?: return Color.Black
    return when (cleaned.length) {
        8 -> Color(
            red = ((value shr 24) and 0xFF) / 255f,
            green = ((value shr 16) and 0xFF) / 255f,
            blue = ((value shr 8) and 0xFF) / 255f,
            alpha = (value and 0xFF) / 255f,
        )

        else -> Color(
            red = ((value shr 16) and 0xFF) / 255f,
            green = ((value shr 8) and 0xFF) / 255f,
            blue = (value and 0xFF) / 255f,
            alpha = 1f,
        )
    }
}

/** "#RRGGBB" representation, used to hand a palette to the widgets. */
fun Color.toHexString(): String = String.format(
    "#%02X%02X%02X",
    (red * 255).roundToInt(),
    (green * 255).roundToInt(),
    (blue * 255).roundToInt(),
)

// MARK: - HSB

/** Hue (0..1), saturation (0..1), brightness (0..1). */
fun Color.toHsb(): Triple<Float, Float, Float> {
    val maxC = max(red, max(green, blue))
    val minC = min(red, min(green, blue))
    val delta = maxC - minC

    val hue = when {
        delta == 0f -> 0f
        maxC == red -> (((green - blue) / delta) % 6f) / 6f
        maxC == green -> (((blue - red) / delta) + 2f) / 6f
        else -> (((red - green) / delta) + 4f) / 6f
    }.let { if (it < 0f) it + 1f else it }

    val saturation = if (maxC == 0f) 0f else delta / maxC
    return Triple(hue, saturation, maxC)
}

fun colorFromHsb(hue: Float, saturation: Float, brightness: Float, alpha: Float = 1f): Color {
    val h = ((hue % 1f) + 1f) % 1f
    val c = brightness * saturation
    val x = c * (1f - abs(((h * 6f) % 2f) - 1f))
    val m = brightness - c

    val (r, g, b) = when ((h * 6f).toInt()) {
        0 -> Triple(c, x, 0f)
        1 -> Triple(x, c, 0f)
        2 -> Triple(0f, c, x)
        3 -> Triple(0f, x, c)
        4 -> Triple(x, 0f, c)
        else -> Triple(c, 0f, x)
    }
    return Color(r + m, g + m, b + m, alpha)
}

/**
 * Shifts hue and scales saturation/brightness, preserving alpha — this is what
 * turns red fire into blue fire without losing the theme's identity.
 *
 * Greys keep their hue: below 0.15 saturation only brightness is scaled, so
 * monochrome themes (Dark Matter) never tint olive.
 */
fun Color.adjusted(hueShift: Double, saturationScale: Double, brightnessScale: Double): Color {
    if (hueShift == 0.0 && saturationScale == 1.0 && brightnessScale == 1.0) return this

    val (h, s, b) = toHsb()
    if (s < 0.15f) {
        return colorFromHsb(h, s, min(1f, b * brightnessScale.toFloat()), alpha)
    }

    var hue = h + (hueShift / 360.0).toFloat()
    hue %= 1f
    if (hue < 0f) hue += 1f

    return colorFromHsb(
        hue = hue,
        saturation = min(1f, s * saturationScale.toFloat()),
        brightness = min(1f, b * brightnessScale.toFloat()),
        alpha = alpha,
    )
}

// MARK: - iOS system colour equivalents
//
// The Swift themes lean on SwiftUI's named colours (.red, .cyan, …). Android's
// defaults are noticeably different, so these mirror the iOS *dark mode* system
// palette to keep each theme's look intact.

object IOSColors {
    val Red = colorFromHex("#FF453A")
    val Orange = colorFromHex("#FF9F0A")
    val Yellow = colorFromHex("#FFD60A")
    val Green = colorFromHex("#30D158")
    val Blue = colorFromHex("#0A84FF")
    val Purple = colorFromHex("#BF5AF2")
    val Cyan = colorFromHex("#64D2FF")
    val Gray = colorFromHex("#8E8E93")
    val White = Color.White
    val Black = Color.Black
}
