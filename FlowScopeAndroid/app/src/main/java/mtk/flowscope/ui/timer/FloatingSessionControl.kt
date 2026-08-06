package mtk.flowscope.ui.timer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.util.HapticManager
import kotlin.math.roundToInt

/**
 * A minimalist, draggable floating control that stays on screen across every tab
 * while a session is running — a volume-style vertical slider for satisfaction
 * plus a one-tap log button, so logging never interrupts what you're doing.
 *
 * Ported from `FloatingSessionControl.swift`.
 */
@Composable
fun FloatingSessionControl(
    config: ThemeConfiguration,
    onLog: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = HapticManager.get(LocalContext.current)
    val density = LocalDensity.current

    var level by remember { mutableFloatStateOf(50f) }
    var isHidden by remember { mutableStateOf(false) }
    var justLogged by remember { mutableStateOf(false) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }

    val width = 56.dp
    val trackHeight = 150.dp

    /** Red at 0, yellow around the middle, green at 100. */
    val levelColor = satisfactionColor(level.toInt())

    LaunchedEffect(justLogged) {
        if (justLogged) {
            delay(600)
            justLogged = false
        }
    }

    Box(
        modifier = modifier
            .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
            .pointerInput(Unit) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    offsetX += dragAmount.x
                    offsetY += dragAmount.y
                }
            },
    ) {
        if (isHidden) {
            // Collapsed handle
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(config.surface.copy(alpha = 0.92f))
                    .border(2.dp, config.primary, CircleShape)
                    .clickable { isHidden = false },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "${level.toInt()}",
                    color = Color.White,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = config.fontDesign.fontFamily,
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(config.cornerRadius + 10.dp))
                    .background(config.surface.copy(alpha = 0.92f))
                    .border(
                        1.dp,
                        config.primary.copy(alpha = 0.5f),
                        RoundedCornerShape(config.cornerRadius + 10.dp),
                    )
                    .padding(10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Filled.KeyboardArrowDown,
                    contentDescription = "Hide quick log",
                    tint = config.primary.copy(alpha = 0.8f),
                    modifier = Modifier
                        .size(20.dp)
                        .clickable { isHidden = true },
                )
                Spacer(Modifier.height(10.dp))

                // Satisfaction track (volume-style, red → green).
                //
                // The gradient is fixed full-height and only the filled portion is
                // revealed, so the colour you see reflects the actual position on
                // the 0–100 scale rather than a re-stretched blend: at 20% you only
                // ever see red/orange.
                Box(
                    modifier = Modifier
                        .width(width)
                        .height(trackHeight)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.08f))
                        .pointerInput(Unit) {
                            detectDragGestures(
                                onDragEnd = { haptics.lightImpact() },
                            ) { change, dragAmount ->
                                change.consume()
                                val trackPx = with(density) { trackHeight.toPx() }
                                val next = (level - dragAmount.y / trackPx * 100f)
                                    .coerceIn(0f, 100f)
                                if (next.toInt() != level.toInt()) haptics.selectionFeedback()
                                level = next
                            }
                        },
                    contentAlignment = Alignment.BottomCenter,
                ) {
                    val innerHeight = trackHeight - 12.dp
                    val fillHeight = (innerHeight * (level / 100f)).coerceAtLeast(6.dp)
                    // The gradient is drawn at full track height and revealed only
                    // up to `level`, so the colour reflects the absolute position on
                    // the 0–100 scale rather than a re-stretched blend: at 20% you
                    // only ever see red/orange, never green.
                    Box(
                        modifier = Modifier
                            .padding(bottom = 6.dp)
                            .width(width - 12.dp)
                            .height(fillHeight)
                            .clip(CircleShape),
                        contentAlignment = Alignment.BottomCenter,
                    ) {
                        Box(
                            // requiredHeight, so the gradient keeps its full
                            // track height and is *clipped* by the parent rather
                            // than squashed to fit the fill.
                            modifier = Modifier
                                .requiredWidth(width - 12.dp)
                                .requiredHeight(innerHeight)
                                .background(
                                    Brush.verticalGradient(
                                        listOf(
                                            Color(0xFF30D158),
                                            Color(0xFFFFD60A),
                                            Color(0xFFFF9F0A),
                                            Color(0xFFFF453A),
                                        ),
                                    ),
                                ),
                        )
                    }
                    Box(
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                        contentAlignment = Alignment.TopCenter,
                    ) {
                        Text(
                            "${level.toInt()}",
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = config.fontDesign.fontFamily,
                        )
                    }
                }

                Spacer(Modifier.height(10.dp))

                // Log button
                Box(
                    modifier = Modifier
                        .size(width)
                        .clip(CircleShape)
                        .background(levelColor)
                        .clickable {
                            onLog(level.toInt())
                            haptics.successFeedback()
                            justLogged = true
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        if (justLogged) Icons.Filled.Check else Icons.Filled.Add,
                        contentDescription = "Log satisfaction ${level.toInt()}",
                        tint = Color.White,
                        modifier = Modifier.size(22.dp),
                    )
                }
            }
        }
    }
}
