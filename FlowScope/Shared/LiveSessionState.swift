//
//  LiveSessionState.swift
//  FlowScope
//
//  Single source of truth for the *in-flight* session, persisted in the App
//  Group so it survives app termination and is readable by the widget and
//  Live Activity. This is what makes a running session recoverable: if iOS
//  kills the app mid-session, relaunching restores it instead of stranding
//  a "ghost" session that only the widget can see.
//

import Foundation

enum LiveSessionState {
    private static let key = "liveSessionState.v2"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStats.appGroupID)
    }

    struct Mood: Codable, Equatable {
        var timestamp: TimeInterval
        var satisfaction: Int
        var note: String
    }

    struct Snapshot: Codable, Equatable {
        var sessionID: UUID
        var name: String
        var category: String
        /// Wall-clock moment the session was first started.
        var sessionStart: Date
        /// Time banked from previously-completed run segments (before pauses).
        var accumulated: TimeInterval
        /// Non-nil while actively counting; the instant the current segment began.
        var runningSince: Date?
        var moods: [Mood]

        var isRunning: Bool { runningSince != nil }
        var isPaused: Bool { runningSince == nil }
        var moodCount: Int { moods.count }

        /// Elapsed time derived from wall-clock, so it stays correct across
        /// app suspension, termination and device reboot.
        var elapsed: TimeInterval {
            let live = runningSince.map { max(0, Date().timeIntervalSince($0)) } ?? 0
            return accumulated + live
        }

        /// Anchor such that `now - anchor == elapsed`.
        var timerAnchor: Date { Date().addingTimeInterval(-elapsed) }

        /// Range for `Text(timerInterval:pauseTime:countsDown:)` — the only
        /// text API that self-updates inside a WidgetKit timeline entry.
        var timerRange: ClosedRange<Date> {
            let start = timerAnchor
            return start...start.addingTimeInterval(60 * 60 * 24)
        }

        /// Freezes the counter at the paused value; nil while running.
        var pauseTime: Date? {
            isPaused ? timerAnchor.addingTimeInterval(elapsed) : nil
        }
    }

    static func write(_ snapshot: Snapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// Returns the in-flight session, or nil when nothing is active.
    static func read() -> Snapshot? {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
