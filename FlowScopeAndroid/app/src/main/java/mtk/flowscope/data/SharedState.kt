package mtk.flowscope.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The Android counterpart of FlowScope's App Group bridge.
 *
 * On iOS the widget extension runs in its own process, so state crossed the
 * boundary through a shared `UserDefaults` suite. Glance widgets run inside our
 * own process, so plain SharedPreferences is enough — but the *shape* of the
 * data is kept identical to LiveSessionState.swift / SharedStats.swift /
 * SharedTheme.swift so the widget code reads the same way.
 */

private const val PREFS = "flowscope.shared"

private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

private fun prefs(context: Context) =
    context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

// MARK: - Live session state

@Serializable
data class LiveMood(
    val timestamp: Double,
    val satisfaction: Int,
    val note: String,
)

/**
 * Single source of truth for the *in-flight* session, so a session survives the
 * app being killed instead of stranding a ghost session only the widget can see.
 */
@Serializable
data class LiveSessionSnapshot(
    val sessionId: String,
    val name: String,
    val category: String,
    /** Epoch millis the session was first started. */
    val sessionStart: Long,
    /** Seconds banked from run segments completed before each pause. */
    val accumulated: Double,
    /** Epoch millis the current run segment began; null while paused. */
    val runningSince: Long?,
    val moods: List<LiveMood>,
) {
    val isRunning: Boolean get() = runningSince != null
    val isPaused: Boolean get() = runningSince == null
    val moodCount: Int get() = moods.size

    /**
     * Elapsed time derived from wall-clock, so it stays correct across process
     * death, doze and reboot.
     */
    val elapsed: Double
        get() {
            val live = runningSince?.let { maxOf(0.0, (System.currentTimeMillis() - it) / 1000.0) } ?: 0.0
            return accumulated + live
        }

    /** Anchor such that `now - anchor == elapsed`, for the notification chronometer. */
    val timerBase: Long get() = System.currentTimeMillis() - (elapsed * 1000).toLong()
}

object LiveSessionState {
    private const val KEY = "liveSessionState.v2"

    fun write(context: Context, snapshot: LiveSessionSnapshot) {
        prefs(context).edit().putString(KEY, json.encodeToString(snapshot)).apply()
    }

    /** Returns the in-flight session, or null when nothing is active. */
    fun read(context: Context): LiveSessionSnapshot? {
        val raw = prefs(context).getString(KEY, null) ?: return null
        return runCatching { json.decodeFromString<LiveSessionSnapshot>(raw) }.getOrNull()
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY).apply()
    }
}

// MARK: - Pending mood queue

/**
 * Lets the widget's quick-log buttons hand a satisfaction value back to the
 * running app, since they can't touch the SessionManager directly.
 */
@Serializable
data class PendingMoodEntry(val satisfaction: Int, val loggedAt: Long)

object PendingMoodQueue {
    private const val KEY = "pendingMoodQueue"

    fun enqueue(context: Context, satisfaction: Int) {
        val queue = read(context).toMutableList()
        queue += PendingMoodEntry(satisfaction, System.currentTimeMillis())
        write(context, queue)
    }

    /** Drains and returns quick-logs made while the app wasn't in the foreground. */
    fun drain(context: Context): List<PendingMoodEntry> {
        val queue = read(context)
        if (queue.isNotEmpty()) write(context, emptyList())
        return queue
    }

    /** Drops queued taps without applying them (used when a session ends). */
    fun clear(context: Context) {
        prefs(context).edit().remove(KEY).apply()
    }

    private fun read(context: Context): List<PendingMoodEntry> {
        val raw = prefs(context).getString(KEY, null) ?: return emptyList()
        return runCatching { json.decodeFromString<List<PendingMoodEntry>>(raw) }.getOrElse { emptyList() }
    }

    private fun write(context: Context, queue: List<PendingMoodEntry>) {
        prefs(context).edit().putString(KEY, json.encodeToString(queue)).apply()
    }
}

/** Lets the Quick Start widget ask the app to begin a session. */
object PendingStartQueue {
    private const val KEY = "pendingStartCategory"

    fun request(context: Context, category: String) {
        prefs(context).edit().putString(KEY, category).apply()
    }

    /** Returns and clears any pending start request. */
    fun take(context: Context): String? {
        val value = prefs(context).getString(KEY, null) ?: return null
        prefs(context).edit().remove(KEY).apply()
        return value
    }
}

// MARK: - Shared stats

@Serializable
data class CategoryTotal(val name: String, val minutes: Int)

/** Lightweight summary the widgets read instead of touching the database. */
@Serializable
data class StatsSnapshot(
    val todayMinutes: Int,
    val todaySessionCount: Int,
    val lastSessionName: String,
    val lastSessionCategory: String,
    /** Minutes per day for the last 7 days, oldest → newest (today last). */
    val weeklyMinutes: List<Int>,
    /** Consecutive days ending today with at least one session. */
    val streakDays: Int,
    /** Average satisfaction across today's logs, 0–100. */
    val averageMood: Int,
    /** Most recent satisfaction values, oldest → newest (max 12). */
    val recentMoods: List<Int>,
    val topCategories: List<CategoryTotal>,
) {
    val weeklyTotal: Int get() = weeklyMinutes.sum()
    val weeklyBest: Int get() = maxOf(weeklyMinutes.maxOrNull() ?: 0, 1)

    companion object {
        val placeholder = StatsSnapshot(
            todayMinutes = 0,
            todaySessionCount = 0,
            lastSessionName = "No sessions yet",
            lastSessionCategory = "FlowScope",
            weeklyMinutes = List(7) { 0 },
            streakDays = 0,
            averageMood = 0,
            recentMoods = emptyList(),
            topCategories = emptyList(),
        )
    }
}

object SharedStats {
    private const val KEY = "sharedStats.v2"

    fun write(context: Context, snapshot: StatsSnapshot) {
        prefs(context).edit().putString(KEY, json.encodeToString(snapshot)).apply()
    }

    fun read(context: Context): StatsSnapshot {
        val raw = prefs(context).getString(KEY, null) ?: return StatsSnapshot.placeholder
        return runCatching { json.decodeFromString<StatsSnapshot>(raw) }
            .getOrElse { StatsSnapshot.placeholder }
    }
}

// MARK: - Shared theme palette

/**
 * Only plain hex strings cross into the widget layer — no Compose types, no
 * shared engine, exactly as in SharedTheme.swift.
 */
@Serializable
data class SharedThemePalette(
    val themeId: String,
    val displayName: String,
    val primaryHex: String,
    val secondaryHex: String,
    val backgroundTopHex: String,
    val backgroundBottomHex: String,
    val textPrimaryHex: String,
    val textSecondaryHex: String,
    val surfaceHex: String,
    val cornerRadius: Double,
) {
    companion object {
        val fallback = SharedThemePalette(
            themeId = "flame",
            displayName = "Flame",
            primaryHex = "#FF6B1A",
            secondaryHex = "#FFC300",
            backgroundTopHex = "#3B0A02",
            backgroundBottomHex = "#1A0B04",
            textPrimaryHex = "#FFFFFF",
            textSecondaryHex = "#FFB088",
            surfaceHex = "#2A0D05",
            cornerRadius = 14.0,
        )
    }
}

object SharedThemeStore {
    private const val KEY = "sharedThemePalette"

    fun write(context: Context, palette: SharedThemePalette) {
        prefs(context).edit().putString(KEY, json.encodeToString(palette)).apply()
    }

    fun read(context: Context): SharedThemePalette {
        val raw = prefs(context).getString(KEY, null) ?: return SharedThemePalette.fallback
        return runCatching { json.decodeFromString<SharedThemePalette>(raw) }
            .getOrElse { SharedThemePalette.fallback }
    }
}
