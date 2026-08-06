import SwiftUI

struct WorkLogView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedSession: Session?
    @State private var showSessionDetail = false
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    
    let filters = ["All", "High Focus", "Medium Focus", "Low Focus"]
    
    var filteredSessions: [Session] {
        let sessions = dataManager.sessions
        
        // Apply filter
        let filtered = sessions.filter { session in
            switch selectedFilter {
            case "High Focus":
                return session.averageMood >= 70
            case "Medium Focus":
                return session.averageMood >= 40 && session.averageMood < 70
            case "Low Focus":
                return session.averageMood < 40
            default:
                return true
            }
        }
        
        // Apply search
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { session in
                session.moodLogs.contains { log in
                    log.note.localizedCaseInsensitiveContains(searchText)
                } || session.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                StatsHeaderView(sessions: filteredSessions)
                
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filters, id: \.self) { filter in
                            FilterPill(
                                title: filter,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tasks...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Session List
                if filteredSessions.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSessions, id: \.id) { session in
                                WorkLogCard(session: session)
                                    .onTapGesture {
                                        selectedSession = session
                                        showSessionDetail = true
                                    }
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Work Log")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedSession) { session in
                SessionGraphView(session: session)
            }
            .onAppear {
                dataManager.fetchAllSessions()
            }
        }
    }
}

// MARK: - Stats Header
struct StatsHeaderView: View {
    @EnvironmentObject var theme: AppThemeManager
    let sessions: [Session]
    
    var totalSessions: Int { sessions.count }
    var totalMinutes: Int { sessions.reduce(0) { $0 + $1.durationInMinutes } }
    var averageMood: Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.averageMood } / sessions.count
    }
    
    var body: some View {
        HStack(spacing: 20) {
            StatBox(
                title: "Sessions",
                value: "\(totalSessions)",
                icon: "timer",
                color: theme.accentColor
            )
            
            StatBox(
                title: "Total Time",
                value: "\(totalMinutes)m",
                icon: "clock",
                color: theme.secondaryAccentColor
            )
            
            StatBox(
                title: "Avg Focus",
                value: "\(averageMood)%",
                icon: "heart.fill",
                color: averageMood >= 70 ? .green : averageMood >= 40 ? .orange : .red
            )
        }
        .padding()
        .background(theme.configuration.backgroundTop)
    }
}

struct StatBox: View {
    @EnvironmentObject var theme: AppThemeManager
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.configuration.surface)
        .cornerRadius(theme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    @EnvironmentObject var theme: AppThemeManager
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: theme.fontDesign))
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(theme.accentColor) : AnyShapeStyle(theme.configuration.surface))
                )
                .foregroundColor(isSelected ? (theme.isDarkMode ? .black : .white) : .primary)
        }
    }
}

// MARK: - Work Log Card
struct WorkLogCard: View {
    @EnvironmentObject var theme: AppThemeManager
    let session: Session
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d • h:mm a"
        return formatter
    }
    
    private var durationString: String {
        let minutes = session.durationInMinutes
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
    
    private var moodColor: Color {
        let mood = session.averageMood
        if mood >= 70 { return .green }
        if mood >= 40 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row: Name and Category
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(session.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Mood Badge
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(moodColor)
                    Text("\(session.averageMood)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(moodColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(moodColor.opacity(0.15))
                .cornerRadius(12)
            }
            
            // Time and Duration
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: session.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundColor(theme.accentColor)
                    Text(durationString)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.moodLogs.count) logs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Mood Logs Preview
            if !session.moodLogs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.moodLogs.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { log in
                            MoodLogChip(log: log)
                        }
                    }
                }
            }
            
            // Chevron
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(theme.configuration.surface)
        .cornerRadius(theme.cornerRadius)
    }
}

// MARK: - Mood Log Chip
struct MoodLogChip: View {
    @EnvironmentObject var theme: AppThemeManager
    let log: MoodLog
    
    private var moodColor: Color {
        let mood = log.satisfaction
        if mood >= 70 { return .green }
        if mood >= 40 { return .orange }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(moodColor)
                .frame(width: 6, height: 6)
            
            Text("\(Int(log.timestamp / 60))m")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(log.satisfaction)%")
                .font(.caption2)
                .fontWeight(.medium)
            
            if !log.note.isEmpty {
                Text("·")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(log.note)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.configuration.surface)
        .cornerRadius(8)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    @EnvironmentObject var theme: AppThemeManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Work Logged Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a timer session and log your moods to see your work history here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            NavigationLink(destination: TimerView()) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Your First Session")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(theme.accentColor)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    WorkLogView()
        .environmentObject(DataManager.shared)
}
