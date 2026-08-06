//
//  SharedStats.swift
//  FlowScope
//
//  Bridge that lets the widget extension read focus stats without touching
//  the app's SwiftData store. The main app writes after every save/fetch.
//

import Foundation

enum SharedStats {
    static let appGroupID = "group.mtk.FlowScope"

    private static let key = "sharedStats.v2"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    struct Snapshot: Codable, Equatable {
        var todayMinutes: Int
        var todaySessionCount: Int
        var lastSessionName: String
        var lastSessionCategory: String

        /// Minutes per day for the last 7 days, oldest → newest (today last).
        var weeklyMinutes: [Int]
        /// Consecutive days (ending today) with at least one session.
        var streakDays: Int
        /// Average satisfaction across today's logs, 0–100.
        var averageMood: Int
        /// Most recent satisfaction values, oldest → newest (max 12).
        var recentMoods: [Int]
        /// Top categories today by minutes.
        var topCategories: [CategoryTotal]

        struct CategoryTotal: Codable, Equatable, Hashable {
            var name: String
            var minutes: Int
        }

        var weeklyTotal: Int { weeklyMinutes.reduce(0, +) }
        var weeklyBest: Int { max(weeklyMinutes.max() ?? 0, 1) }

        static let placeholder = Snapshot(
            todayMinutes: 0,
            todaySessionCount: 0,
            lastSessionName: "No sessions yet",
            lastSessionCategory: "FlowScope",
            weeklyMinutes: [0, 0, 0, 0, 0, 0, 0],
            streakDays: 0,
            averageMood: 0,
            recentMoods: [],
            topCategories: []
        )

        static let sample = Snapshot(
            todayMinutes: 96,
            todaySessionCount: 4,
            lastSessionName: "Refactor timer",
            lastSessionCategory: "Coding",
            weeklyMinutes: [45, 80, 30, 120, 60, 95, 96],
            streakDays: 6,
            averageMood: 74,
            recentMoods: [50, 62, 80, 45, 90, 72, 68, 85],
            topCategories: [
                .init(name: "Coding", minutes: 62),
                .init(name: "Study", minutes: 24),
                .init(name: "Reading", minutes: 10)
            ]
        )
    }

    static func write(_ snapshot: Snapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> Snapshot {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}
