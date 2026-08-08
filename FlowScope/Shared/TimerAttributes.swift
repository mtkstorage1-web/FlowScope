import Foundation

// Live Activities are an iOS feature — there is no Dynamic Island or Lock
// Screen on a Mac, so the whole attribute set compiles out there.
#if os(iOS)
import ActivityKit

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
#endif
