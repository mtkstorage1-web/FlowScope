package mtk.flowscope.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import mtk.flowscope.data.LiveSessionSnapshot
import mtk.flowscope.data.LiveSessionState
import mtk.flowscope.data.SharedStats
import mtk.flowscope.data.SharedThemePalette
import mtk.flowscope.data.SharedThemeStore
import mtk.flowscope.data.StatsSnapshot
import mtk.flowscope.session.formatDuration

/**
 * The six home-screen widgets, ported from FlowScopeWidget.swift and
 * FlowScopeWidgetGallery.swift.
 *
 * WidgetKit's TimelineProvider becomes Glance's `provideGlance`, which reads the
 * same shared snapshots the iOS extension read from the App Group.
 */

private data class WidgetData(
    val stats: StatsSnapshot,
    val live: LiveSessionSnapshot?,
    val palette: SharedThemePalette,
)

private fun readData(context: Context) = WidgetData(
    stats = SharedStats.read(context),
    live = LiveSessionState.read(context),
    palette = SharedThemeStore.read(context),
)

// MARK: - 0. Status widget (live session + today)

class StatusWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = readData(context)
        provideContent { StatusContent(data) }
    }
}

@Composable
private fun StatusContent(data: WidgetData) {
    val p = data.palette
    val compact = LocalSize.current.width < 200.dp

    Column(
        modifier = GlanceModifier.fillMaxSize().themedWidgetBackground(p).then(openAppModifier()),
    ) {
        val live = data.live
        if (live != null) {
            Text(
                live.name.ifBlank { "Focus session" },
                maxLines = 1,
                style = TextStyle(
                    color = ColorProvider(p.textPrimary),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                formatDuration(live.elapsed),
                style = TextStyle(
                    color = ColorProvider(p.primary),
                    fontSize = if (compact) 26.sp else 32.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                if (live.isPaused) "${live.category} · Paused" else live.category,
                maxLines = 1,
                style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
            )
            Spacer(GlanceModifier.defaultWeight())
            MoodButtonsRow(p, compact = true)
        } else {
            Text(
                "Today",
                style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
            )
            Text(
                "${data.stats.todayMinutes}m",
                style = TextStyle(
                    color = ColorProvider(p.primary),
                    fontSize = if (compact) 30.sp else 36.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                "${data.stats.todaySessionCount} sessions · ${data.stats.streakDays}d streak",
                maxLines = 1,
                style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
            )
            Spacer(GlanceModifier.defaultWeight())
            Text(
                data.stats.lastSessionName,
                maxLines = 1,
                style = TextStyle(color = ColorProvider(p.textPrimary), fontSize = 11.sp),
            )
        }
    }
}

class StatusWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StatusWidget()
}

// MARK: - 1. Streak

class StreakWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = readData(context)
        provideContent { StreakContent(data) }
    }
}

@Composable
private fun StreakContent(data: WidgetData) {
    val p = data.palette
    val s = data.stats
    Column(
        modifier = GlanceModifier.fillMaxSize().themedWidgetBackground(p).then(openAppModifier()),
    ) {
        Text("🔥", style = TextStyle(fontSize = 18.sp))
        Spacer(GlanceModifier.defaultWeight())
        Text(
            "${s.streakDays}",
            style = TextStyle(
                color = ColorProvider(p.primary),
                fontSize = 40.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
        Text(
            "day streak",
            style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
        )
        Text(
            "${s.todayMinutes}m today",
            style = TextStyle(
                color = ColorProvider(p.textPrimary),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

class StreakWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StreakWidget()
}

// MARK: - 2. Mood trend

class MoodTrendWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = readData(context)
        provideContent { MoodTrendContent(data) }
    }
}

@Composable
private fun MoodTrendContent(data: WidgetData) {
    val p = data.palette
    val s = data.stats
    val wide = LocalSize.current.width >= 250.dp

    Box(modifier = GlanceModifier.fillMaxSize().themedWidgetBackground(p)) {
        if (wide) {
            Row(modifier = GlanceModifier.fillMaxSize()) {
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Text(
                        "Avg Mood",
                        style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
                    )
                    Text(
                        "${s.averageMood}%",
                        style = TextStyle(
                            color = ColorProvider(MoodPalette.color(s.averageMood)),
                            fontSize = 30.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                    Spacer(GlanceModifier.height(6.dp))
                    MoodSparkline(s.recentMoods, p, 28.dp)
                }
                Spacer(GlanceModifier.width(12.dp))
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = GlanceModifier.fillMaxHeight(),
                ) {
                    Text(
                        "Log now",
                        style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
                    )
                    Spacer(GlanceModifier.height(8.dp))
                    MoodButtonsRow(p)
                }
            }
        } else {
            Column(modifier = GlanceModifier.fillMaxSize()) {
                Text(
                    "Avg Mood",
                    style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
                )
                Text(
                    "${s.averageMood}%",
                    style = TextStyle(
                        color = ColorProvider(MoodPalette.color(s.averageMood)),
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Spacer(GlanceModifier.height(4.dp))
                MoodSparkline(s.recentMoods, p, 22.dp)
                Spacer(GlanceModifier.defaultWeight())
                MoodButtonsRow(p, compact = true)
            }
        }
    }
}

class MoodTrendWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MoodTrendWidget()
}

// MARK: - 3. Weekly

class WeeklyWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = readData(context)
        provideContent { WeeklyContent(data) }
    }
}

@Composable
private fun WeeklyContent(data: WidgetData) {
    val p = data.palette
    val s = data.stats
    Column(
        modifier = GlanceModifier.fillMaxSize().themedWidgetBackground(p).then(openAppModifier()),
    ) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    "This Week",
                    style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
                )
                Text(
                    "${s.weeklyTotal}m",
                    style = TextStyle(
                        color = ColorProvider(p.primary),
                        fontSize = 26.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    "🔥 ${s.streakDays}",
                    style = TextStyle(
                        color = ColorProvider(p.primary),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Text(
                    "streak",
                    style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
                )
            }
        }
        Spacer(GlanceModifier.height(10.dp))
        WeeklyBars(s.weeklyMinutes, p, 52.dp)
    }
}

class WeeklyWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = WeeklyWidget()
}

// MARK: - 4. Quick start

class QuickStartWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = readData(context)
        provideContent { QuickStartContent(data) }
    }
}

@Composable
private fun QuickStartContent(data: WidgetData) {
    val p = data.palette
    val categories = listOf("Coding", "Study", "Reading", "Creative")
    val narrow = LocalSize.current.width < 200.dp
    val visible = if (narrow) categories.take(2) else categories

    Column(modifier = GlanceModifier.fillMaxSize().themedWidgetBackground(p)) {
        val live = data.live
        if (live != null) {
            // A session is already running — show it rather than a start button.
            Text(
                live.name.ifBlank { "Focus session" },
                maxLines = 1,
                style = TextStyle(
                    color = ColorProvider(p.textPrimary),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                formatDuration(live.elapsed),
                style = TextStyle(
                    color = ColorProvider(p.primary),
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Spacer(GlanceModifier.defaultWeight())
            MoodButtonsRow(p, compact = true)
        } else {
            Text(
                "Quick Start",
                style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp),
            )
            Spacer(GlanceModifier.height(6.dp))
            if (narrow) {
                visible.forEach { category ->
                    CategoryButton(category, p)
                    Spacer(GlanceModifier.height(6.dp))
                }
            } else {
                visible.chunked(2).forEach { pair ->
                    Row(modifier = GlanceModifier.fillMaxWidth()) {
                        pair.forEachIndexed { index, category ->
                            Box(modifier = GlanceModifier.defaultWeight()) {
                                CategoryButton(category, p)
                            }
                            if (index == 0) Spacer(GlanceModifier.width(6.dp))
                        }
                    }
                    Spacer(GlanceModifier.height(6.dp))
                }
            }
        }
    }
}

class QuickStartWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QuickStartWidget()
}

// MARK: - 5. Categories

class CategoriesWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = readData(context)
        provideContent { CategoriesContent(data) }
    }
}

@Composable
private fun CategoriesContent(data: WidgetData) {
    val p = data.palette
    val s = data.stats
    Column(
        modifier = GlanceModifier.fillMaxSize().themedWidgetBackground(p).then(openAppModifier()),
    ) {
        Text("Today", style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 11.sp))
        Spacer(GlanceModifier.height(6.dp))

        if (s.topCategories.isEmpty()) {
            Spacer(GlanceModifier.defaultWeight())
            Text(
                "No sessions yet",
                style = TextStyle(color = ColorProvider(p.textSecondary), fontSize = 12.sp),
            )
            Spacer(GlanceModifier.defaultWeight())
        } else {
            s.topCategories.forEach { item ->
                Row(modifier = GlanceModifier.fillMaxWidth()) {
                    Text(
                        item.name,
                        maxLines = 1,
                        modifier = GlanceModifier.defaultWeight(),
                        style = TextStyle(
                            color = ColorProvider(p.textPrimary),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                    Text(
                        "${item.minutes}m",
                        style = TextStyle(
                            color = ColorProvider(p.textSecondary),
                            fontSize = 11.sp,
                        ),
                    )
                }
                Spacer(GlanceModifier.height(3.dp))
                // Proportional bar: this category's share of today's minutes.
                // Glance weights are always equal, so the filled width is
                // measured against the widget's own width instead.
                val trackWidth = LocalSize.current.width - 24.dp
                val ratio = (item.minutes.toFloat() / maxOf(s.todayMinutes, 1)).coerceIn(0f, 1f)
                Box(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .height(5.dp)
                        .background(p.primary.copy(alpha = 0.15f))
                        .cornerRadius(3.dp),
                ) {
                    Box(
                        modifier = GlanceModifier
                            .width((trackWidth * ratio).coerceAtLeast(4.dp))
                            .height(5.dp)
                            .background(p.primary)
                            .cornerRadius(3.dp),
                    ) {}
                }
                Spacer(GlanceModifier.height(8.dp))
            }
        }
    }
}

class CategoriesWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CategoriesWidget()
}
