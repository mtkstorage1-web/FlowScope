package mtk.flowscope.ui.graph

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FormatListBulleted
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.data.SessionWithMoodLogs
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.ui.timer.satisfactionColor

/**
 * Session summary with the satisfaction-over-time chart, ported from
 * `SessionGraphView.swift`.
 *
 * Swift Charts isn't available here, so the line is drawn directly on a Compose
 * Canvas using the same smooth-curve construction as `GraphShape.swift`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionGraphSheet(
    session: SessionWithMoodLogs,
    config: ThemeConfiguration,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val logs = session.moodLogs.sortedBy { it.timestamp }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = config.backgroundBottom,
        contentColor = config.textPrimary,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
        ) {
            Text(
                "Session Summary",
                color = config.textPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = config.fontDesign.fontFamily,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                session.name,
                color = config.textSecondary,
                fontSize = 14.sp,
                fontFamily = config.fontDesign.fontFamily,
            )

            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SummaryStat(
                    Icons.Filled.AccessTime,
                    "${session.durationInMinutes} min",
                    config.textSecondary,
                    config,
                )
                SummaryStat(
                    Icons.Filled.Favorite,
                    "${session.averageMood}% avg",
                    satisfactionColor(session.averageMood),
                    config,
                )
                SummaryStat(
                    Icons.Filled.FormatListBulleted,
                    "${logs.size} logs",
                    config.textSecondary,
                    config,
                )
            }

            Spacer(Modifier.height(24.dp))

            if (logs.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 60.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(
                        Icons.Filled.ShowChart,
                        null,
                        tint = config.textSecondary,
                        modifier = Modifier.size(48.dp),
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        "No mood logs recorded",
                        color = config.textSecondary,
                        fontSize = 16.sp,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
            } else {
                Text(
                    "Satisfaction Over Time",
                    color = config.textPrimary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = config.fontDesign.fontFamily,
                )
                Spacer(Modifier.height(12.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(config.cornerRadius))
                        .background(config.surface)
                        .padding(16.dp),
                ) {
                    MoodChart(
                        values = logs.map { it.timestamp to it.satisfaction },
                        config = config,
                        modifier = Modifier.fillMaxWidth().height(240.dp),
                    )
                }

                Spacer(Modifier.height(24.dp))

                Text(
                    "Mood Logs",
                    color = config.textPrimary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = config.fontDesign.fontFamily,
                )
                Spacer(Modifier.height(8.dp))

                logs.forEach { log ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 3.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(config.surface.copy(alpha = 0.5f))
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(satisfactionColor(log.satisfaction)),
                        )
                        Spacer(Modifier.width(10.dp))
                        Text(
                            "${(log.timestamp / 60).toInt()}m",
                            color = config.textSecondary,
                            fontSize = 12.sp,
                            fontFamily = config.fontDesign.fontFamily,
                            modifier = Modifier.width(44.dp),
                        )
                        Text(
                            "${log.satisfaction}%",
                            color = config.textPrimary,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            fontFamily = config.fontDesign.fontFamily,
                            modifier = Modifier.width(52.dp),
                        )
                        Text(
                            log.note.ifEmpty { "No note" },
                            color = config.textSecondary,
                            fontSize = 12.sp,
                            fontFamily = config.fontDesign.fontFamily,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SummaryStat(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    tint: Color,
    config: ThemeConfiguration,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(4.dp))
        Text(
            label,
            color = tint,
            fontSize = 13.sp,
            fontFamily = config.fontDesign.fontFamily,
        )
    }
}

/**
 * Smooth satisfaction curve with a gradient fill underneath and a point per log.
 * The curve uses the same midpoint-control construction as `SmoothCurveShape`.
 */
@Composable
private fun MoodChart(
    values: List<Pair<Double, Int>>,
    config: ThemeConfiguration,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier) {
        if (values.isEmpty()) return@Canvas

        val maxTime = values.maxOf { it.first }.coerceAtLeast(1.0)
        val gridColor = config.textSecondary.copy(alpha = 0.15f)

        // Horizontal gridlines at 0 / 25 / 50 / 75 / 100%.
        for (i in 0..4) {
            val y = size.height * (1f - i / 4f)
            drawLine(gridColor, Offset(0f, y), Offset(size.width, y), strokeWidth = 1f)
        }

        val points = values.map { (timestamp, satisfaction) ->
            Offset(
                x = if (values.size == 1) {
                    size.width / 2
                } else {
                    (timestamp / maxTime).toFloat() * size.width
                },
                y = size.height * (1f - satisfaction.coerceIn(0, 100) / 100f),
            )
        }

        val line = Path().apply {
            moveTo(points.first().x, points.first().y)
            for (i in 0 until points.size - 1) {
                val current = points[i]
                val next = points[i + 1]
                val midX = (current.x + next.x) / 2
                cubicTo(midX, current.y, midX, next.y, next.x, next.y)
            }
        }

        // Area fill under the curve.
        val fill = Path().apply {
            addPath(line)
            lineTo(points.last().x, size.height)
            lineTo(points.first().x, size.height)
            close()
        }
        drawPath(
            fill,
            Brush.verticalGradient(
                listOf(config.primary.copy(alpha = 0.28f), Color.Transparent),
            ),
        )

        drawPath(
            line,
            Brush.horizontalGradient(config.chartColors),
            style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
        )

        points.forEachIndexed { index, point ->
            drawCircle(config.backgroundBottom, 5.dp.toPx(), point)
            drawCircle(satisfactionColor(values[index].second), 3.5.dp.toPx(), point)
        }
    }
}
