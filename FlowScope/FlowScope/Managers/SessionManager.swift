import SwiftUI
import Combine
import ActivityKit
import WidgetKit
import OSLog

private let log = Logger(subsystem: "mtk.FlowScope", category: "SessionManager")

@MainActor
final class SessionManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentSession: Session?
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var moodLogs: [MoodLog] = []
    @Published private(set) var sessionName: String = ""
    @Published private(set) var sessionCategory: String = "General"

    /// True when a session was recovered from disk after the app was killed.
    @Published private(set) var didRestoreSession = false

    /// Mirrors the system setting; false means no Dynamic Island / Lock Screen
    /// presentation is possible until the user enables it.
    @Published private(set) var liveActivitiesEnabled = true

    // MARK: - Private State

    /// Time banked from completed run segments (before each pause).
    private var accumulated: TimeInterval = 0
    /// Instant the current run segment began; nil while paused.
    private var runningSince: Date?
    /// Wall-clock start of the whole session (used for `Session.startTime`).
    private var sessionStart: Date = Date()
    private var sessionID = UUID()

    private var ticker: Timer?
    private var liveActivity: Activity<TimerAttributes>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    /// Last whole second pushed to the Live Activity (prevents update spam).
    private var lastPushedSecond: Int = -1
    /// Last cycle index seen, so we can fire a one-shot completion moment.
    private var lastCycleIndex = 0
    /// Set briefly when a focus cycle completes — drives the on-screen flash.
    @Published private(set) var cycleJustCompleted = false

    // MARK: - Init

    init() {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        restoreIfNeeded()
        if currentSession == nil {
            // Nothing to resume — drop any Live Activity from a previous launch.
            endOrphanedActivities()
        }
    }

    // MARK: - Restore

    /// Reattaches to a session that survived app termination. Without this the
    /// widget/Live Activity keep counting while the app shows an idle timer,
    /// leaving a session the user can't stop.
    func restoreIfNeeded() {
        guard let snapshot = LiveSessionState.read() else { return }

        sessionID = snapshot.sessionID
        sessionName = snapshot.name
        sessionCategory = snapshot.category
        sessionStart = snapshot.sessionStart
        accumulated = snapshot.accumulated
        runningSince = snapshot.runningSince
        isRunning = snapshot.isRunning
        isPaused = snapshot.isPaused
        elapsedTime = snapshot.elapsed

        let session = Session(
            startTime: snapshot.sessionStart,
            totalDuration: snapshot.elapsed,
            name: snapshot.name,
            category: snapshot.category
        )
        moodLogs = snapshot.moods.map {
            MoodLog(timestamp: $0.timestamp, satisfaction: $0.satisfaction, note: $0.note)
        }
        session.moodLogs = moodLogs
        currentSession = session
        didRestoreSession = true

        ensureLiveActivity()
        if isRunning {
            startTicker()
            beginBackgroundTask()
        }
        log.info("Restored session '\(snapshot.name, privacy: .public)' at \(Int(snapshot.elapsed))s")
    }

    /// Adopts an existing Live Activity left over from a previous launch.
    private func reattachLiveActivity() {
        liveActivity = Activity<TimerAttributes>.activities.first
    }

    // MARK: - Session Lifecycle

    func startSession(name: String = "Untitled Session", category: String = "General") {
        sessionID = UUID()
        sessionStart = Date()
        accumulated = 0
        runningSince = Date()
        elapsedTime = 0
        moodLogs = []
        sessionName = name
        sessionCategory = category
        isRunning = true
        isPaused = false
        didRestoreSession = false
        lastPushedSecond = -1
        lastCycleIndex = 0

        currentSession = Session(
            startTime: sessionStart,
            totalDuration: 0,
            name: name,
            category: category
        )

        startTicker()
        startLiveActivity()
        beginBackgroundTask()
        persist()

        HapticManager.shared.heavyImpact()
        SoundManager.shared.play(.sessionStart, theme: ThemeManager.shared.currentTheme)
        log.info("Started session '\(name, privacy: .public)'")
    }

    func pauseSession() {
        guard isRunning else { return }

        // Bank the current segment, then stop counting.
        accumulated = elapsedTime
        runningSince = nil
        isRunning = false
        isPaused = true
        stopTicker()

        currentSession?.totalDuration = elapsedTime
        persist()
        updateLiveActivity(force: true)

        HapticManager.shared.mediumImpact()
        SoundManager.shared.play(.sessionPause, theme: ThemeManager.shared.currentTheme)
        log.info("Paused at \(Int(self.elapsedTime))s")
    }

    func resumeSession() {
        guard isPaused else { return }

        runningSince = Date()
        isRunning = true
        isPaused = false

        startTicker()
        persist()
        ensureLiveActivity()

        HapticManager.shared.mediumImpact()
        SoundManager.shared.play(.sessionResume, theme: ThemeManager.shared.currentTheme)
        log.info("Resumed at \(Int(self.elapsedTime))s")
    }

    func stopSession() {
        stopTicker()
        recomputeElapsed()

        isRunning = false
        isPaused = false
        runningSince = nil

        if let session = currentSession {
            session.totalDuration = elapsedTime
            session.endTime = Date()
            session.moodLogs = moodLogs
            DataManager.shared.saveSession(session)
            log.info("Saved session '\(session.name, privacy: .public)' — \(session.durationInMinutes)m")
        }

        endLiveActivity()
        LiveSessionState.clear()
        PendingMoodQueue.clear()
        endBackgroundTask()
        WidgetCenter.shared.reloadAllTimelines()

        HapticManager.shared.successFeedback()
        SoundManager.shared.play(.sessionEnd, theme: ThemeManager.shared.currentTheme)

        currentSession = nil
        elapsedTime = 0
        accumulated = 0
        moodLogs = []
        sessionName = ""
        sessionCategory = "General"
        didRestoreSession = false
    }

    /// Ends a recovered session without saving — escape hatch for a stale
    /// "ghost" session the user no longer wants.
    func discardSession() {
        stopTicker()
        endLiveActivity()
        LiveSessionState.clear()
        PendingMoodQueue.clear()
        endBackgroundTask()
        WidgetCenter.shared.reloadAllTimelines()

        currentSession = nil
        isRunning = false
        isPaused = false
        runningSince = nil
        elapsedTime = 0
        accumulated = 0
        moodLogs = []
        sessionName = ""
        sessionCategory = "General"
        didRestoreSession = false
        log.info("Discarded session")
    }

    func acknowledgeRestore() { didRestoreSession = false }

    // MARK: - Ticking

    /// 1 Hz is enough — elapsed time is derived from wall-clock, not counted up,
    /// so ticks only drive the UI and can never drift or be lost.
    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        recomputeElapsed()
        currentSession?.totalDuration = elapsedTime
        consumePendingMoodLogs()
        detectCycleCompletion()

        // Push at most one Live Activity update per whole second.
        let second = Int(elapsedTime)
        if second != lastPushedSecond, second % 15 == 0 {
            lastPushedSecond = second
            updateLiveActivity()
            persist()
        }
    }

    /// Fires once each time the ring completes a lap.
    private func detectCycleCompletion() {
        let index = completedCycles
        guard index > lastCycleIndex else { lastCycleIndex = index; return }
        lastCycleIndex = index
        guard AppSettings.shared.cycleAlert else { return }

        HapticManager.shared.successFeedback()
        SoundManager.shared.play(.cycleComplete, theme: ThemeManager.shared.currentTheme)
        cycleJustCompleted = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            cycleJustCompleted = false
        }
    }

    private func recomputeElapsed() {
        let live = runningSince.map { max(0, Date().timeIntervalSince($0)) } ?? 0
        elapsedTime = accumulated + live
    }

    // MARK: - Mood Logging

    func logMood(satisfaction: Int, note: String = "") {
        logMood(satisfaction: satisfaction, note: note, at: elapsedTime)
    }

    private func logMood(satisfaction: Int, note: String, at timestamp: TimeInterval) {
        let entry = MoodLog(timestamp: timestamp, satisfaction: satisfaction, note: note)
        moodLogs.append(entry)
        currentSession?.moodLogs = moodLogs

        persist()
        updateLiveActivity(force: true)
        HapticManager.shared.lightImpact()
        SoundManager.shared.play(.moodLogged, theme: ThemeManager.shared.currentTheme)
        log.debug("Mood \(satisfaction)% at \(Int(timestamp))s")
    }

    /// Applies satisfaction taps made from the widget, Lock Screen or Dynamic
    /// Island. Each tap is placed at the moment it happened, not the moment
    /// the app happened to read it.
    func consumePendingMoodLogs() {
        let pending = PendingMoodQueue.drain()
        guard !pending.isEmpty, currentSession != nil else { return }

        for entry in pending {
            let offset = max(0, entry.loggedAt.timeIntervalSince(sessionStart))
            logMood(satisfaction: entry.satisfaction, note: "", at: min(offset, elapsedTime))
        }
    }

    // MARK: - Persistence

    private func persist() {
        let snapshot = LiveSessionState.Snapshot(
            sessionID: sessionID,
            name: sessionName,
            category: sessionCategory,
            sessionStart: sessionStart,
            accumulated: accumulated,
            runningSince: runningSince,
            moods: moodLogs.map {
                LiveSessionState.Mood(timestamp: $0.timestamp, satisfaction: $0.satisfaction, note: $0.note)
            }
        )
        LiveSessionState.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "mtk.FlowScope.FlowScopeStatusWidget")
    }

    // MARK: - Live Activities

    private func contentState() -> TimerAttributes.ContentState {
        TimerAttributes.ContentState(
            elapsedTime: elapsedTime,
            moodCount: moodLogs.count,
            isPaused: isPaused,
            sessionName: sessionName,
            sessionCategory: sessionCategory,
            startDate: Date().addingTimeInterval(-elapsedTime)
        )
    }

    private func startLiveActivity() {
        guard AppSettings.shared.liveActivityEnabled else { return }
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled else {
            log.notice("Live Activities disabled in Settings — Dynamic Island unavailable")
            return
        }
        do {
            liveActivity = try Activity.request(
                attributes: TimerAttributes(),
                content: .init(state: contentState(), staleDate: nil),
                pushType: nil
            )
            log.info("Live Activity started: \(self.liveActivity?.id ?? "-", privacy: .public)")
        } catch {
            log.error("Live Activity start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Guarantees a Live Activity exists whenever a session is active.
    ///
    /// Previously the activity was only ever created inside `startSession()`,
    /// so a session recovered after the app was killed — or one whose activity
    /// the user swiped away — had no Dynamic Island at all. This re-adopts an
    /// existing activity if there is one, and otherwise creates a fresh one.
    func ensureLiveActivity() {
        guard currentSession != nil else { return }
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled else { return }

        if liveActivity == nil {
            reattachLiveActivity()
        }
        if liveActivity == nil {
            startLiveActivity()
        } else {
            updateLiveActivity(force: true)
        }
    }

    /// Clears Live Activities left behind by a previous launch that no longer
    /// correspond to a live session (otherwise they linger on the Lock Screen
    /// forever with a frozen timer).
    private func endOrphanedActivities() {
        let active = Activity<TimerAttributes>.activities
        guard !active.isEmpty else { return }
        for activity in active {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        liveActivity = nil
        log.info("Ended \(active.count) orphaned Live Activities")
    }

    private func updateLiveActivity(force: Bool = false) {
        guard let activity = liveActivity else { return }
        let state = contentState()
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let state = contentState()
        liveActivity = nil
        Task {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "FlowScopeSession") { [weak self] in
            Task { @MainActor in self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    // MARK: - Helpers

    /// Refreshes derived state when the app returns to the foreground.
    func refreshFromForeground() {
        guard currentSession != nil else {
            restoreIfNeeded()
            // Honor a Quick Start widget tap only when nothing is running.
            if currentSession == nil, let category = PendingStartQueue.take() {
                startSession(name: category, category: category)
            }
            return
        }
        _ = PendingStartQueue.take()   // discard: a session is already active
        recomputeElapsed()
        consumePendingMoodLogs()
        ensureLiveActivity()
    }

    func getSessionDuration() -> String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    /// Length of one focus cycle. The ring fills over this, then resets — far
    /// more legible than mapping to a 2-hour ceiling, where a 45-second session
    /// rendered as 0.6% and the ring read as permanently empty.
    static var cycleLength: TimeInterval { AppSettings.shared.cycleLength }

    /// 0–1 progress through the *current* cycle.
    var cycleProgress: CGFloat {
        let position = elapsedTime.truncatingRemainder(dividingBy: Self.cycleLength)
        return CGFloat(position / Self.cycleLength)
    }

    /// How many full 25-minute cycles are complete.
    var completedCycles: Int {
        Int(elapsedTime / Self.cycleLength)
    }

    /// Seconds left in the current cycle.
    var timeLeftInCycle: TimeInterval {
        Self.cycleLength - elapsedTime.truncatingRemainder(dividingBy: Self.cycleLength)
    }

    func getProgressPercentage() -> CGFloat { cycleProgress }
}
