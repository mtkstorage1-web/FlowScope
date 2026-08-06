package mtk.flowscope.ui.calendar

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.data.SessionRepository
import mtk.flowscope.data.SessionWithMoodLogs
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.ui.timer.satisfactionColor
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Ported from `CalenderView.swift`. */
@Composable
fun CalendarScreen(
    sessions: List<SessionWithMoodLogs>,
    config: ThemeConfiguration,
    onSelectSession: (SessionWithMoodLogs) -> Unit,
    modifier: Modifier = Modifier,
) {
    var selectedDate by remember { mutableLongStateOf(System.currentTimeMillis()) }

    val monthFormat = remember { SimpleDateFormat("MMMM yyyy", Locale.getDefault()) }
    val dayFormat = remember { SimpleDateFormat("EEEE, MMM d", Locale.getDefault()) }
    val timeFormat = remember { SimpleDateFormat("h:mm a", Locale.getDefault()) }

    val daySessions = sessions.filter {
        SessionRepository.isSameDay(it.startTime, selectedDate)
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(vertical = 16.dp),
    ) {
        Text(
            "History",
            color = config.textPrimary,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = config.fontDesign.fontFamily,
            modifier = Modifier.padding(start = 16.dp, bottom = 16.dp),
        )

        // Month navigation
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.ChevronLeft,
                "Previous month",
                tint = config.primary,
                modifier = Modifier
                    .size(28.dp)
                    .clickable { selectedDate = shiftMonth(selectedDate, -1) },
            )
            Text(
                monthFormat.format(Date(selectedDate)),
                color = config.textPrimary,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
            Icon(
                Icons.Filled.ChevronRight,
                "Next month",
                tint = config.primary,
                modifier = Modifier
                    .size(28.dp)
                    .clickable { selectedDate = shiftMonth(selectedDate, 1) },
            )
        }

        Spacer(Modifier.height(16.dp))

        // Weekday headers
        val weekdays = remember {
            val symbols = java.text.DateFormatSymbols(Locale.getDefault()).shortWeekdays
            // Calendar.SUNDAY == 1, and index 0 is empty.
            (1..7).map { symbols[it].take(2) }
        }
        Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
            weekdays.forEach { day ->
                Text(
                    day,
                    color = config.textSecondary,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                    fontFamily = config.fontDesign.fontFamily,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        // Day grid
        val days = remember(selectedDate) { daysInMonth(selectedDate) }
        days.chunked(7).forEach { week ->
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                week.forEach { date ->
                    Box(Modifier.weight(1f)) {
                        if (date != null) {
                            DayCell(
                                date = date,
                                isSelected = SessionRepository.isSameDay(date, selectedDate),
                                sessions = sessions.filter {
                                    SessionRepository.isSameDay(it.startTime, date)
                                },
                                config = config,
                            ) { selectedDate = date }
                        } else {
                            Spacer(Modifier.height(50.dp))
                        }
                    }
                }
                // Pad short final weeks so the grid stays aligned.
                repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
            }
        }

        Spacer(Modifier.height(20.dp))

        Text(
            dayFormat.format(Date(selectedDate)),
            color = config.textPrimary,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = config.fontDesign.fontFamily,
            modifier = Modifier.padding(horizontal = 16.dp),
        )

        Spacer(Modifier.height(12.dp))

        if (daySessions.isEmpty()) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 30.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Filled.Timer,
                    null,
                    tint = config.textSecondary,
                    modifier = Modifier.size(32.dp),
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "No sessions this day",
                    color = config.textSecondary,
                    fontSize = 14.sp,
                    fontFamily = config.fontDesign.fontFamily,
                )
            }
        } else {
            daySessions.forEach { session ->
                SessionCard(session, config, timeFormat) { onSelectSession(session) }
                Spacer(Modifier.height(10.dp))
            }
        }
    }
}

@Composable
private fun DayCell(
    date: Long,
    isSelected: Boolean,
    sessions: List<SessionWithMoodLogs>,
    config: ThemeConfiguration,
    onClick: () -> Unit,
) {
    val dayNumber = Calendar.getInstance().apply { timeInMillis = date }.get(Calendar.DAY_OF_MONTH)

    Column(
        modifier = Modifier
            .height(50.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(config.cornerRadius / 1.5f))
            .background(if (isSelected) config.primary else Color.Transparent)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            "$dayNumber",
            color = if (isSelected) Color.Black else config.textPrimary,
            fontSize = 14.sp,
            fontFamily = config.fontDesign.fontFamily,
        )
        if (sessions.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            val avgMood = sessions.sumOf { it.averageMood } / sessions.size
            Box(Modifier.size(6.dp).clip(CircleShape).background(satisfactionColor(avgMood)))
        }
    }
}

@Composable
private fun SessionCard(
    session: SessionWithMoodLogs,
    config: ThemeConfiguration,
    timeFormat: SimpleDateFormat,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(config.cornerRadius))
            .background(config.surface)
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                "${session.durationInMinutes} min · ${session.name}",
                color = config.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = config.fontDesign.fontFamily,
            )
            Text(
                timeFormat.format(Date(session.startTime)),
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        Text(
            "${session.averageMood}%",
            color = config.textPrimary,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.width(4.dp))
        Icon(
            Icons.Filled.Favorite,
            null,
            tint = satisfactionColor(session.averageMood),
            modifier = Modifier.size(14.dp),
        )
        Spacer(Modifier.width(8.dp))
        Icon(
            Icons.Filled.ChevronRight,
            null,
            tint = config.textSecondary,
            modifier = Modifier.size(16.dp),
        )
    }
}

// MARK: - Helpers

private fun shiftMonth(millis: Long, delta: Int): Long =
    Calendar.getInstance().apply {
        timeInMillis = millis
        add(Calendar.MONTH, delta)
    }.timeInMillis

/** Leading nulls pad the grid so day 1 lands under the right weekday. */
private fun daysInMonth(millis: Long): List<Long?> {
    val calendar = Calendar.getInstance().apply {
        timeInMillis = millis
        set(Calendar.DAY_OF_MONTH, 1)
        set(Calendar.HOUR_OF_DAY, 12)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }
    val firstWeekday = calendar.get(Calendar.DAY_OF_WEEK)
    val daysCount = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

    val days = MutableList<Long?>(firstWeekday - 1) { null }
    for (day in 1..daysCount) {
        days += Calendar.getInstance().apply {
            timeInMillis = calendar.timeInMillis
            set(Calendar.DAY_OF_MONTH, day)
        }.timeInMillis
    }
    return days
}
