import SwiftUI
import SwiftData
import Combine
import WidgetKit

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var sessions: [Session] = []
    private var modelContext: ModelContext?
    
    private init() {
        // Private init for singleton
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchAllSessions()
    }
    
    func saveSession(_ session: Session) {
        guard let context = modelContext else {
            print("❌ Error: modelContext is nil!")
            return
        }
        
        context.insert(session)
        
        do {
            try context.save()
            print("✅ Session saved successfully!")
            fetchAllSessions()
        } catch {
            print("❌ Error saving session: \(error)")
        }
    }
    
    func fetchAllSessions() {
        guard let context = modelContext else {
            print("❌ Error: modelContext is nil!")
            return
        }
        
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
        
        do {
            sessions = try context.fetch(descriptor)
            print("✅ Fetched \(sessions.count) sessions")
        } catch {
            print("❌ Error fetching sessions: \(error)")
            sessions = []
        }

        updateSharedStats()
    }

    /// Publishes a lightweight summary to the App Group so the Home/Lock Screen
    /// widget can show today's stats without touching SwiftData directly.
    private func updateSharedStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let todaySessions = sessions.filter { calendar.isDateInToday($0.startTime) }
        let todayMinutes = todaySessions.reduce(0) { $0 + $1.durationInMinutes }
        let latest = sessions.first

        // Last 7 days, oldest → newest.
        let weekly: [Int] = (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return sessions
                .filter { calendar.isDate($0.startTime, inSameDayAs: day) }
                .reduce(0) { $0 + $1.durationInMinutes }
        }

        // Consecutive days ending today with at least one session.
        var streak = 0
        var cursor = today
        while sessions.contains(where: { calendar.isDate($0.startTime, inSameDayAs: cursor) }) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        let todayLogs = todaySessions.flatMap(\.moodLogs)
        let averageMood = todayLogs.isEmpty
            ? 0
            : todayLogs.reduce(0) { $0 + $1.satisfaction } / todayLogs.count

        let recentMoods = sessions
            .flatMap(\.moodLogs)
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(12)
            .map(\.satisfaction)

        let grouped = Dictionary(grouping: todaySessions, by: \.category)
        let topCategories = grouped
            .map { SharedStats.Snapshot.CategoryTotal(
                name: $0.key,
                minutes: $0.value.reduce(0) { $0 + $1.durationInMinutes }
            ) }
            .sorted { $0.minutes > $1.minutes }
            .prefix(3)

        SharedStats.write(
            SharedStats.Snapshot(
                todayMinutes: todayMinutes,
                todaySessionCount: todaySessions.count,
                lastSessionName: latest?.name ?? SharedStats.Snapshot.placeholder.lastSessionName,
                lastSessionCategory: latest?.category ?? SharedStats.Snapshot.placeholder.lastSessionCategory,
                weeklyMinutes: weekly,
                streakDays: streak,
                averageMood: averageMood,
                recentMoods: Array(recentMoods),
                topCategories: Array(topCategories)
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func deleteSession(_ session: Session) {
        guard let context = modelContext else { return }
        context.delete(session)
        
        do {
            try context.save()
            fetchAllSessions()
        } catch {
            print("❌ Error deleting session: \(error)")
        }
    }
    
    // MARK: - Editing a finished session
    //
    // Focus is the whole point of the app, so forgetting to tap "log" mid-task
    // is the normal case, not the exception. Everything below lets a session be
    // completed after the fact — the graph and averages recompute from the same
    // relationship the live session writes to.

    /// Adds a log to an already-saved session. `timestamp` is an offset in
    /// seconds from the session's start, clamped to the session's length.
    @discardableResult
    func addMoodLog(to session: Session,
                    satisfaction: Int,
                    note: String = "",
                    at timestamp: TimeInterval) -> MoodLog {
        let clamped = min(max(0, timestamp), max(0, session.totalDuration))
        let entry = MoodLog(
            timestamp: clamped,
            satisfaction: min(max(0, satisfaction), 100),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext?.insert(entry)
        // Append only — SwiftData fills in `entry.session` from the inverse.
        // Setting both sides can insert the log twice.
        session.moodLogs.append(entry)
        persistChanges()
        return entry
    }

    func updateMoodLog(_ log: MoodLog,
                       satisfaction: Int,
                       note: String,
                       at timestamp: TimeInterval? = nil) {
        log.satisfaction = min(max(0, satisfaction), 100)
        log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let timestamp, let session = log.session {
            log.timestamp = min(max(0, timestamp), max(0, session.totalDuration))
        } else if let timestamp {
            log.timestamp = max(0, timestamp)
        }
        persistChanges()
    }

    func deleteMoodLog(_ log: MoodLog, from session: Session) {
        session.moodLogs.removeAll { $0.id == log.id }
        modelContext?.delete(log)
        persistChanges()
    }

    func updateSessionDetails(_ session: Session, name: String, category: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        session.name = trimmedName.isEmpty ? "Untitled Session" : trimmedName
        session.category = trimmedCategory.isEmpty ? "General" : trimmedCategory
        persistChanges()
    }

    /// Saves and republishes derived state (list, widget snapshot).
    private func persistChanges() {
        guard let context = modelContext else {
            print("❌ Error: modelContext is nil!")
            return
        }
        do {
            try context.save()
            fetchAllSessions()
        } catch {
            print("❌ Error saving changes: \(error)")
        }
    }

    func sessionsForDate(_ date: Date) -> [Session] {
        let calendar = Calendar.current
        return sessions.filter { session in
            calendar.isDate(session.startTime, inSameDayAs: date)
        }
    }
}
