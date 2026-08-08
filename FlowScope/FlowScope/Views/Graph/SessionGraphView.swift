import SwiftUI
import Charts

struct SessionGraphView: View {
    @Bindable var session: Session
    @EnvironmentObject var theme: AppThemeManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedPoint: MoodLog?
    /// Non-nil while the add/edit sheet is up. `.new` for a log that doesn't
    /// exist yet, `.existing` to change one that does.
    @State private var editorTarget: MoodLogEditorTarget?
    @State private var isEditingDetails = false

    private var logs: [MoodLog] { session.sortedMoodLogs }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    graphSection
                    logsSection
                }
                .padding(.vertical)
            }
            .platformNavigationTitleMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isEditingDetails = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editorTarget) { target in
                MoodLogEditorView(session: session, target: target)
                    .environmentObject(theme)
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $isEditingDetails) {
                SessionDetailsEditorView(session: session)
                    .environmentObject(theme)
                    .environmentObject(dataManager)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            HStack(spacing: 6) {
                Image(systemName: "tag")
                Text(session.category)
                Text("•")
                Text(session.startTime, format: .dateTime.weekday(.wide).month().day().hour().minute())
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            HStack {
                Label(session.durationString, systemImage: "clock")
                Spacer()
                Label("\(session.averageMood)% avg", systemImage: "heart.fill")
                    .foregroundColor(.green)
                Spacer()
                Label("\(logs.count) logs", systemImage: "list.bullet")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.top, 2)
        }
        .padding(.horizontal)
    }

    // MARK: - Graph

    @ViewBuilder
    private var graphSection: some View {
        if logs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("No mood logs recorded")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Add one now — the graph fills in as soon as you do.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                addLogButton
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Satisfaction Over Time")
                    .font(.headline)
                    .padding(.horizontal)

                Chart {
                    ForEach(logs, id: \.id) { log in
                        LineMark(
                            x: .value("Time", log.timestamp / 60),
                            y: .value("Mood", log.satisfaction)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: theme.chartColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                        PointMark(
                            x: .value("Time", log.timestamp / 60),
                            y: .value("Mood", log.satisfaction)
                        )
                        .foregroundStyle(theme.accentColor)
                        .symbolSize(selectedPoint?.id == log.id ? 100 : 30)
                        .annotation(position: .overlay) {
                            if selectedPoint?.id == log.id {
                                Text(log.note.isEmpty ? "\(log.satisfaction)%" : log.note)
                                    .font(.caption)
                                    .padding(6)
                                    .background(theme.configuration.surface)
                                    .cornerRadius(6)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                        AxisTick()
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                        AxisTick()
                    }
                }
                .chartXAxisLabel("Minutes", position: .bottom)
                .chartYAxisLabel("Satisfaction", position: .leading)
                .padding(.horizontal)
            }
            .background(theme.configuration.surface)
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    // MARK: - Logs

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mood Logs")
                    .font(.headline)
                Spacer()
                if !logs.isEmpty {
                    addLogButton
                }
            }
            .padding(.horizontal)

            ForEach(logs, id: \.id) { log in
                Button {
                    editorTarget = .existing(log)
                } label: {
                    logRow(log)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit") { editorTarget = .existing(log) }
                    Button("Delete", role: .destructive) {
                        withAnimation {
                            if selectedPoint?.id == log.id { selectedPoint = nil }
                            dataManager.deleteMoodLog(log, from: session)
                        }
                    }
                }
                .padding(.horizontal)
            }

            if !logs.isEmpty {
                Text("Tap a log to change its satisfaction, note or time. Long-press to delete.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 2)
            }
        }
    }

    private func logRow(_ log: MoodLog) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(colorForSatisfaction(log.satisfaction))
                .frame(width: 10, height: 10)

            Text("\(Int(log.timestamp / 60))m")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)

            Text("\(log.satisfaction)%")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .leading)

            Text(log.note.isEmpty ? "No note" : log.note)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(theme.configuration.surface.opacity(0.5))
        .cornerRadius(8)
        .contentShape(Rectangle())
    }

    private var addLogButton: some View {
        Button {
            editorTarget = .new
        } label: {
            Label("Add Log", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.accentColor)
        }
        .buttonStyle(.plain)
    }

    private func colorForSatisfaction(_ value: Int) -> Color {
        switch value {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        case 70..<90: return .green
        default: return .blue
        }
    }
}

// MARK: - Editor target

enum MoodLogEditorTarget: Identifiable {
    case new
    case existing(MoodLog)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let log): return log.id.uuidString
        }
    }

    var log: MoodLog? {
        if case .existing(let log) = self { return log }
        return nil
    }
}

// MARK: - Mood Log Editor

/// Add or change a log on a session that has already ended. Deliberately the
/// same dial as the live logger, so a retroactive entry feels like the one you
/// meant to make at the time.
struct MoodLogEditorView: View {
    @EnvironmentObject var theme: AppThemeManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let session: Session
    let target: MoodLogEditorTarget

    @State private var satisfaction: Double = 50
    @State private var note: String = ""
    @State private var minuteMark: Double = 0
    @State private var isDragging = false
    @State private var showDeleteConfirm = false

    private var config: ThemeConfiguration { theme.configuration }
    private var maxMinutes: Double { max(1, Double(session.durationInMinutes)) }
    private var isEditing: Bool { target.log != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundView

                ScrollView {
                    VStack(spacing: 20) {
                        Text(isEditing ? "Update this log" : "How was this stretch?")
                            .font(.system(.title3, design: config.fontDesign).weight(.semibold))
                            .foregroundStyle(config.textPrimary)
                            .padding(.top, 4)

                        dial

                        timeSection
                        noteSection
                        saveButton

                        if isEditing {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Log", systemImage: "trash")
                                    .font(.system(.subheadline, design: config.fontDesign))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(isEditing ? "Edit Log" : "Add Log")
            .platformNavigationTitleMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(config.primary)
                }
            }
            .platformToolbarBackground(config.backgroundTop)
            .confirmationDialog("Delete this log?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let log = target.log {
                        dataManager.deleteMoodLog(log, from: session)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .tint(config.primary)
        .preferredColorScheme(.dark)
        .onAppear(perform: loadInitialValues)
    }

    // MARK: Pieces

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(config.ring.trackColor, lineWidth: 18)
                .frame(width: 176, height: 176)

            Circle()
                .trim(from: 0, to: satisfaction / 100)
                .stroke(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(-90))
                .shadow(color: satisfactionColor.opacity(0.6), radius: 12)
                .animation(isDragging ? nil : .spring(response: 0.3), value: satisfaction)

            VStack(spacing: 2) {
                Text("\(Int(satisfaction))%")
                    .font(.system(size: 38, weight: .bold, design: config.fontDesign))
                    .foregroundStyle(config.textPrimary)
                    .monospacedDigit()
                Text(satisfactionLevel)
                    .font(.system(.subheadline, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)
            }
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    let delta = -value.translation.height / 2
                    let next = min(max(0, satisfaction + delta / 8), 100)
                    if Int(next) != Int(satisfaction) {
                        HapticManager.shared.selectionFeedback()
                    }
                    satisfaction = next
                }
                .onEnded { _ in
                    isDragging = false
                    HapticManager.shared.lightImpact()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Satisfaction")
        .accessibilityValue("\(Int(satisfaction)) percent, \(satisfactionLevel)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: satisfaction = min(100, satisfaction + 5)
            case .decrement: satisfaction = max(0, satisfaction - 5)
            default: break
            }
        }
    }

    /// Where in the session this log belongs. Without it every retroactive log
    /// would stack on top of the others at minute zero and flatten the graph.
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("When in the session")
                    .font(.system(.subheadline, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)
                Spacer()
                Text("\(Int(minuteMark)) min")
                    .font(.system(.subheadline, design: config.fontDesign).weight(.bold))
                    .foregroundStyle(config.primary)
            }
            Slider(value: $minuteMark, in: 0...maxMinutes, step: 1)
                .tint(config.primary)
            Text("Session ran \(session.durationString).")
                .font(.system(.caption2, design: config.fontDesign))
                .foregroundStyle(config.textSecondary)
        }
        .padding()
        .themedSurface(config)
        .padding(.horizontal)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.system(.subheadline, design: config.fontDesign))
                .foregroundStyle(config.textSecondary)

            TextField("", text: $note, prompt:
                Text("What were you doing?").foregroundColor(config.textSecondary.opacity(0.7)),
                axis: .vertical
            )
            .lineLimit(1...4)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(config.surface)
            .foregroundStyle(config.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .stroke(config.primary.opacity(0.35), lineWidth: 1)
            )
            .accessibilityLabel("Note")
        }
        .padding(.horizontal)
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(isEditing ? "Save Changes" : "Add Log")
            }
            .font(.system(.headline, design: config.fontDesign))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .fill(config.accentGradient)
            )
            .shadow(color: config.primary.opacity(0.45), radius: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: Actions

    private func loadInitialValues() {
        guard let log = target.log else {
            // A new log defaults to the end of the session — the usual case is
            // "I just finished and forgot to rate the last stretch".
            minuteMark = maxMinutes
            return
        }
        satisfaction = Double(log.satisfaction)
        note = log.note
        minuteMark = (log.timestamp / 60).rounded()
    }

    private func save() {
        let seconds = minuteMark * 60
        if let log = target.log {
            dataManager.updateMoodLog(log,
                                      satisfaction: Int(satisfaction),
                                      note: note,
                                      at: seconds)
        } else {
            dataManager.addMoodLog(to: session,
                                   satisfaction: Int(satisfaction),
                                   note: note,
                                   at: seconds)
        }
        HapticManager.shared.successFeedback()
        dismiss()
    }

    private var satisfactionColor: Color {
        switch satisfaction {
        case ..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        default: return .green
        }
    }

    private var satisfactionLevel: String {
        switch satisfaction {
        case ..<20: return "Terrible"
        case 20..<40: return "Bad"
        case 40..<60: return "Okay"
        case 60..<80: return "Good"
        default: return "Excellent"
        }
    }
}

// MARK: - Session Details Editor

/// Rename a finished session or recategorize it — a session started from the
/// widget only carries its category, so this is often the first chance to name it.
struct SessionDetailsEditorView: View {
    @EnvironmentObject var theme: AppThemeManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let session: Session

    @State private var name = ""
    @State private var category = ""

    private var config: ThemeConfiguration { theme.configuration }

    private let suggestedCategories = [
        "Work", "Study", "Exercise", "Creative", "Chores",
        "Reading", "Coding", "Meeting", "Gaming", "General"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundView

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        field("Session Name", text: $name, prompt: "e.g., Writing blog post")

                        VStack(alignment: .leading, spacing: 8) {
                            field("Category", text: $category, prompt: "e.g., Work, Study, or your own…")

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(suggestedCategories, id: \.self) { suggestion in
                                        CategoryChip(
                                            title: suggestion,
                                            isSelected: category == suggestion,
                                            config: config
                                        ) {
                                            category = suggestion
                                        }
                                    }
                                }
                                .padding(.trailing, 16)
                            }
                        }

                        Button(action: save) {
                            Text("Save")
                                .font(.system(.headline, design: config.fontDesign))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                                        .fill(config.accentGradient)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Session")
            .platformNavigationTitleMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(config.primary)
                }
            }
            .platformToolbarBackground(config.backgroundTop)
        }
        .tint(config.primary)
        .preferredColorScheme(.dark)
        .onAppear {
            name = session.name
            category = session.category
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(.subheadline, design: config.fontDesign).weight(.semibold))
                .foregroundStyle(config.textSecondary)

            TextField("", text: text, prompt:
                Text(prompt).foregroundColor(config.textSecondary.opacity(0.7))
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(config.surface)
            .foregroundStyle(config.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .stroke(config.primary.opacity(0.35), lineWidth: 1)
            )
            .accessibilityLabel(label)
        }
    }

    private func save() {
        dataManager.updateSessionDetails(session, name: name, category: category)
        dismiss()
    }
}
