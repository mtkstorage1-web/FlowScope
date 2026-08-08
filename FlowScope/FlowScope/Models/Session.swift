import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var totalDuration: TimeInterval
    var name: String          // ← NEW: Name of the task
    var category: String      // ← NEW: Category
    @Relationship(deleteRule: .cascade) var moodLogs: [MoodLog]
    
    init(
        startTime: Date = Date(),
        totalDuration: TimeInterval = 0,
        name: String = "Untitled Session",
        category: String = "General"
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = nil
        self.totalDuration = totalDuration
        self.name = name
        self.category = category
        self.moodLogs = []
    }
    
    var durationInMinutes: Int {
        Int(totalDuration / 60)
    }

    var averageMood: Int {
        guard !moodLogs.isEmpty else { return 0 }
        let sum = moodLogs.reduce(0) { $0 + $1.satisfaction }
        return sum / moodLogs.count
    }

    /// Never renders as an empty row — sessions started from the widget or an
    /// older build can have a blank name.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Session" : trimmed
    }

    /// "1h 05m" / "24m" — the same string everywhere a duration is shown.
    var durationString: String {
        let minutes = durationInMinutes
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(minutes)m"
    }

    /// Logs in chronological order. Retroactively added logs land wherever the
    /// relationship happens to store them, so anything drawing a line or a list
    /// has to sort first.
    var sortedMoodLogs: [MoodLog] {
        moodLogs.sorted { $0.timestamp < $1.timestamp }
    }
}

@Model
final class MoodLog {
    var id: UUID
    var timestamp: TimeInterval
    var satisfaction: Int
    var note: String
    var session: Session?
    
    init(timestamp: TimeInterval, satisfaction: Int, note: String = "") {
        self.id = UUID()
        self.timestamp = timestamp
        self.satisfaction = satisfaction
        self.note = note
    }
}
