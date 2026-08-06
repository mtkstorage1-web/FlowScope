package mtk.flowscope.ui.timer

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.session.SessionManager
import mtk.flowscope.session.formatDuration
import mtk.flowscope.theme.AppSettings
import mtk.flowscope.theme.RingMode
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.ui.components.ThemedDigits
import mtk.flowscope.ui.components.ThemedIconButton
import mtk.flowscope.ui.components.ThemedProgressRing
import mtk.flowscope.ui.components.themedSurface
import kotlin.math.min

/**
 * Pure presentation, ported from `TimerView.swift`. Every colour, font, shape
 * and animation comes from the theme configuration — the only conditionals here
 * are session state (running / paused / idle).
 */
@Composable
fun TimerScreen(
    sessionManager: SessionManager,
    config: ThemeConfiguration,
    settings: AppSettings,
    modifier: Modifier = Modifier,
) {
    var showMoodDial by remember { mutableStateOf(false) }
    var showEndConfirmation by remember { mutableStateOf(false) }
    var showSetupSheet by remember { mutableStateOf(false) }

    /** What the ring measures, per the user's choice. */
    val ringProgress = when (settings.ringMode) {
        RingMode.Cycle -> sessionManager.cycleProgress
        RingMode.SessionGoal ->
            min((sessionManager.elapsedTime / settings.goalLength).toFloat(), 1f)

        RingMode.Hidden -> 0f
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            if (sessionManager.didRestoreSession) {
                RestoredBanner(
                    config = config,
                    onDiscard = { sessionManager.discardSession() },
                    onAcknowledge = { sessionManager.acknowledgeRestore() },
                )
                Spacer(Modifier.height(16.dp))
            }

            if (!sessionManager.ongoingNotificationEnabled) {
                NotificationsDisabledBanner(config)
                Spacer(Modifier.height(16.dp))
            }

            if (sessionManager.isRunning || sessionManager.elapsedTime > 0) {
                SessionHeader(sessionManager, config)
                Spacer(Modifier.height(24.dp))
            }

            ThemedDigits(
                text = formatDuration(sessionManager.elapsedTime),
                config = config,
                settings = settings,
                modifier = Modifier.padding(horizontal = 16.dp),
            )

            Spacer(Modifier.height(24.dp))

            if (settings.ringMode != RingMode.Hidden) {
                Box(contentAlignment = Alignment.Center) {
                    ThemedProgressRing(progress = ringProgress, config = config)
                    // Soft scrim so particle fields (retro grid, scanlines) don't
                    // cut through the readout and wreck its contrast.
                    Box(
                        modifier = Modifier
                            .size(192.dp)
                            .background(
                                Brush.radialGradient(
                                    listOf(
                                        config.backgroundBottom.copy(alpha = 0.85f),
                                        Color.Transparent,
                                    ),
                                ),
                            ),
                    )
                    if (sessionManager.isRunning || sessionManager.elapsedTime > 0) {
                        RingCenter(sessionManager, config)
                    }
                }
                Spacer(Modifier.height(24.dp))
            }

            if (sessionManager.isRunning) {
                LogMoodButton(config) { showMoodDial = true }
                Spacer(Modifier.height(24.dp))
            }

            ControlButtons(
                sessionManager = sessionManager,
                config = config,
                onStart = { showSetupSheet = true },
                onStop = { showEndConfirmation = true },
            )
            Spacer(Modifier.height(40.dp))
        }

        // One-shot celebration when a focus cycle completes.
        AnimatedVisibility(
            visible = sessionManager.cycleJustCompleted,
            enter = fadeIn(),
            exit = fadeOut(),
        ) {
            Box(Modifier.fillMaxSize().background(config.primary.copy(alpha = 0.28f)))
        }
    }

    if (showSetupSheet) {
        SessionSetupSheet(
            config = config,
            onDismiss = { showSetupSheet = false },
            onStart = { name, category ->
                sessionManager.startSession(name, category)
                showSetupSheet = false
            },
        )
    }

    if (showMoodDial) {
        MoodDialSheet(
            config = config,
            onDismiss = { showMoodDial = false },
            onLog = { satisfaction, note ->
                sessionManager.logMood(satisfaction, note)
                showMoodDial = false
            },
        )
    }

    if (showEndConfirmation) {
        AlertDialog(
            onDismissRequest = { showEndConfirmation = false },
            title = { Text("End Session?") },
            text = {
                Text(
                    "'${sessionManager.sessionName}' will be saved with " +
                        "${sessionManager.moodLogs.size} mood logs.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    sessionManager.stopSession()
                    showEndConfirmation = false
                }) { Text("End", color = Color(0xFFFF453A)) }
            },
            dismissButton = {
                TextButton(onClick = { showEndConfirmation = false }) {
                    Text("Cancel", color = config.primary)
                }
            },
            containerColor = config.surface,
            titleContentColor = config.textPrimary,
            textContentColor = config.textSecondary,
        )
    }
}

// MARK: - Banners

/**
 * Shown when a session survived the app being killed. Without this the session
 * keeps running in the widget with no way to act on it.
 */
@Composable
private fun RestoredBanner(
    config: ThemeConfiguration,
    onDiscard: () -> Unit,
    onAcknowledge: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .themedSurface(config)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Refresh, null, tint = config.primary)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                "Session recovered",
                color = config.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
            Text(
                "Picked up where you left off.",
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        TextButton(onClick = onDiscard) { Text("Discard", color = Color(0xFFFF453A)) }
        TextButton(onClick = onAcknowledge) { Text("OK", color = config.primary) }
    }
}

/**
 * Without this the ongoing timer notification silently never appears and
 * there's no way for the user to know the system setting is the reason.
 */
@Composable
private fun NotificationsDisabledBanner(config: ThemeConfiguration) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .themedSurface(config)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Warning, null, tint = Color(0xFFFF9F0A))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                "Notifications are off",
                color = config.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
            Text(
                "Allow notifications to keep the timer running in the background.",
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
    }
}

// MARK: - Header

@Composable
private fun SessionHeader(sessionManager: SessionManager, config: ThemeConfiguration) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            sessionManager.sessionName,
            color = config.textPrimary,
            fontSize = 17.sp,
            fontWeight = config.fontWeight,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            sessionManager.sessionCategory,
            color = config.textSecondary,
            fontSize = 12.sp,
            fontFamily = config.fontDesign.fontFamily,
            modifier = Modifier
                .clip(RoundedCornerShape(config.cornerRadius * 0.6f))
                .background(config.surface)
                .padding(horizontal = 12.dp, vertical = 4.dp),
        )
    }
}

// MARK: - Ring centre

@Composable
private fun RingCenter(sessionManager: SessionManager, config: ThemeConfiguration) {
    val left = sessionManager.timeLeftInCycle.toInt()
    val cycleRemaining = String.format("%d:%02d", left / 60, left % 60)

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            cycleRemaining,
            color = config.primary,
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = config.fontDesign.fontFamily,
        )
        Text(
            "left in cycle",
            color = config.textSecondary,
            fontSize = 11.sp,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Repeat, null, tint = config.textSecondary, modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(3.dp))
            Text(
                "${sessionManager.completedCycles}",
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
            Spacer(Modifier.width(10.dp))
            Icon(Icons.Filled.BarChart, null, tint = config.textSecondary, modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(3.dp))
            Text(
                "${sessionManager.moodLogs.size}",
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
    }
}

// MARK: - Controls

@Composable
private fun LogMoodButton(config: ThemeConfiguration, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(config.primary.copy(alpha = 0.15f))
            .border(1.dp, config.primary.copy(alpha = 0.45f), CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 30.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Tune, null, tint = config.primary)
        Spacer(Modifier.width(8.dp))
        Text(
            "Log How You Feel",
            color = config.primary,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = config.fontDesign.fontFamily,
        )
    }
}

@Composable
private fun ControlButtons(
    sessionManager: SessionManager,
    config: ThemeConfiguration,
    onStart: () -> Unit,
    onStop: () -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(36.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (!sessionManager.isRunning && sessionManager.elapsedTime > 0) {
            ThemedIconButton(Icons.Filled.PlayArrow, "Resume", config, size = 64.dp) {
                sessionManager.resumeSession()
            }
        } else if (sessionManager.isRunning) {
            ThemedIconButton(Icons.Filled.Pause, "Pause", config, size = 64.dp) {
                sessionManager.pauseSession()
            }
        }

        if (!sessionManager.isRunning && sessionManager.elapsedTime == 0.0) {
            ThemedIconButton(Icons.Filled.PlayArrow, "Start session", config, size = 84.dp) {
                onStart()
            }
        } else {
            ThemedIconButton(Icons.Filled.Stop, "End session", config, size = 64.dp) {
                onStop()
            }
        }
    }
}
