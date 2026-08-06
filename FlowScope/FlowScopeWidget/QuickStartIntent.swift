//
//  QuickStartIntent.swift
//  FlowScopeWidget
//
//  Lets the Quick Start widget kick off a session for a given category.
//  The widget process can't touch SessionManager, so it queues the request
//  and opens the app, which starts the session on foreground.
//

import AppIntents

struct QuickStartIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Starts a FlowScope session in the chosen category.")

    /// Bring the app forward so the timer is visible immediately.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Category")
    var category: String

    init() { self.category = "General" }
    init(category: String) { self.category = category }

    func perform() async throws -> some IntentResult {
        PendingStartQueue.request(category: category)
        return .result()
    }
}
