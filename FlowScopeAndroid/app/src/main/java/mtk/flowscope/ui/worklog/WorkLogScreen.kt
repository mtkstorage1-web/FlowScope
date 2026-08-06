package mtk.flowscope.ui.worklog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FormatListBulleted
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.data.MoodLogEntity
import mtk.flowscope.data.SessionWithMoodLogs
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.ui.timer.ThemedTextField
import mtk.flowscope.ui.timer.satisfactionColor
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val Filters = listOf("All", "High Focus", "Medium Focus", "Low Focus")

/** Ported from `WorkLogView.swift`. */
@Composable
fun WorkLogScreen(
    sessions: List<SessionWithMoodLogs>,
    config: ThemeConfiguration,
    onSelectSession: (SessionWithMoodLogs) -> Unit,
    modifier: Modifier = Modifier,
) {
    var searchText by remember { mutableStateOf("") }
    var selectedFilter by remember { mutableStateOf("All") }

    val filtered = remember(sessions, searchText, selectedFilter) {
        sessions
            .filter { session ->
                when (selectedFilter) {
                    "High Focus" -> session.averageMood >= 70
                    "Medium Focus" -> session.averageMood in 40..69
                    "Low Focus" -> session.averageMood < 40
                    else -> true
                }
            }
            .filter { session ->
                searchText.isEmpty() ||
                    session.name.contains(searchText, ignoreCase = true) ||
                    session.moodLogs.any { it.note.contains(searchText, ignoreCase = true) }
            }
    }

    Column(modifier = modifier.fillMaxSize()) {
        Text(
            "Work Log",
            color = config.textPrimary,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = config.fontDesign.fontFamily,
            modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 8.dp),
        )

        StatsHeader(filtered, config)

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Filters.forEach { filter ->
                FilterPill(filter, selectedFilter == filter, config) { selectedFilter = filter }
            }
        }

        Row(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Search, null, tint = config.textSecondary)
            Spacer(Modifier.width(8.dp))
            ThemedTextField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = "Search tasks…",
                config = config,
            )
        }

        Spacer(Modifier.height(8.dp))

        if (filtered.isEmpty()) {
            EmptyState(config)
        } else {
            LazyColumn(
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    horizontal = 16.dp,
                    vertical = 12.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(filtered, key = { it.id }) { session ->
                    WorkLogCard(session, config) { onSelectSession(session) }
                }
            }
        }
    }
}

@Composable
private fun StatsHeader(sessions: List<SessionWithMoodLogs>, config: ThemeConfiguration) {
    val totalMinutes = sessions.sumOf { it.durationInMinutes }
    val averageMood =
        if (sessions.isEmpty()) 0 else sessions.sumOf { it.averageMood } / sessions.size

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(config.backgroundTop)
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        StatBox("Sessions", "${sessions.size}", Icons.Filled.Timer, config.primary, config, Modifier.weight(1f))
        StatBox("Total Time", "${totalMinutes}m", Icons.Filled.AccessTime, config.secondary, config, Modifier.weight(1f))
        StatBox(
            "Avg Focus",
            "$averageMood%",
            Icons.Filled.Favorite,
            satisfactionColor(averageMood),
            config,
            Modifier.weight(1f),
        )
    }
}

@Composable
private fun StatBox(
    title: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    config: ThemeConfiguration,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(config.cornerRadius))
            .background(config.surface)
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = color, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(4.dp))
            Text(
                value,
                color = config.textPrimary,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        Text(
            title,
            color = config.textSecondary,
            fontSize = 11.sp,
            fontFamily = config.fontDesign.fontFamily,
        )
    }
}

@Composable
private fun FilterPill(
    title: String,
    isSelected: Boolean,
    config: ThemeConfiguration,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(if (isSelected) config.primary else config.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Text(
            title,
            color = if (isSelected) Color.Black else config.textPrimary,
            fontSize = 12.sp,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            fontFamily = config.fontDesign.fontFamily,
        )
    }
}

@Composable
private fun WorkLogCard(
    session: SessionWithMoodLogs,
    config: ThemeConfiguration,
    onClick: () -> Unit,
) {
    val dateFormat = remember { SimpleDateFormat("EEEE, MMM d • h:mm a", Locale.getDefault()) }
    val moodColor = satisfactionColor(session.averageMood)

    val minutes = session.durationInMinutes
    val durationString = if (minutes >= 60) "${minutes / 60}h ${minutes % 60}m" else "${minutes}m"

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(config.cornerRadius))
            .background(config.surface)
            .clickable(onClick = onClick)
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(
                    session.name,
                    color = config.textPrimary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = config.fontDesign.fontFamily,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Sell, null, tint = config.textSecondary, modifier = Modifier.size(12.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(
                        session.category,
                        color = config.textSecondary,
                        fontSize = 12.sp,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
            }

            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(moodColor.copy(alpha = 0.15f))
                    .padding(horizontal = 10.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Favorite, null, tint = moodColor, modifier = Modifier.size(12.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    "${session.averageMood}%",
                    color = moodColor,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = config.fontDesign.fontFamily,
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.AccessTime, null, tint = config.textSecondary, modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(4.dp))
            Text(
                dateFormat.format(Date(session.startTime)),
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Icon(Icons.Filled.Timer, null, tint = config.primary, modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(4.dp))
            Text(
                durationString,
                color = config.textPrimary,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = config.fontDesign.fontFamily,
            )
            Spacer(Modifier.width(10.dp))
            Icon(
                Icons.Filled.FormatListBulleted,
                null,
                tint = config.textSecondary,
                modifier = Modifier.size(12.dp),
            )
            Spacer(Modifier.width(2.dp))
            Text(
                "${session.moodLogs.size}",
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }

        if (session.moodLogs.isNotEmpty()) {
            Spacer(Modifier.height(10.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                session.moodLogs.sortedBy { it.timestamp }.forEach { log ->
                    MoodLogChip(log, config)
                }
            }
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            Icon(
                Icons.Filled.ChevronRight,
                null,
                tint = config.textSecondary,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

@Composable
private fun MoodLogChip(log: MoodLogEntity, config: ThemeConfiguration) {
    val moodColor = satisfactionColor(log.satisfaction)
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .border(1.dp, config.primary.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(6.dp).clip(CircleShape).background(moodColor))
        Spacer(Modifier.width(4.dp))
        Text(
            "${(log.timestamp / 60).toInt()}m",
            color = config.textSecondary,
            fontSize = 10.sp,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.width(4.dp))
        Text(
            "${log.satisfaction}%",
            color = config.textPrimary,
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            fontFamily = config.fontDesign.fontFamily,
        )
        if (log.note.isNotEmpty()) {
            Spacer(Modifier.width(4.dp))
            Text(
                "· ${log.note}",
                color = config.textSecondary,
                fontSize = 10.sp,
                fontFamily = config.fontDesign.fontFamily,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun EmptyState(config: ThemeConfiguration) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Filled.Timer,
            null,
            tint = config.textSecondary,
            modifier = Modifier.size(60.dp),
        )
        Spacer(Modifier.height(20.dp))
        Text(
            "No Work Logged Yet",
            color = config.textPrimary,
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Start a timer session and log your moods to see your work history here.",
            color = config.textSecondary,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            fontFamily = config.fontDesign.fontFamily,
        )
    }
}
