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

    /// True once a session exists — running or paused with time on the clock.
    private var hasActiveSession: Bool {
        sessionManager.isRunning || sessionManager.elapsedTime > 0
    }

    /// Driven by the Settings switch, and only while a session is live — the
    /// idle screen still needs its start button.
    private var minimal: Bool {
        settings.minimalSession && hasActiveSession
    }

    /// The emblem only steps back when something is actually drawn on top of
    /// it — which now means the countdown alone. With that switched off (the
    /// default) the ring centre is empty and the emblem has no reason to fade.
    private var emblemStrength: Double {
        let overlapped = hasActiveSession && !minimal && settings.showGoalTimer
        return overlapped ? 0.34 : 0.95
    }

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

                // The banners survive minimal mode — they carry the only way to
                // discard a recovered session and the only hint that Live
                // Activities are switched off system-wide.
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

                    // Character themes fill the ring with their emblem. It
                    // drops back to a watermark once a session starts so the
                    // cycle countdown on top of it stays readable — unless the
                    // chrome is hidden, in which case nothing overlaps it.
                    if let emblem = config.emblem {
                        ThemeEmblemView(
                            emblem: emblem,
                            config: config,
                            size: minimal ? 210 : 172,
                            strength: emblemStrength,
                            isLive: sessionManager.isRunning
                        )
                        .animation(.easeInOut(duration: 0.45), value: emblemStrength)
                        .animation(.easeInOut(duration: 0.45), value: minimal)
                    }

                    if !minimal { ringCenter }
                }
                .opacity(settings.ringMode == .hidden ? 0 : 1)
                .frame(height: settings.ringMode == .hidden ? 0 : nil)
                .padding(.vertical, 12)

                if !minimal { sessionCounters }

                logMoodButton

                if !minimal {
                    controlButtons
                        .padding(.bottom, 40)
                }

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
        .platformStatusBarHidden(settings.hideStatusBar)
        .sheet(isPresented: $showSetupSheet) {
            SessionSetupView()
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showMoodDial) {
            MoodDialView()
                .platformSheetSizing()
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
                    PlatformSettings.openAppSettings()
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
        if hasActiveSession {
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

    /// Countdown only. The cycle/log counters used to live here too, but inside
    /// the ring they sat right on top of the emblem.
    @ViewBuilder
    private var ringCenter: some View {
        if hasActiveSession && settings.showGoalTimer {
            VStack(spacing: 3) {
                Text(goalCountdown)
                    .font(.system(.title2, design: config.fontDesign).weight(.semibold))
                    .foregroundStyle(goalReached ? config.secondary : config.primary)
                    .monospacedDigit()
                Text(goalCountdownLabel)
                    .font(.system(.caption2, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(goalCountdown) \(goalCountdownLabel)")
        }
    }

    // MARK: - Session Counters

    /// Cycles completed and moods logged, parked below the ring so the emblem
    /// stays unobstructed.
    @ViewBuilder
    private var sessionCounters: some View {
        if hasActiveSession {
            HStack(spacing: 16) {
                Label("\(sessionManager.completedCycles)", systemImage: "repeat")
                Label("\(sessionManager.moodLogs.count)", systemImage: "chart.bar.fill")
            }
            .font(.system(.footnote, design: config.fontDesign))
            .foregroundStyle(config.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(config.surface))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(sessionManager.completedCycles) cycles done, \(sessionManager.moodLogs.count) moods logged")
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

    /// Minutes:seconds remaining in the current cycle.
    private var cycleRemaining: String {
        clock(sessionManager.timeLeftInCycle)
    }

    /// Seconds left of the session goal, floored at zero.
    private var goalRemaining: TimeInterval {
        max(0, settings.goalLength - sessionManager.elapsedTime)
    }

    private var goalReached: Bool {
        settings.ringMode == .sessionGoal && goalRemaining == 0
    }

    /// The readout tracks whatever the ring is measuring. Showing cycle time
    /// while the ring fills over the goal made the two disagree on screen.
    private var goalCountdown: String {
        switch settings.ringMode {
        case .sessionGoal: return goalReached ? "Goal met" : clock(goalRemaining)
        case .cycle, .hidden: return cycleRemaining
        }
    }

    private var goalCountdownLabel: String {
        switch settings.ringMode {
        case .sessionGoal: return goalReached ? "\(settings.goalMinutes) min done" : "left of goal"
        case .cycle, .hidden: return "left in cycle"
        }
    }

    private func clock(_ interval: TimeInterval) -> String {
        let left = Int(interval)
        return String(format: "%d:%02d", left / 60, left % 60)
    }
}

#Preview {
    TimerView()
        .environmentObject(SessionManager())
        .environmentObject(ThemeManager.shared)
}
