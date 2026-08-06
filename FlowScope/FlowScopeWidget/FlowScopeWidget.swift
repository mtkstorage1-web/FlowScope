//
//  FlowScopeWidget.swift
//  FlowScopeWidget
//
//  Themed Home Screen + Lock Screen widget. Colors come from the App Group
//  palette the app publishes, so the widget always matches the active theme.
//

import WidgetKit
import SwiftUI
import AppIntents

struct FlowScopeEntry: TimelineEntry {
    let date: Date
    let stats: SharedStats.Snapshot
    let live: LiveSessionState.Snapshot?
    let palette: SharedThemePalette
}

struct FlowScopeProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlowScopeEntry {
        FlowScopeEntry(date: Date(), stats: .placeholder, live: nil, palette: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlowScopeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlowScopeEntry>) -> Void) {
        let entry = currentEntry()
        let minutes = entry.live?.isRunning == true ? 5 : 20
        let next = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date().addingTimeInterval(1200)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> FlowScopeEntry {
        FlowScopeEntry(
            date: Date(),
            stats: SharedStats.read(),
            live: LiveSessionState.read(),
            palette: SharedTheme.read()
        )
    }
}

// MARK: - Entry View

struct FlowScopeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: FlowScopeEntry

    private var p: SharedThemePalette { entry.palette }

    var body: some View {
        switch family {
        case .accessoryCircular:   circularView
        case .accessoryRectangular: rectangularView
        case .accessoryInline:      inlineView
        case .systemMedium:         mediumView
        default:                    smallView
        }
    }

    // MARK: Home — Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let live = entry.live {
                Text(live.name)
                    .font(.caption.bold())
                    .foregroundStyle(p.textPrimary)
                    .lineLimit(1)
                timerText(live, size: 26)
                Spacer(minLength: 0)
                MoodButtonsRow(compact: true)
            } else {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(p.primary)
                Spacer(minLength: 0)
                Text("\(entry.stats.todayMinutes)m")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(p.accentGradient)
                Text("Today · \(entry.stats.todaySessionCount) sessions")
                    .font(.caption2)
                    .foregroundStyle(p.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { p.backgroundGradient }
    }

    // MARK: Home — Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            if let live = entry.live {
                VStack(alignment: .leading, spacing: 6) {
                    Text(live.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(p.textPrimary)
                        .lineLimit(1)
                    Text(live.category)
                        .font(.caption2)
                        .foregroundStyle(p.textSecondary)
                    timerText(live, size: 30)
                    Text("\(live.moodCount) moods logged")
                        .font(.caption2)
                        .foregroundStyle(p.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("How do you feel?")
                        .font(.caption2)
                        .foregroundStyle(p.textSecondary)
                    MoodButtonsRow()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(p.primary)
                    Text("\(entry.stats.todayMinutes)m")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(p.accentGradient)
                    Text("Today · \(entry.stats.todaySessionCount) sessions")
                        .font(.caption2)
                        .foregroundStyle(p.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Session")
                        .font(.caption2)
                        .foregroundStyle(p.textSecondary)
                    Text(entry.stats.lastSessionName)
                        .font(.subheadline.bold())
                        .foregroundStyle(p.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                    Text(entry.stats.lastSessionCategory)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(p.primary.opacity(0.22))
                        .foregroundStyle(p.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { p.backgroundGradient }
    }

    // MARK: Lock Screen

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "timer").font(.caption2)
                if let live = entry.live, live.isRunning {
                    LiveTimerText(range: live.timerRange, pauseTime: live.pauseTime,
                                  font: .system(.caption2, design: .rounded, weight: .bold))
                } else {
                    Text("\(entry.stats.todayMinutes)m")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
            }
        }
        .accessibilityLabel("FlowScope focus time")
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
            VStack(alignment: .leading, spacing: 1) {
                if let live = entry.live {
                    Text(live.name).font(.headline).lineLimit(1)
                    if live.isRunning {
                        LiveTimerText(range: live.timerRange, pauseTime: live.pauseTime, font: .caption2)
                    } else {
                        Text("Paused").font(.caption2)
                    }
                } else {
                    Text("\(entry.stats.todayMinutes)m today").font(.headline)
                    Text("\(entry.stats.todaySessionCount) sessions").font(.caption2)
                }
            }
            if entry.live != nil {
                Spacer()
                MoodButtonsRow(compact: true)
            }
        }
    }

    private var inlineView: some View {
        Group {
            if let live = entry.live, live.isRunning {
                Label { LiveTimerText(range: live.timerRange, pauseTime: live.pauseTime, font: .caption2) } icon: { Image(systemName: "timer") }
            } else {
                Label("\(entry.stats.todayMinutes)m today", systemImage: "timer")
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func timerText(_ live: LiveSessionState.Snapshot, size: CGFloat) -> some View {
        if live.isRunning {
            LiveTimerText(range: live.timerRange, pauseTime: live.pauseTime,
                          font: .system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(p.accentGradient)
        } else {
            Text("Paused")
                .font(.system(size: size * 0.8, weight: .bold, design: .rounded))
                .foregroundStyle(p.textSecondary)
        }
    }
}

// MARK: - Widget

struct FlowScopeWidget: Widget {
    let kind: String = "mtk.FlowScope.FlowScopeStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowScopeProvider()) { entry in
            FlowScopeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FlowScope")
        .description("Live session timer with quick mood logging, themed to match the app.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

#Preview(as: .systemMedium) {
    FlowScopeWidget()
} timeline: {
    FlowScopeEntry(
        date: .now,
        stats: .placeholder,
        live: LiveSessionState.Snapshot(
            sessionID: UUID(), name: "Deep Work", category: "Coding",
            sessionStart: .now.addingTimeInterval(-620), accumulated: 0,
            runningSince: .now.addingTimeInterval(-620), moods: []
        ),
        palette: .fallback
    )
}
