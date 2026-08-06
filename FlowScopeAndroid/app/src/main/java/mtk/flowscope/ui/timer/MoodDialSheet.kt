package mtk.flowscope.ui.timer

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.util.HapticManager

/** Ported from `MoodDialView.swift`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoodDialSheet(
    config: ThemeConfiguration,
    onDismiss: () -> Unit,
    onLog: (satisfaction: Int, note: String) -> Unit,
) {
    var satisfaction by remember { mutableFloatStateOf(50f) }
    var note by remember { mutableStateOf("") }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val haptics = HapticManager.get(LocalContext.current)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = config.backgroundBottom,
        contentColor = config.textPrimary,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                "How do you feel?",
                color = config.textPrimary,
                fontSize = 19.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
            Spacer(Modifier.height(20.dp))

            MoodDial(
                satisfaction = satisfaction,
                config = config,
                onChange = { next ->
                    if (next.toInt() != satisfaction.toInt()) haptics.selectionFeedback()
                    satisfaction = next
                },
                onRelease = { haptics.lightImpact() },
            )

            Spacer(Modifier.height(20.dp))

            Text(
                "What are you working on?",
                color = config.textSecondary,
                fontSize = 14.sp,
                fontFamily = config.fontDesign.fontFamily,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(8.dp))
            ThemedTextField(
                value = note,
                onValueChange = { note = it },
                placeholder = "Task description…",
                config = config,
            )

            Spacer(Modifier.height(24.dp))

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(config.cornerRadius))
                    .background(Brush.horizontalGradient(config.accentColors))
                    .clickable { onLog(satisfaction.toInt(), note.trim()) }
                    .padding(vertical = 16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.CheckCircle, null, tint = Color.Black)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "Log Mood",
                        color = Color.Black,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
            }
        }
    }
}

/**
 * The fill stays a red→green mood ramp regardless of theme — that's data, not
 * decoration. Vertical dragging is far more predictable than angular hit-testing.
 */
@Composable
private fun MoodDial(
    satisfaction: Float,
    config: ThemeConfiguration,
    onChange: (Float) -> Unit,
    onRelease: () -> Unit,
) {
    val moodColors = listOf(
        Color(0xFFFF453A),
        Color(0xFFFF9F0A),
        Color(0xFFFFD60A),
        Color(0xFF30D158),
    )

    Box(contentAlignment = Alignment.Center) {
        Canvas(
            modifier = Modifier
                .size(176.dp)
                .pointerInput(Unit) {
                    detectVerticalDragGestures(
                        onDragEnd = onRelease,
                        onVerticalDrag = { _, dragAmount ->
                            // Matches the Swift gesture: -translation.height / 2 / 8.
                            val delta = -dragAmount / 16f
                            onChange((satisfaction + delta).coerceIn(0f, 100f))
                        },
                    )
                },
        ) {
            val lineWidth = 18.dp.toPx()
            val inset = lineWidth / 2
            val arcSize = Size(size.width - lineWidth, size.height - lineWidth)
            val topLeft = Offset(inset, inset)

            drawArc(
                color = config.ring.trackColor,
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = lineWidth, cap = StrokeCap.Round),
            )

            rotate(-90f, center) {
                drawArc(
                    brush = Brush.sweepGradient(moodColors + moodColors.first(), center),
                    startAngle = 0f,
                    sweepAngle = (satisfaction / 100f).coerceIn(0.001f, 1f) * 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = lineWidth, cap = StrokeCap.Round),
                )
            }
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "${satisfaction.toInt()}%",
                color = config.textPrimary,
                fontSize = 38.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = config.fontDesign.fontFamily,
            )
            Text(
                satisfactionLevel(satisfaction),
                color = config.textSecondary,
                fontSize = 14.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
    }
}

fun satisfactionLevel(value: Float): String = when {
    value < 20 -> "Terrible"
    value < 40 -> "Bad"
    value < 60 -> "Okay"
    value < 80 -> "Good"
    else -> "Excellent"
}

fun satisfactionColor(value: Int): Color = when {
    value < 30 -> Color(0xFFFF453A)
    value < 50 -> Color(0xFFFF9F0A)
    value < 70 -> Color(0xFFFFD60A)
    value < 90 -> Color(0xFF30D158)
    else -> Color(0xFF0A84FF)
}
