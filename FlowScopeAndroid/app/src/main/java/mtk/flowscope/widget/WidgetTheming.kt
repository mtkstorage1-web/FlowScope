package mtk.flowscope.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import mtk.flowscope.MainActivity
import mtk.flowscope.data.PendingMoodQueue
import mtk.flowscope.data.PendingStartQueue
import mtk.flowscope.data.SharedThemePalette
import mtk.flowscope.util.colorFromHex

/**
 * Shared theming and interaction pieces for the Glance widgets, ported from
 * `WidgetTheming.swift`.
 *
 * Glance renders through RemoteViews, so there is no Canvas: the sparkline and
 * weekly chart are built out of laid-out rectangles rather than drawn paths.
 */

val SharedThemePalette.primary: Color get() = colorFromHex(primaryHex)
val SharedThemePalette.secondary: Color get() = colorFromHex(secondaryHex)
val SharedThemePalette.backgroundTop: Color get() = colorFromHex(backgroundTopHex)
val SharedThemePalette.backgroundBottom: Color get() = colorFromHex(backgroundBottomHex)
val SharedThemePalette.textPrimary: Color get() = colorFromHex(textPrimaryHex)
val SharedThemePalette.textSecondary: Color get() = colorFromHex(textSecondaryHex)
val SharedThemePalette.surface: Color get() = colorFromHex(surfaceHex)

/** The card background every widget sits on. */
fun GlanceModifier.themedWidgetBackground(palette: SharedThemePalette): GlanceModifier =
    this.background(palette.backgroundBottom)
        .cornerRadius(palette.cornerRadius.dp)
        .padding(12.dp)

object MoodPalette {
    fun color(value: Int): Color = when {
        value < 30 -> colorFromHex("#FF453A")
        value < 50 -> colorFromHex("#FF9F0A")
        value < 70 -> colorFromHex("#FFD60A")
        value < 90 -> colorFromHex("#30D158")
        else -> colorFromHex("#0A84FF")
    }
}

// MARK: - Actions

private val LevelKey = ActionParameters.Key<Int>("level")
private val CategoryKey = ActionParameters.Key<String>("category")

/**
 * Queues a satisfaction tap for the app to apply. The widget can't reach the
 * SessionManager directly, so the value is placed on the pending queue with the
 * moment it happened.
 */
class LogMoodAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        PendingMoodQueue.enqueue(context, parameters[LevelKey] ?: 50)
        refreshAllWidgets(context)
    }
}

/** Queues a start request and brings the app forward so the timer is visible. */
class QuickStartAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        PendingStartQueue.request(context, parameters[CategoryKey] ?: "General")
        context.startActivity(
            Intent(context, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
    }
}

/** Opens the app on tap — the widget-wide fallback action. */
fun openAppModifier(): GlanceModifier =
    GlanceModifier.clickable(
        androidx.glance.action.actionStartActivity<MainActivity>(),
    )

// MARK: - Mood buttons

/** The same three quick-log levels the iOS widget offered. */
@Composable
fun MoodButtonsRow(palette: SharedThemePalette, compact: Boolean = false) {
    val size = if (compact) 26.dp else 34.dp
    Row(verticalAlignment = Alignment.CenterVertically) {
        MoodButton("🙁", 20, MoodPalette.color(20), size)
        Spacer(GlanceModifier.width(if (compact) 8.dp else 14.dp))
        MoodButton("😐", 60, MoodPalette.color(60), size)
        Spacer(GlanceModifier.width(if (compact) 8.dp else 14.dp))
        MoodButton("🙂", 95, MoodPalette.color(95), size)
    }
}

@Composable
private fun MoodButton(
    glyph: String,
    level: Int,
    tint: Color,
    size: androidx.compose.ui.unit.Dp,
) {
    Box(
        modifier = GlanceModifier
            .size(size)
            .background(tint)
            .cornerRadius(size / 2)
            .clickable(actionRunCallback<LogMoodAction>(actionParametersOf(LevelKey to level))),
        contentAlignment = Alignment.Center,
    ) {
        Text(glyph, style = TextStyle(fontSize = if (size < 30.dp) 12.sp else 15.sp))
    }
}

@Composable
fun CategoryButton(category: String, palette: SharedThemePalette) {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .background(palette.primary.copy(alpha = 0.22f))
            .cornerRadius((palette.cornerRadius * 0.6).dp)
            .padding(vertical = 8.dp)
            .clickable(
                actionRunCallback<QuickStartAction>(actionParametersOf(CategoryKey to category)),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            category,
            maxLines = 1,
            style = TextStyle(
                color = ColorProvider(palette.primary),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
            ),
        )
    }
}

// MARK: - Charts built from boxes

/**
 * Bar sparkline of recent satisfaction values.
 *
 * The iOS version drew a smooth Canvas line; RemoteViews can't draw paths, so
 * each reading becomes a column whose height tracks its value — same trend,
 * same colour language.
 */
@Composable
fun MoodSparkline(
    values: List<Int>,
    palette: SharedThemePalette,
    height: androidx.compose.ui.unit.Dp,
) {
    if (values.isEmpty()) {
        Text(
            "No logs yet",
            style = TextStyle(color = ColorProvider(palette.textSecondary), fontSize = 11.sp),
        )
        return
    }
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(height),
        verticalAlignment = Alignment.Bottom,
    ) {
        values.takeLast(12).forEach { value ->
            val barHeight = (height * (value.coerceIn(0, 100) / 100f)).coerceAtLeast(2.dp)
            Box(
                modifier = GlanceModifier
                    .defaultWeight()
                    .height(barHeight)
                    .padding(horizontal = 1.dp)
                    .background(MoodPalette.color(value))
                    .cornerRadius(2.dp),
            ) {}
        }
    }
}

/** Last 7 days of focus minutes, oldest → newest. */
@Composable
fun WeeklyBars(
    minutes: List<Int>,
    palette: SharedThemePalette,
    barHeight: androidx.compose.ui.unit.Dp,
) {
    val best = maxOf(minutes.maxOrNull() ?: 0, 1)
    val labels = listOf("M", "T", "W", "T", "F", "S", "S")
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.Bottom,
    ) {
        minutes.forEachIndexed { index, value ->
            Box(
                modifier = GlanceModifier.defaultWeight().padding(horizontal = 2.dp),
                contentAlignment = Alignment.BottomCenter,
            ) {
                androidx.glance.layout.Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    Box(
                        modifier = GlanceModifier
                            .fillMaxWidth()
                            .height((barHeight * (value.toFloat() / best)).coerceAtLeast(3.dp))
                            .background(if (value > 0) palette.primary else palette.primary.copy(alpha = 0.18f))
                            .cornerRadius(3.dp),
                    ) {}
                    Spacer(GlanceModifier.height(3.dp))
                    Text(
                        labels.getOrElse(index) { "" },
                        style = TextStyle(
                            color = ColorProvider(palette.textSecondary),
                            fontSize = 9.sp,
                        ),
                    )
                }
            }
        }
    }
}
