//
//  WidgetTheming.swift
//  FlowScopeWidget
//
//  Shared themed building blocks for every FlowScope widget and for the
//  Live Activity, so all surfaces track the app's active theme.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Live Timer

/// Self-updating timer text. `Text(timerInterval:)` is the API WidgetKit
/// actually re-renders on its own — `Text(_:style:.timer)` freezes inside a
/// timeline entry, which is why widgets looked static.
struct LiveTimerText: View {
    let range: ClosedRange<Date>
    let pauseTime: Date?
    var font: Font = .system(size: 28, weight: .bold, design: .rounded)

    var body: some View {
        Text(timerInterval: range, pauseTime: pauseTime, countsDown: false)
            .font(font)
            .monospacedDigit()
            .minimumScaleFactor(0.4)
            .lineLimit(1)
    }
}

// MARK: - Mood color ramp

enum MoodPalette {
    /// Red → orange → yellow → green, matching the in-app satisfaction slider.
    static func color(_ value: Int) -> Color {
        switch value {
        case ..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        default: return .green
        }
    }
}

// MARK: - Quick mood buttons

struct MoodButtonsRow: View {
    var compact: Bool = false
    var tint: Color? = nil

    var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            button(20, .red, "face.dashed", "Log low satisfaction")
            button(60, .yellow, "face.smiling", "Log medium satisfaction")
            button(95, .green, "face.smiling.inverse", "Log high satisfaction")
        }
    }

    private func button(_ level: Int, _ color: Color, _ symbol: String, _ label: String) -> some View {
        Button(intent: LogMoodIntent(level: level)) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 11 : 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: compact ? 22 : 30, height: compact ? 22 : 30)
                .background(Circle().fill(tint ?? color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Sparkline

/// Tiny mood trend line drawn with native Canvas.
struct MoodSparkline: View {
    let values: [Int]
    let palette: SharedThemePalette

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (i, value) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height * (1 - CGFloat(value) / 100)
                i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [palette.primary, palette.secondary]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )

            // Dot on the newest value.
            if let last = values.last {
                let x = size.width
                let y = size.height * (1 - CGFloat(last) / 100)
                let r: CGFloat = 3
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(MoodPalette.color(last))
                )
            }
        }
    }
}

// MARK: - Weekly bars

struct WeeklyBars: View {
    let minutes: [Int]
    let palette: SharedThemePalette
    var barHeight: CGFloat = 44

    private var labels: [String] { ["M", "T", "W", "T", "F", "S", "S"] }

    var body: some View {
        let best = max(minutes.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(minutes.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(index == minutes.count - 1 ? AnyShapeStyle(palette.accentGradient)
                                                         : AnyShapeStyle(palette.primary.opacity(0.35)))
                        .frame(height: max(3, barHeight * CGFloat(value) / CGFloat(best)))
                    Text(labels[index % labels.count])
                        .font(.system(size: 8))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: barHeight + 14, alignment: .bottom)
        .accessibilityLabel("Focus minutes for the last 7 days")
    }
}

// MARK: - Ring

struct WidgetRing: View {
    let progress: Double
    let palette: SharedThemePalette
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.primary.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(colors: [palette.primary, palette.secondary, palette.primary], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Background helper

extension View {
    /// Themed widget container background.
    func themedWidgetBackground(_ palette: SharedThemePalette) -> some View {
        containerBackground(for: .widget) { palette.backgroundGradient }
    }
}
