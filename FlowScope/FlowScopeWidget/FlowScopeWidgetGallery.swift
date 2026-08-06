//
//  FlowScopeWidgetGallery.swift
//  FlowScopeWidget
//
//  Five additional themed widgets beyond the main live-session widget:
//  Streak, Mood Trend, Weekly, Quick Start and Categories.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared timeline plumbing

struct GalleryEntry: TimelineEntry {
    let date: Date
    let stats: SharedStats.Snapshot
    let live: LiveSessionState.Snapshot?
    let palette: SharedThemePalette
}

struct GalleryProvider: TimelineProvider {
    func placeholder(in context: Context) -> GalleryEntry {
        GalleryEntry(date: .now, stats: .sample, live: nil, palette: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (GalleryEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GalleryEntry>) -> Void) {
        let e = entry()
        let mins = e.live?.isRunning == true ? 5 : 20
        let next = Calendar.current.date(byAdding: .minute, value: mins, to: .now) ?? .now.addingTimeInterval(1200)
        completion(Timeline(entries: [e], policy: .after(next)))
    }

    private func entry() -> GalleryEntry {
        GalleryEntry(date: .now, stats: SharedStats.read(), live: LiveSessionState.read(), palette: SharedTheme.read())
    }
}

// MARK: - 1. Streak Widget

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mtk.FlowScope.StreakWidget", provider: GalleryProvider()) { entry in
            StreakView(entry: entry)
        }
        .configurationDisplayName("Focus Streak")
        .description("Your consecutive days of focus, themed to match the app.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

struct StreakView: View {
    @Environment(\.widgetFamily) var family
    let entry: GalleryEntry
    private var p: SharedThemePalette { entry.palette }
    private var s: SharedStats.Snapshot { entry.stats }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Image(systemName: "flame.fill").font(.caption2)
                    Text("\(s.streakDays)").font(.system(.title3, design: .rounded, weight: .bold))
                }
            }
            .accessibilityLabel("\(s.streakDays) day focus streak")
        case .accessoryInline:
            Label("\(s.streakDays)-day streak", systemImage: "flame.fill")
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(p.accentGradient)
                Spacer(minLength: 0)
                Text("\(s.streakDays)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(p.accentGradient)
                Text(s.streakDays == 1 ? "day streak" : "day streak")
                    .font(.caption2)
                    .foregroundStyle(p.textSecondary)
                Text("\(s.todayMinutes)m today")
                    .font(.caption2.bold())
                    .foregroundStyle(p.textPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .themedWidgetBackground(p)
        }
    }
}

// MARK: - 2. Mood Trend Widget

struct MoodTrendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mtk.FlowScope.MoodWidget", provider: GalleryProvider()) { entry in
            MoodTrendView(entry: entry)
        }
        .configurationDisplayName("Mood Trend")
        .description("How your satisfaction has been trending, with one-tap logging.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct MoodTrendView: View {
    @Environment(\.widgetFamily) var family
    let entry: GalleryEntry
    private var p: SharedThemePalette { entry.palette }
    private var s: SharedStats.Snapshot { entry.stats }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Avg mood \(s.averageMood)%").font(.headline)
                MoodSparkline(values: s.recentMoods, palette: p).frame(height: 16)
            }
        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Mood").font(.caption2).foregroundStyle(p.textSecondary)
                    Text("\(s.averageMood)%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(MoodPalette.color(s.averageMood))
                    MoodSparkline(values: s.recentMoods, palette: p).frame(height: 28)
                }
                Spacer()
                VStack(spacing: 8) {
                    Text("Log now").font(.caption2).foregroundStyle(p.textSecondary)
                    MoodButtonsRow()
                }
            }
            .padding()
            .themedWidgetBackground(p)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("Avg Mood").font(.caption2).foregroundStyle(p.textSecondary)
                Text("\(s.averageMood)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(MoodPalette.color(s.averageMood))
                MoodSparkline(values: s.recentMoods, palette: p).frame(height: 22)
                Spacer(minLength: 0)
                MoodButtonsRow(compact: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .themedWidgetBackground(p)
        }
    }
}

// MARK: - 3. Weekly Widget

struct WeeklyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mtk.FlowScope.WeeklyWidget", provider: GalleryProvider()) { entry in
            WeeklyView(entry: entry)
        }
        .configurationDisplayName("Weekly Focus")
        .description("Your last 7 days of focus time.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WeeklyView: View {
    let entry: GalleryEntry
    private var p: SharedThemePalette { entry.palette }
    private var s: SharedStats.Snapshot { entry.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week").font(.caption2).foregroundStyle(p.textSecondary)
                    Text("\(s.weeklyTotal)m")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(p.accentGradient)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Label("\(s.streakDays)", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(p.primary)
                    Text("streak").font(.caption2).foregroundStyle(p.textSecondary)
                }
            }
            WeeklyBars(minutes: s.weeklyMinutes, palette: p, barHeight: 52)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding()
        .themedWidgetBackground(p)
    }
}

// MARK: - 4. Quick Start Widget

struct QuickStartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mtk.FlowScope.QuickStartWidget", provider: GalleryProvider()) { entry in
            QuickStartView(entry: entry)
        }
        .configurationDisplayName("Quick Start")
        .description("Start a focus session in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickStartView: View {
    @Environment(\.widgetFamily) var family
    let entry: GalleryEntry
    private var p: SharedThemePalette { entry.palette }

    private let categories = ["Coding", "Study", "Reading", "Creative"]

    var body: some View {
        if let live = entry.live {
            // A session is already running — show it rather than a start button.
            VStack(alignment: .leading, spacing: 6) {
                Text(live.name).font(.caption.bold()).foregroundStyle(p.textPrimary).lineLimit(1)
                LiveTimerText(range: live.timerRange, pauseTime: live.pauseTime,
                              font: .system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(p.accentGradient)
                Spacer(minLength: 0)
                MoodButtonsRow(compact: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .themedWidgetBackground(p)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Start").font(.caption2).foregroundStyle(p.textSecondary)
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(visibleCategories, id: \.self) { category in
                        Button(intent: QuickStartIntent(category: category)) {
                            Text(category)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: p.cornerRadius * 0.6, style: .continuous)
                                        .fill(p.primary.opacity(0.22))
                                )
                                .foregroundStyle(p.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start \(category) session")
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .themedWidgetBackground(p)
        }
    }

    private var visibleCategories: [String] {
        family == .systemSmall ? Array(categories.prefix(2)) : categories
    }

    private var gridColumns: [GridItem] {
        family == .systemSmall
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }
}

// MARK: - 5. Categories Widget

struct CategoriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mtk.FlowScope.CategoriesWidget", provider: GalleryProvider()) { entry in
            CategoriesView(entry: entry)
        }
        .configurationDisplayName("Top Categories")
        .description("Where your focus time went today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CategoriesView: View {
    let entry: GalleryEntry
    private var p: SharedThemePalette { entry.palette }
    private var s: SharedStats.Snapshot { entry.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today").font(.caption2).foregroundStyle(p.textSecondary)

            if s.topCategories.isEmpty {
                Spacer()
                Text("No sessions yet")
                    .font(.caption)
                    .foregroundStyle(p.textSecondary)
                Spacer()
            } else {
                ForEach(s.topCategories, id: \.self) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.name)
                                .font(.caption.bold())
                                .foregroundStyle(p.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.minutes)m")
                                .font(.caption2)
                                .foregroundStyle(p.textSecondary)
                        }
                        GeometryReader { geo in
                            let ratio = CGFloat(item.minutes) / CGFloat(max(s.todayMinutes, 1))
                            ZStack(alignment: .leading) {
                                Capsule().fill(p.primary.opacity(0.15))
                                Capsule().fill(p.accentGradient)
                                    .frame(width: max(4, geo.size.width * ratio))
                            }
                        }
                        .frame(height: 5)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .themedWidgetBackground(p)
    }
}

// MARK: - Previews

#Preview("Streak", as: .systemSmall) {
    StreakWidget()
} timeline: {
    GalleryEntry(date: .now, stats: .sample, live: nil, palette: .fallback)
}

#Preview("Weekly", as: .systemMedium) {
    WeeklyWidget()
} timeline: {
    GalleryEntry(date: .now, stats: .sample, live: nil, palette: .fallback)
}
