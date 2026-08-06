//
//  AppSettings.swift
//  FlowScope
//
//  Single source of truth for every user-tunable preference outside of the
//  theme palette itself: effect intensity, motion, timing, feedback and
//  layout. Persisted with @AppStorage so it survives launches.
//

import SwiftUI
import Combine

// MARK: - Option types

enum EffectIntensity: String, CaseIterable, Identifiable, Codable {
    case off, subtle, balanced, intense, maximum
    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .subtle: return "Subtle"
        case .balanced: return "Balanced"
        case .intense: return "Intense"
        case .maximum: return "Max"
        }
    }

    /// Multiplies particle opacity / stroke weight.
    var opacityScale: Double {
        switch self {
        case .off: return 0
        case .subtle: return 0.5
        case .balanced: return 1.0
        case .intense: return 1.45
        case .maximum: return 1.9
        }
    }

    /// Multiplies how many particles are drawn.
    var densityScale: Double {
        switch self {
        case .off: return 0
        case .subtle: return 0.6
        case .balanced: return 1.0
        case .intense: return 1.5
        case .maximum: return 2.0
        }
    }
}

enum AnimationSpeed: String, CaseIterable, Identifiable, Codable {
    case calm, normal, fast
    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: return "Calm"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }

    var scale: Double {
        switch self {
        case .calm: return 0.55
        case .normal: return 1.0
        case .fast: return 1.7
        }
    }
}

/// What the big ring on the Focus screen measures.
enum RingMode: String, CaseIterable, Identifiable, Codable {
    case cycle, sessionGoal, hidden
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cycle: return "Focus Cycle"
        case .sessionGoal: return "Session Goal"
        case .hidden: return "Hidden"
        }
    }

    var explanation: String {
        switch self {
        case .cycle: return "Ring fills over one focus block, then resets and counts a lap."
        case .sessionGoal: return "Ring fills once over your whole target session length."
        case .hidden: return "No ring — just the timer."
        }
    }
}

// MARK: - App Settings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Visual effects
    @AppStorage("settings.effectIntensity") private var intensityRaw = EffectIntensity.balanced.rawValue
    @AppStorage("settings.animationSpeed") private var speedRaw = AnimationSpeed.normal.rawValue
    @AppStorage("settings.parallaxEnabled") var parallaxEnabled = true { didSet { objectWillChange.send() } }
    @AppStorage("settings.animatedDigits") var animatedDigits = true { didSet { objectWillChange.send() } }
    @AppStorage("settings.glowEnabled") var glowEnabled = true { didSet { objectWillChange.send() } }
    /// 0–100%. Softens the animated background so foreground UI pops.
    @AppStorage("settings.backgroundBlur") var backgroundBlur = 0.0 { didSet { objectWillChange.send() } }

    // Timing
    @AppStorage("settings.cycleMinutes") var cycleMinutes = 25 { didSet { objectWillChange.send() } }
    @AppStorage("settings.goalMinutes") var goalMinutes = 90 { didSet { objectWillChange.send() } }
    @AppStorage("settings.ringMode") private var ringModeRaw = RingMode.cycle.rawValue

    // Feedback
    @AppStorage("settings.hapticsEnabled") var hapticsEnabled = true { didSet { objectWillChange.send() } }
    @AppStorage("settings.soundEnabled") var soundEnabled = true { didSet { objectWillChange.send() } }
    @AppStorage("settings.soundVolume") var soundVolume = 0.7 { didSet { objectWillChange.send() } }
    @AppStorage("settings.cycleAlert") var cycleAlert = true { didSet { objectWillChange.send() } }

    // Layout / behavior
    @AppStorage("settings.floatingControlEnabled") var floatingControlEnabled = true { didSet { objectWillChange.send() } }
    @AppStorage("settings.keepScreenAwake") var keepScreenAwake = false { didSet { objectWillChange.send() } }
    @AppStorage("settings.liveActivityEnabled") var liveActivityEnabled = true { didSet { objectWillChange.send() } }
    @AppStorage("settings.hideStatusBar") var hideStatusBar = true { didSet { objectWillChange.send() } }

    private init() {}

    // MARK: Typed accessors

    var effectIntensity: EffectIntensity {
        get { EffectIntensity(rawValue: intensityRaw) ?? .balanced }
        set { objectWillChange.send(); intensityRaw = newValue.rawValue }
    }

    var animationSpeed: AnimationSpeed {
        get { AnimationSpeed(rawValue: speedRaw) ?? .normal }
        set { objectWillChange.send(); speedRaw = newValue.rawValue }
    }

    var ringMode: RingMode {
        get { RingMode(rawValue: ringModeRaw) ?? .cycle }
        set { objectWillChange.send(); ringModeRaw = newValue.rawValue }
    }

    var cycleLength: TimeInterval { TimeInterval(cycleMinutes * 60) }
    var goalLength: TimeInterval { TimeInterval(goalMinutes * 60) }

    /// Options offered for cycle length, in minutes.
    static let cycleOptions = [10, 15, 20, 25, 30, 45, 50, 60]
    static let goalOptions = [30, 45, 60, 90, 120, 180, 240]

    func resetAll() {
        objectWillChange.send()
        intensityRaw = EffectIntensity.balanced.rawValue
        speedRaw = AnimationSpeed.normal.rawValue
        parallaxEnabled = true
        animatedDigits = true
        glowEnabled = true
        backgroundBlur = 0
        cycleMinutes = 25
        goalMinutes = 90
        ringModeRaw = RingMode.cycle.rawValue
        hapticsEnabled = true
        soundEnabled = true
        soundVolume = 0.7
        cycleAlert = true
        floatingControlEnabled = true
        keepScreenAwake = false
        liveActivityEnabled = true
        hideStatusBar = true
    }
}
