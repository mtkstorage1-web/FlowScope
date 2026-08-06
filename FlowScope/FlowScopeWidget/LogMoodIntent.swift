//
//  LogMoodIntent.swift
//  FlowScopeWidget
//
//  Powers the satisfaction quick-log buttons on the Lock Screen and in the
//  Dynamic Island. Runs in the widget extension process, so it can't touch
//  SessionManager directly — it just queues the tap for the app to apply.
//

import AppIntents
import ActivityKit

struct LogMoodIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Mood"
    static var description = IntentDescription("Quickly logs how you feel without opening FlowScope.")

    // Stay on the Lock Screen / Dynamic Island — don't launch the app.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Satisfaction")
    var level: Int

    init() {
        self.level = 50
    }

    init(level: Int) {
        self.level = level
    }

    func perform() async throws -> some IntentResult {
        PendingMoodQueue.enqueue(satisfaction: level)
        return .result()
    }
}
