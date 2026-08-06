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
