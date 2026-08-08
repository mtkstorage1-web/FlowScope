import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var theme: AppThemeManager
    @State private var selectedDate = Date()
    @State private var selectedSession: Session?
    @State private var showSessionDetail = false
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month Navigation
                    HStack {
                        Button(action: {
                            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Text(monthYearString(from: selectedDate))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Calendar Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: daysInWeek), spacing: 12) {
                        // Day headers
                        ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: 30)
                        }
                        
                        // Day cells
                        ForEach(daysInMonth(), id: \.self) { date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                    sessions: dataManager.sessionsForDate(date)
                                )
                                .onTapGesture {
                                    selectedDate = date
                                }
                            } else {
                                Color.clear
                                    .frame(height: 50)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Selected Day Sessions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(formattedDate(selectedDate))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let daySessions = dataManager.sessionsForDate(selectedDate)
                        
                        if daySessions.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("No sessions this day")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            ForEach(daySessions, id: \.id) { session in
                                SessionCard(session: session)
                                    .onTapGesture {
                                        selectedSession = session
                                        showSessionDetail = true
                                    }
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
            .platformNavigationTitleMode(.large)
            .sheet(item: $selectedSession) { session in
                SessionGraphView(session: session)
                    .environmentObject(dataManager)
                    .environmentObject(theme)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))
        else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysCount = range.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...daysCount {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Day Cell
struct DayCell: View {
    @EnvironmentObject var theme: AppThemeManager
    let date: Date
    let isSelected: Bool
    let sessions: [Session]

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(.body, design: theme.fontDesign))
                .foregroundColor(isSelected ? (theme.isDarkMode ? .white : .black) : .primary)

            if !sessions.isEmpty {
                let avgMood = sessions.reduce(0) { $0 + $1.averageMood } / sessions.count
                Circle()
                    .fill(colorForMood(avgMood))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius / 1.5)
                .fill(isSelected ? theme.accentColor : Color.clear)
        )
    }
    
    private func colorForMood(_ value: Int) -> Color {
        switch value {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        case 70..<90: return .green
        default: return .blue
        }
    }
}

// MARK: - Session Card
struct SessionCard: View {
    @EnvironmentObject var theme: AppThemeManager
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(session.durationString, systemImage: "timer")
                        .foregroundColor(theme.accentColor)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(session.startTime, style: .time)
                        .foregroundColor(.secondary)

                    if !session.category.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(session.category)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("\(session.averageMood)%")
                    .font(.headline)

                Image(systemName: "heart.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(theme.configuration.surface)
        .cornerRadius(12)
    }
}

extension Session: Identifiable { }
