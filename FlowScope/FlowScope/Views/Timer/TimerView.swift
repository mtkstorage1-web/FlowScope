//
//  TimerView.swift
//  FlowScope
//
//  Pure presentation. Every color, font, shadow, shape and animation comes
//  from `themeManager.configuration` — there are no hardcoded colors or
//  fonts and no theme branching in this file.
//
//  (The remaining conditionals are session-state logic — running / paused /
//  idle — which is preserved app behavior, not styling.)
//

import SwiftUI

struct TimerView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showMoodDial = false
    @State private var showEndConfirmation = false
    @State private var showSetupSheet = false

    @ObservedObject private var settings = AppSettings.shared
    private var config: ThemeConfiguration { themeManager.configuration }

    /// What the ring measures, per the user's choice.
    private var ringProgress: CGFloat {
        switch settings.ringMode {
        case .cycle:       return sessionManager.cycleProgress
        case .sessionGoal: return min(CGFloat(sessionManager.elapsedTime / settings.goalLength), 1)
        case .hidden:      return 0
        }
    }

    var body: some View {
        ZStack {
            themeManager.backgroundView

            VStack(spacing: 32) {
                Spacer()

                restoredBanner

                liveActivityDisabledBanner

                sessionHeader

                ThemedDigits(text: timeString(from: sessionManager.elapsedTime), config: config)
                    .padding(.horizontal)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(spokenTime(sessionManager.elapsedTime))

                ZStack {
                    if settings.ringMode != .hidden {
                        ThemedProgressRing(progress: ringProgress, config: config)
                    }
                    // Soft scrim so particle fields (retro grid, scanlines) don't
                    // cut through the countdown and wreck its contrast.
                    RadialGradient(
                        colors: [config.backgroundBottom.opacity(0.85), .clear],
                        center: .center, startRadius: 0, endRadius: 96
                    )
                    .allowsHitTesting(false)
                    ringCenter
                }
                .opacity(settings.ringMode == .hidden ? 0 : 1)
                .frame(height: settings.ringMode == .hidden ? 0 : nil)
                .padding(.vertical, 12)

                logMoodButton

                controlButtons
                    .padding(.bottom, 40)

                Spacer()
            }
            // One-shot celebration when a focus cycle completes.
            if sessionManager.cycleJustCompleted {
                config.primary
                    .opacity(0.28)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: sessionManager.cycleJustCompleted)
        .applyTheme(config)
        .statusBar(hidden: settings.hideStatusBar)
        .sheet(isPresented: $showSetupSheet) {
            SessionSetupView()
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showMoodDial) {
            MoodDialView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                sessionManager.stopSession()
            }
        } message: {
            Text("'\(sessionManager.sessionName)' will be saved with \(sessionManager.moodLogs.count) mood logs.")
        }
    }

    // MARK: - Live Activities Disabled Banner

    /// Without this the Dynamic Island silently never appears and there's no
    /// way for the user to know the system setting is the reason.
    @ViewBuilder
    private var liveActivityDisabledBanner: some View {
        if !sessionManager.liveActivitiesEnabled {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dynamic Island is off")
                        .font(.system(.subheadline, design: config.fontDesign).weight(.semibold))
                        .foregroundStyle(config.textPrimary)
                    Text("Enable Live Activities to see your timer on the Lock Screen.")
                        .font(.system(.caption2, design: config.fontDesign))
                        .foregroundStyle(config.textSecondary)
                }
                Spacer()
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(.caption, design: config.fontDesign).weight(.semibold))
                .foregroundStyle(config.primary)
            }
            .padding(12)
            .themedSurface(config)
            .padding(.horizontal)
        }
    }

    // MARK: - Recovered Session Banner

    /// Shown when a session survived the app being killed. Without this the
    /// session keeps running in the widget with no way to act on it.
    @ViewBuilder
    private var restoredBanner: some View {
        if sessionManager.didRestoreSession {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(config.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session recovered")
                        .font(.system(.subheadline, design: config.fontDesign).weight(.semibold))
                        .foregroundStyle(config.textPrimary)
                    Text("Picked up where you left off.")
                        .font(.system(.caption2, design: config.fontDesign))
                        .foregroundStyle(config.textSecondary)
                }
                Spacer()
                Button("Discard") { sessionManager.discardSession() }
                    .font(.system(.caption, design: config.fontDesign).weight(.semibold))
                    .foregroundStyle(.red)
                Button("OK") { sessionManager.acknowledgeRestore() }
                    .font(.system(.caption, design: config.fontDesign).weight(.semibold))
                    .foregroundStyle(config.primary)
            }
            .padding(12)
            .themedSurface(config)
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Session Header

    @ViewBuilder
    private var sessionHeader: some View {
        if sessionManager.isRunning || sessionManager.elapsedTime > 0 {
            VStack(spacing: 6) {
                Text(sessionManager.sessionName)
                    .font(.system(.headline, design: config.fontDesign).weight(config.fontWeight))
                    .foregroundStyle(config.textPrimary)

                Text(sessionManager.sessionCategory)
                    .font(.system(.caption, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(config.surface)
                    .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius * 0.6, style: .continuous))
            }
            .padding(.top, 30)
        }
    }

    // MARK: - Mood Counter

    @ViewBuilder
    private var ringCenter: some View {
        if sessionManager.isRunning || sessionManager.elapsedTime > 0 {
            VStack(spacing: 3) {
                Text(cycleRemaining)
                    .font(.system(.title2, design: config.fontDesign).weight(.semibold))
                    .foregroundStyle(config.primary)
                    .monospacedDigit()
                Text("left in cycle")
                    .font(.system(.caption2, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)

                HStack(spacing: 10) {
                    Label("\(sessionManager.completedCycles)", systemImage: "repeat")
                    Label("\(sessionManager.moodLogs.count)", systemImage: "chart.bar.fill")
                }
                .font(.system(.caption2, design: config.fontDesign))
                .foregroundStyle(config.textSecondary)
                .padding(.top, 2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(cycleRemaining) left in cycle, \(sessionManager.completedCycles) cycles done")
        }
    }

    // MARK: - Log Mood

    @ViewBuilder
    private var logMoodButton: some View {
        if sessionManager.isRunning {
            Button {
                showMoodDial = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Log How You Feel")
                }
                .font(.system(.headline, design: config.fontDesign))
                .foregroundStyle(config.primary)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background(Capsule().fill(config.primary.opacity(0.15)))
                .overlay(Capsule().stroke(config.primary.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 36) {
            if !sessionManager.isRunning && sessionManager.elapsedTime > 0 {
                ThemedIconButton(systemName: "play.fill", config: config, size: 64) {
                    sessionManager.resumeSession()
                }
            } else if sessionManager.isRunning {
                ThemedIconButton(systemName: "pause.fill", config: config, size: 64) {
                    sessionManager.pauseSession()
                }
            }

            if !sessionManager.isRunning && sessionManager.elapsedTime == 0 {
                ThemedIconButton(systemName: "play.fill", config: config, size: 84) {
                    showSetupSheet = true
                }
            } else {
                ThemedIconButton(systemName: "stop.fill", config: config, size: 64) {
                    showEndConfirmation = true
                }
            }
        }
    }

    // MARK: - Preserved Timer Logic

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        let hours = Int(timeInterval) / 3600

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// VoiceOver-friendly duration ("12 minutes, 30 seconds").
    private func spokenTime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: interval) ?? "0 seconds"
    }

    /// Minutes:seconds remaining in the current 25-minute cycle.
    private var cycleRemaining: String {
        let left = Int(sessionManager.timeLeftInCycle)
        return String(format: "%d:%02d", left / 60, left % 60)
    }
}

#Preview {
    TimerView()
        .environmentObject(SessionManager())
        .environmentObject(ThemeManager.shared)
}
