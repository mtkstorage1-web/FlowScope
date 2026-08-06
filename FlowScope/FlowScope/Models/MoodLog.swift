import Foundation

struct MoodLogStruct: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let satisfaction: Int
    let note: String
    
    init(id: UUID = UUID(), timestamp: TimeInterval, satisfaction: Int, note: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.satisfaction = satisfaction
        self.note = note
    }
}
