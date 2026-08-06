//
//  PendingMoodQueue.swift
//  FlowScope
//
//  Lets the Lock Screen / Dynamic Island quick-log buttons (which run in the
//  widget extension process via App Intents) hand a satisfaction value back
//  to the running app, since they can't call SessionManager directly.
//

import Foundation

struct PendingMoodEntry: Codable {
    let satisfaction: Int
    let loggedAt: Date
}

enum PendingMoodQueue {
    private static let key = "pendingMoodQueue"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStats.appGroupID)
    }

    /// Called from the widget extension's AppIntent when a Lock Screen / Dynamic Island button is tapped.
    static func enqueue(satisfaction: Int) {
        guard let defaults else { return }
        var queue = readRaw(defaults)
        queue.append(PendingMoodEntry(satisfaction: satisfaction, loggedAt: Date()))
        write(queue, to: defaults)
    }

    /// Called from the main app to drain and apply any quick-logs made while the app wasn't active.
    static func drain() -> [PendingMoodEntry] {
        guard let defaults else { return [] }
        let queue = readRaw(defaults)
        if !queue.isEmpty {
            write([], to: defaults)
        }
        return queue
    }

    private static func readRaw(_ defaults: UserDefaults) -> [PendingMoodEntry] {
        guard let data = defaults.data(forKey: key),
              let queue = try? JSONDecoder().decode([PendingMoodEntry].self, from: data) else {
            return []
        }
        return queue
    }

    /// Drops any queued taps without applying them (used when a session ends).
    static func clear() {
        defaults?.removeObject(forKey: key)
    }

    private static func write(_ queue: [PendingMoodEntry], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Pending Start

/// Lets the Quick Start widget ask the app to begin a session.
enum PendingStartQueue {
    private static let key = "pendingStartCategory"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStats.appGroupID)
    }

    static func request(category: String) {
        defaults?.set(category, forKey: key)
    }

    /// Returns and clears any pending start request.
    static func take() -> String? {
        guard let defaults, let category = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return category
    }
}
