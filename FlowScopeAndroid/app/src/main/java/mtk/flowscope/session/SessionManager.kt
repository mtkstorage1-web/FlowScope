package mtk.flowscope.session

import android.app.Application
import android.content.Intent
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import mtk.flowscope.audio.SoundCue
import mtk.flowscope.audio.SoundManager
import mtk.flowscope.data.LiveMood
import mtk.flowscope.data.LiveSessionSnapshot
import mtk.flowscope.data.LiveSessionState
import mtk.flowscope.data.MoodLogEntity
import mtk.flowscope.data.PendingMoodQueue
import mtk.flowscope.data.PendingStartQueue
import mtk.flowscope.data.SessionEntity
import mtk.flowscope.data.SessionRepository
import mtk.flowscope.theme.AppSettings
import mtk.flowscope.theme.ThemeManager
import mtk.flowscope.util.HapticManager
import mtk.flowscope.widget.refreshAllWidgets
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

private const val TAG = "SessionManager"

/**
 * Ported from `SessionManager.swift`.
 *
 * The timing model is preserved exactly: elapsed time is *derived from
 * wall-clock*, never counted up, so it can't drift and survives process death.
 * `accumulated` banks completed run segments and `runningSince` marks the start
 * of the current one.
 */
class SessionManager(app: Application) : AndroidViewModel(app) {

    private val context get() = getApplication<Application>()
    private val repository = SessionRepository.get(context)
    private val settings = AppSettings.get(context)
    private val haptics = HapticManager.get(context)
    private val sound = SoundManager.get(context)
    private val themes = ThemeManager.get(context)

    // MARK: - Observable state

    var isRunning by mutableStateOf(false)
        private set
    var isPaused by mutableStateOf(false)
        private set
    var elapsedTime by mutableStateOf(0.0)
        private set
    var sessionName by mutableStateOf("")
        private set
    var sessionCategory by mutableStateOf("General")
        private set

    val moodLogs = mutableStateListOf<MoodLogEntity>()

    /** True when a session was recovered from disk after the app was killed. */
    var didRestoreSession by mutableStateOf(false)
        private set

    /**
     * Mirrors whether the ongoing notification can actually be shown. When the
     * user has denied notifications there is no lock-screen timer, and the
     * Focus screen says so rather than failing silently.
     */
    var ongoingNotificationEnabled by mutableStateOf(true)
        private set

    /** Set briefly when a focus cycle completes — drives the on-screen flash. */
    var cycleJustCompleted by mutableStateOf(false)
        private set

    var hasSession by mutableStateOf(false)
        private set

    // MARK: - Private state

    /** Seconds banked from run segments completed before each pause. */
    private var accumulated = 0.0

    /** Epoch millis the current run segment began; null while paused. */
    private var runningSince: Long? = null

    /** Wall-clock start of the whole session. */
    private var sessionStart = System.currentTimeMillis()
    private var sessionId = UUID.randomUUID().toString()

    private var ticker: Job? = null

    /** Last whole second pushed to the notification (prevents update spam). */
    private var lastPushedSecond = -1

    /** Last cycle index seen, so we can fire a one-shot completion moment. */
    private var lastCycleIndex = 0

    init {
        restoreIfNeeded()
        if (!hasSession) SessionService.stop(context)
    }

    // MARK: - Restore

    /**
     * Reattaches to a session that survived app termination. Without this the
     * widget and notification keep counting while the app shows an idle timer,
     * leaving a session the user can't stop.
     */
    fun restoreIfNeeded() {
        val snapshot = LiveSessionState.read(context) ?: return

        sessionId = snapshot.sessionId
        sessionName = snapshot.name
        sessionCategory = snapshot.category
        sessionStart = snapshot.sessionStart
        accumulated = snapshot.accumulated
        runningSince = snapshot.runningSince
        isRunning = snapshot.isRunning
        isPaused = snapshot.isPaused
        elapsedTime = snapshot.elapsed

        moodLogs.clear()
        moodLogs += snapshot.moods.map {
            MoodLogEntity(
                sessionId = sessionId,
                timestamp = it.timestamp,
                satisfaction = it.satisfaction,
                note = it.note,
            )
        }

        hasSession = true
        didRestoreSession = true

        ensureOngoingNotification()
        if (isRunning) startTicker()
        Log.i(TAG, "Restored session '${snapshot.name}' at ${snapshot.elapsed.toInt()}s")
    }

    // MARK: - Session lifecycle

    fun startSession(name: String = "Untitled Session", category: String = "General") {
        sessionId = UUID.randomUUID().toString()
        sessionStart = System.currentTimeMillis()
        accumulated = 0.0
        runningSince = sessionStart
        elapsedTime = 0.0
        moodLogs.clear()
        sessionName = name
        sessionCategory = category
        isRunning = true
        isPaused = false
        hasSession = true
        didRestoreSession = false
        lastPushedSecond = -1
        lastCycleIndex = 0

        startTicker()
        persist()
        ensureOngoingNotification()

        haptics.heavyImpact()
        sound.play(SoundCue.SessionStart, themes.currentTheme)
        Log.i(TAG, "Started session '$name'")
    }

    fun pauseSession() {
        if (!isRunning) return

        // Bank the current segment, then stop counting.
        accumulated = elapsedTime
        runningSince = null
        isRunning = false
        isPaused = true
        stopTicker()

        persist()
        updateOngoingNotification()

        haptics.mediumImpact()
        sound.play(SoundCue.SessionPause, themes.currentTheme)
        Log.i(TAG, "Paused at ${elapsedTime.toInt()}s")
    }

    fun resumeSession() {
        if (!isPaused) return

        runningSince = System.currentTimeMillis()
        isRunning = true
        isPaused = false

        startTicker()
        persist()
        ensureOngoingNotification()

        haptics.mediumImpact()
        sound.play(SoundCue.SessionResume, themes.currentTheme)
        Log.i(TAG, "Resumed at ${elapsedTime.toInt()}s")
    }

    fun stopSession() {
        stopTicker()
        recomputeElapsed()

        isRunning = false
        isPaused = false
        runningSince = null

        if (hasSession) {
            val entity = SessionEntity(
                id = sessionId,
                startTime = sessionStart,
                endTime = System.currentTimeMillis(),
                totalDuration = elapsedTime,
                name = sessionName,
                category = sessionCategory,
            )
            repository.saveSession(entity, moodLogs.toList())
            Log.i(TAG, "Saved session '$sessionName' — ${(elapsedTime / 60).toInt()}m")
        }

        SessionService.stop(context)
        LiveSessionState.clear(context)
        PendingMoodQueue.clear(context)
        refreshAllWidgets(context)

        haptics.successFeedback()
        sound.play(SoundCue.SessionEnd, themes.currentTheme)

        clearInMemoryState()
    }

    /**
     * Ends a recovered session without saving — the escape hatch for a stale
     * "ghost" session the user no longer wants.
     */
    fun discardSession() {
        stopTicker()
        SessionService.stop(context)
        LiveSessionState.clear(context)
        PendingMoodQueue.clear(context)
        refreshAllWidgets(context)
        clearInMemoryState()
        Log.i(TAG, "Discarded session")
    }

    private fun clearInMemoryState() {
        hasSession = false
        isRunning = false
        isPaused = false
        runningSince = null
        elapsedTime = 0.0
        accumulated = 0.0
        moodLogs.clear()
        sessionName = ""
        sessionCategory = "General"
        didRestoreSession = false
    }

    fun acknowledgeRestore() {
        didRestoreSession = false
    }

    // MARK: - Ticking

    /**
     * 1 Hz is enough — elapsed time is derived from wall-clock rather than
     * counted up, so ticks only drive the UI and can never drift or be lost.
     */
    private fun startTicker() {
        stopTicker()
        ticker = viewModelScope.launch {
            while (true) {
                tick()
                delay(1000)
            }
        }
    }

    private fun stopTicker() {
        ticker?.cancel()
        ticker = null
    }

    private fun tick() {
        recomputeElapsed()
        consumePendingMoodLogs()
        detectCycleCompletion()

        val second = elapsedTime.toInt()
        if (second != lastPushedSecond && second % 15 == 0) {
            lastPushedSecond = second
            updateOngoingNotification()
            persist()
        }
    }

    /** Fires once each time the ring completes a lap. */
    private fun detectCycleCompletion() {
        val index = completedCycles
        if (index <= lastCycleIndex) {
            lastCycleIndex = index
            return
        }
        lastCycleIndex = index
        if (!settings.cycleAlert) return

        haptics.successFeedback()
        sound.play(SoundCue.CycleComplete, themes.currentTheme)
        cycleJustCompleted = true
        viewModelScope.launch {
            delay(900)
            cycleJustCompleted = false
        }
    }

    private fun recomputeElapsed() {
        val live = runningSince?.let { max(0.0, (System.currentTimeMillis() - it) / 1000.0) } ?: 0.0
        elapsedTime = accumulated + live
    }

    // MARK: - Mood logging

    fun logMood(satisfaction: Int, note: String = "") {
        logMood(satisfaction, note, elapsedTime)
    }

    private fun logMood(satisfaction: Int, note: String, timestamp: Double) {
        moodLogs += MoodLogEntity(
            sessionId = sessionId,
            timestamp = timestamp,
            satisfaction = satisfaction,
            note = note,
        )

        persist()
        updateOngoingNotification()
        haptics.lightImpact()
        sound.play(SoundCue.MoodLogged, themes.currentTheme)
        Log.d(TAG, "Mood $satisfaction% at ${timestamp.toInt()}s")
    }

    /**
     * Applies satisfaction taps made from the widget or the notification. Each
     * tap is placed at the moment it happened, not the moment the app read it.
     */
    fun consumePendingMoodLogs() {
        val pending = PendingMoodQueue.drain(context)
        if (pending.isEmpty() || !hasSession) return

        for (entry in pending) {
            val offset = max(0.0, (entry.loggedAt - sessionStart) / 1000.0)
            logMood(entry.satisfaction, "", min(offset, elapsedTime))
        }
    }

    // MARK: - Persistence

    private fun persist() {
        LiveSessionState.write(
            context,
            LiveSessionSnapshot(
                sessionId = sessionId,
                name = sessionName,
                category = sessionCategory,
                sessionStart = sessionStart,
                accumulated = accumulated,
                runningSince = runningSince,
                moods = moodLogs.map { LiveMood(it.timestamp, it.satisfaction, it.note) },
            ),
        )
        refreshAllWidgets(context)
    }

    // MARK: - Ongoing notification (the Live Activity equivalent)

    /**
     * Guarantees the foreground service is running whenever a session is active.
     *
     * On iOS this was a Live Activity on the Lock Screen and Dynamic Island.
     * Android has no equivalent surface, so the same job — keeping the session
     * alive in the background and visible at a glance — is done by an ongoing
     * foreground-service notification with the same quick-log actions.
     */
    fun ensureOngoingNotification() {
        if (!hasSession) return
        ongoingNotificationEnabled = SessionService.notificationsAllowed(context)
        if (!settings.liveActivityEnabled) return
        SessionService.start(context)
    }

    private fun updateOngoingNotification() {
        if (!hasSession || !settings.liveActivityEnabled) return
        SessionService.update(context)
    }

    // MARK: - Foreground refresh

    /** Refreshes derived state when the app returns to the foreground. */
    fun refreshFromForeground() {
        ongoingNotificationEnabled = SessionService.notificationsAllowed(context)

        if (!hasSession) {
            restoreIfNeeded()
            // Honour a Quick Start widget tap only when nothing is running.
            if (!hasSession) {
                PendingStartQueue.take(context)?.let { startSession(it, it) }
            }
            return
        }
        PendingStartQueue.take(context) // discard: a session is already active
        recomputeElapsed()
        consumePendingMoodLogs()
        ensureOngoingNotification()
    }

    // MARK: - Helpers

    fun sessionDurationString(): String = formatDuration(elapsedTime)

    /**
     * Length of one focus cycle. The ring fills over this, then resets — far
     * more legible than mapping to a fixed ceiling, where a 45-second session
     * rendered as 0.6% and the ring read as permanently empty.
     */
    private val cycleLength: Double get() = settings.cycleLength

    /** 0–1 progress through the *current* cycle. */
    val cycleProgress: Float
        get() = ((elapsedTime % cycleLength) / cycleLength).toFloat()

    /** How many full cycles are complete. */
    val completedCycles: Int get() = (elapsedTime / cycleLength).toInt()

    /** Seconds left in the current cycle. */
    val timeLeftInCycle: Double get() = cycleLength - (elapsedTime % cycleLength)

    override fun onCleared() {
        super.onCleared()
        stopTicker()
    }
}

/** "12:34" or "1:02:03". */
fun formatDuration(seconds: Double): String {
    val total = seconds.toInt()
    val hours = total / 3600
    val minutes = (total % 3600) / 60
    val secs = total % 60
    return if (hours > 0) {
        String.format("%02d:%02d:%02d", hours, minutes, secs)
    } else {
        String.format("%02d:%02d", minutes, secs)
    }
}
