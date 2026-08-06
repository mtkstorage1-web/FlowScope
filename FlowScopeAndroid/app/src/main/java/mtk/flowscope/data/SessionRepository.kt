package mtk.flowscope.data

import android.content.Context
import androidx.room.Room
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import mtk.flowscope.widget.refreshAllWidgets
import java.util.Calendar

/**
 * Ported from `DataManager.swift`. Owns the Room store, exposes the session
 * list, and republishes the widget stats snapshot after every change.
 */
class SessionRepository private constructor(private val context: Context) {

    private val db = Room.databaseBuilder(
        context.applicationContext,
        FlowScopeDatabase::class.java,
        "flowscope.db",
    ).build()

    private val dao = db.sessionDao()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _sessions = MutableStateFlow<List<SessionWithMoodLogs>>(emptyList())
    val sessions: StateFlow<List<SessionWithMoodLogs>> = _sessions.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        scope.launch {
            _sessions.value = dao.getAll()
            updateSharedStats()
        }
    }

    fun saveSession(session: SessionEntity, logs: List<MoodLogEntity>) {
        scope.launch {
            dao.saveSession(session, logs)
            _sessions.value = dao.getAll()
            updateSharedStats()
        }
    }

    fun deleteSession(sessionId: String) {
        scope.launch {
            dao.deleteSession(sessionId)
            _sessions.value = dao.getAll()
            updateSharedStats()
        }
    }

    fun sessionsForDate(dateMillis: Long): List<SessionWithMoodLogs> =
        _sessions.value.filter { isSameDay(it.startTime, dateMillis) }

    /**
     * Publishes a lightweight summary so the widgets can show today's stats
     * without touching the database directly.
     */
    private suspend fun updateSharedStats() {
        val all = _sessions.value
        val now = System.currentTimeMillis()

        val todaySessions = all.filter { isSameDay(it.startTime, now) }
        val todayMinutes = todaySessions.sumOf { it.durationInMinutes }
        val latest = all.firstOrNull()

        // Last 7 days, oldest → newest.
        val weekly = (6 downTo 0).map { offset ->
            val day = startOfDay(now) - offset * DAY_MILLIS
            all.filter { isSameDay(it.startTime, day) }.sumOf { it.durationInMinutes }
        }

        // Consecutive days ending today with at least one session.
        var streak = 0
        var cursor = startOfDay(now)
        while (all.any { isSameDay(it.startTime, cursor) }) {
            streak++
            cursor -= DAY_MILLIS
        }

        val todayLogs = todaySessions.flatMap { it.moodLogs }
        val averageMood =
            if (todayLogs.isEmpty()) 0 else todayLogs.sumOf { it.satisfaction } / todayLogs.size

        val recentMoods = all
            .flatMap { it.moodLogs }
            .sortedBy { it.timestamp }
            .takeLast(12)
            .map { it.satisfaction }

        val topCategories = todaySessions
            .groupBy { it.category }
            .map { (name, items) -> CategoryTotal(name, items.sumOf { it.durationInMinutes }) }
            .sortedByDescending { it.minutes }
            .take(3)

        SharedStats.write(
            context,
            StatsSnapshot(
                todayMinutes = todayMinutes,
                todaySessionCount = todaySessions.size,
                lastSessionName = latest?.name ?: StatsSnapshot.placeholder.lastSessionName,
                lastSessionCategory = latest?.category
                    ?: StatsSnapshot.placeholder.lastSessionCategory,
                weeklyMinutes = weekly,
                streakDays = streak,
                averageMood = averageMood,
                recentMoods = recentMoods,
                topCategories = topCategories,
            ),
        )
        refreshAllWidgets(context)
    }

    companion object {
        private const val DAY_MILLIS = 24L * 60 * 60 * 1000

        fun startOfDay(millis: Long): Long = Calendar.getInstance().apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        fun isSameDay(a: Long, b: Long): Boolean = startOfDay(a) == startOfDay(b)

        @Volatile
        private var instance: SessionRepository? = null

        fun get(context: Context): SessionRepository =
            instance ?: synchronized(this) {
                instance ?: SessionRepository(context.applicationContext).also { instance = it }
            }
    }
}
