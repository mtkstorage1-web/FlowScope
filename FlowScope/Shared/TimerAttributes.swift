import ActivityKit
import Foundation

struct TimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var moodCount: Int
        var isPaused: Bool
        var sessionName: String
        var sessionCategory: String
        /// Anchor date such that `now - startDate` == total elapsed time.
        /// Lets the Lock Screen / Dynamic Island timer tick live via
        /// `Text(startDate, style: .timer)` without needing per-second app updates.
        var startDate: Date
    }
}
