//
//  FlowScopeWidgetLiveActivity.swift
//  FlowScopeWidget
//
//  Lock Screen + Dynamic Island presentation. Fully themed from the App
//  Group palette, with a self-updating timer and quick mood logging.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct FlowScopeWidgetLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            LockScreenView(state: context.state, palette: SharedTheme.read())
                .activityBackgroundTint(SharedTheme.read().backgroundBottom)
                .activitySystemActionForegroundColor(SharedTheme.read().primary)
        } dynamicIsland: { context in
            let p = SharedTheme.read()
            let s = context.state

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            StatusDot(isPaused: s.isPaused, palette: p)
                            Text(s.sessionName)
                                .font(.caption.bold())
                                .foregroundStyle(p.textPrimary)
                                .lineLimit(1)
                        }
                        Text(s.sessionCategory)
                            .font(.system(size: 10))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(p.primary.opacity(0.22)))
                            .foregroundStyle(p.primary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        timer(s, font: .system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(p.accentGradient)
                        HStack(spacing: 3) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(p.secondary)
                            Text("\(s.moodCount) logs")
                                .font(.system(size: 10))
                                .foregroundStyle(p.textSecondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ThemedProgressBar(
                            range: s.startDate...s.startDate.addingTimeInterval(7200),
                            isPaused: s.isPaused,
                            staticProgress: min(s.elapsedTime / 7200, 1),
                            palette: p
                        )
                        HStack {
                            Text("How do you feel?")
                                .font(.system(size: 10))
                                .foregroundStyle(p.textSecondary)
                            Spacer()
                            MoodButtonsRow(compact: true)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                StatusDot(isPaused: s.isPaused, palette: p)
            } compactTrailing: {
                timer(s, font: .system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(p.primary)
                    .frame(maxWidth: 52)
            } minimal: {
                StatusDot(isPaused: s.isPaused, palette: p)
            }
            .keylineTint(p.primary)
            .widgetURL(URL(string: "flowscope://session"))
        }
    }

    /// Self-updating timer that freezes when paused.
    @ViewBuilder
    private func timer(_ s: TimerAttributes.ContentState, font: Font) -> some View {
        let start = s.startDate
        LiveTimerText(
            range: start...start.addingTimeInterval(60 * 60 * 24),
            pauseTime: s.isPaused ? start.addingTimeInterval(s.elapsedTime) : nil,
            font: font
        )
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let state: TimerAttributes.ContentState
    let palette: SharedThemePalette

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                StatusDot(isPaused: state.isPaused, palette: palette)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.sessionName)
                        .font(.subheadline.bold())
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Text(state.sessionCategory)
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                let start = state.startDate
                LiveTimerText(
                    range: start...start.addingTimeInterval(60 * 60 * 24),
                    pauseTime: state.isPaused ? start.addingTimeInterval(state.elapsedTime) : nil,
                    font: .system(size: 30, weight: .bold, design: .rounded)
                )
                .foregroundStyle(palette.accentGradient)
                .frame(maxWidth: 130)
            }

            ThemedProgressBar(
                range: state.startDate...state.startDate.addingTimeInterval(7200),
                isPaused: state.isPaused,
                staticProgress: min(state.elapsedTime / 7200, 1),
                palette: palette
            )

            HStack {
                Label("\(state.moodCount)", systemImage: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                MoodButtonsRow()
            }
        }
        .padding(16)
    }
}

// MARK: - Pieces

private struct StatusDot: View {
    let isPaused: Bool
    let palette: SharedThemePalette

    var body: some View {
        Image(systemName: isPaused ? "pause.circle.fill" : "circle.fill")
            .font(.system(size: isPaused ? 11 : 9))
            .foregroundStyle(isPaused ? Color.orange : palette.primary)
            .shadow(color: isPaused ? .orange : palette.primary, radius: 4)
            // Continuous pulse while running — one of the few animations the
            // Live Activity renderer supports out of process.
            .symbolEffect(.pulse, options: .repeating, isActive: !isPaused)
            .accessibilityLabel(isPaused ? "Paused" : "Running")
    }
}

/// Progress that keeps filling on its own. `ProgressView(timerInterval:)` is
/// re-rendered by the system every frame, unlike a static width computed once
/// when the Live Activity content is pushed.
private struct ThemedProgressBar: View {
    let range: ClosedRange<Date>
    let isPaused: Bool
    let staticProgress: Double
    let palette: SharedThemePalette

    var body: some View {
        Group {
            if isPaused {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.primary.opacity(0.18))
                        Capsule()
                            .fill(palette.accentGradient)
                            .frame(width: max(3, geo.size.width * staticProgress))
                    }
                }
            } else {
                ProgressView(timerInterval: range, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(palette.primary)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Previews

extension TimerAttributes {
    fileprivate static var preview: TimerAttributes { TimerAttributes() }
}

extension TimerAttributes.ContentState {
    fileprivate static var running: TimerAttributes.ContentState {
        .init(elapsedTime: 930, moodCount: 3, isPaused: false,
              sessionName: "Refactor timer", sessionCategory: "Coding",
              startDate: Date().addingTimeInterval(-930))
    }
    fileprivate static var paused: TimerAttributes.ContentState {
        .init(elapsedTime: 1500, moodCount: 5, isPaused: true,
              sessionName: "Refactor timer", sessionCategory: "Coding",
              startDate: Date().addingTimeInterval(-1500))
    }
}

#Preview("Live Activity", as: .content, using: TimerAttributes.preview) {
    FlowScopeWidgetLiveActivity()
} contentStates: {
    TimerAttributes.ContentState.running
    TimerAttributes.ContentState.paused
}
