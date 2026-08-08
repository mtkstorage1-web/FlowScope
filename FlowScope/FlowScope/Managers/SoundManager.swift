//
//  SoundManager.swift
//  FlowScope
//
//  Theme-aware sound design, synthesized at runtime with AVAudioEngine —
//  no audio files to ship, and every cue can be tuned per theme.
//
//  Sounds duck under other audio and respect the silent switch (ambient
//  category), so starting a session never interrupts the user's music.
//

import AVFoundation
import OSLog

private let log = Logger(subsystem: "mtk.FlowScope", category: "Sound")

enum SoundCue {
    case sessionStart
    case sessionPause
    case sessionResume
    case sessionEnd
    case moodLogged
    case cycleComplete
    case themeSwitch
}

/// Per-theme sonic character, so Flame glows warm and Cyberpunk buzzes retro.
enum SoundProfile: String, CaseIterable, Identifiable, Codable {
    case crystalline, warm, electric, retro, cosmic
    var id: String { rawValue }

    var label: String {
        switch self {
        case .crystalline: return "Crystalline"
        case .warm: return "Warm"
        case .electric: return "Electric"
        case .retro: return "Retro"
        case .cosmic: return "Cosmic"
        }
    }

    /// Base frequencies (Hz) for a pleasant interval in this profile.
    var rootFrequency: Double {
        switch self {
        case .crystalline: return 880
        case .warm: return 392
        case .electric: return 660
        case .retro: return 523
        case .cosmic: return 466
        }
    }

    /// Harmonic weights — how bright/complex the timbre is.
    var harmonics: [Double] {
        switch self {
        case .crystalline: return [1.0, 0.35, 0.18, 0.09]
        case .warm:        return [1.0, 0.5, 0.12]
        case .electric:    return [1.0, 0.7, 0.5, 0.35, 0.2]
        case .retro:       return [1.0, 0.0, 0.6, 0.0, 0.35]   // hollow, square-ish
        case .cosmic:      return [1.0, 0.25, 0.4, 0.15, 0.08]
        }
    }

    static func matching(_ theme: AppTheme) -> SoundProfile {
        switch theme {
        case .flame, .lava, .redHood:   return .warm
        case .cyberpunk, .neon80s:      return .retro
        case .superman:                 return .cosmic
        case .batman, .deathstroke:     return .crystalline
        case .nightwing:                return .electric
        }
    }
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isConfigured = false

    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

    private init() {}

    // MARK: Engine lifecycle

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        do {
            #if os(iOS)
            // .ambient => obeys the ring/silent switch and mixes with music.
            // macOS has no audio session to configure; AVAudioEngine mixes by default.
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try engine.start()
            player.play()
            isConfigured = true
        } catch {
            log.error("Audio unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Public API

    func play(_ cue: SoundCue, theme: AppTheme) {
        guard AppSettings.shared.soundEnabled else { return }
        let profile = SoundProfile.matching(theme)
        let volume = Float(AppSettings.shared.soundVolume)
        guard volume > 0.01 else { return }

        configureIfNeeded()
        guard isConfigured else { return }

        let notes = notes(for: cue, profile: profile)
        guard let buffer = render(notes: notes, profile: profile, volume: volume) else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    // MARK: Cue design

    /// (frequency multiplier, start time, duration) per partial of the cue.
    private func notes(for cue: SoundCue, profile: SoundProfile) -> [(Double, Double, Double)] {
        switch cue {
        case .sessionStart:                     // rising perfect fifth
            return [(1.0, 0.0, 0.18), (1.5, 0.09, 0.26)]
        case .sessionResume:
            return [(1.0, 0.0, 0.14), (1.25, 0.07, 0.2)]
        case .sessionPause:                     // falling step
            return [(1.0, 0.0, 0.14), (0.84, 0.07, 0.2)]
        case .sessionEnd:                       // descending resolve
            return [(1.5, 0.0, 0.16), (1.25, 0.1, 0.18), (1.0, 0.2, 0.42)]
        case .moodLogged:                       // short blip
            return [(2.0, 0.0, 0.09)]
        case .cycleComplete:                    // triumphant triad
            return [(1.0, 0.0, 0.5), (1.25, 0.06, 0.46), (1.5, 0.12, 0.5), (2.0, 0.18, 0.55)]
        case .themeSwitch:                      // quick sweep
            return [(1.33, 0.0, 0.1), (2.0, 0.05, 0.16)]
        }
    }

    /// Additive synthesis with an exponential decay envelope + soft stereo spread.
    private func render(notes: [(Double, Double, Double)], profile: SoundProfile, volume: Float) -> AVAudioPCMBuffer? {
        let total = (notes.map { $0.1 + $0.2 }.max() ?? 0.3) + 0.05
        let frames = AVAudioFrameCount(total * sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames

        guard let left = buffer.floatChannelData?[0],
              let right = buffer.floatChannelData?[1] else { return nil }

        for frame in 0..<Int(frames) { left[frame] = 0; right[frame] = 0 }

        let harmonics = profile.harmonics
        let harmonicSum = harmonics.reduce(0, +)

        for (multiplier, start, duration) in notes {
            let frequency = profile.rootFrequency * multiplier
            let startFrame = Int(start * sampleRate)
            let noteFrames = Int(duration * sampleRate)

            for i in 0..<noteFrames {
                let frame = startFrame + i
                guard frame < Int(frames) else { break }

                let progress = Double(i) / Double(noteFrames)
                // Fast attack, exponential decay — reads as a struck/plucked tone.
                let attack = min(1, progress / 0.02)
                let envelope = attack * exp(-4.5 * progress)

                var sample = 0.0
                let phase = 2 * Double.pi * frequency * Double(i) / sampleRate
                for (index, weight) in harmonics.enumerated() where weight > 0 {
                    sample += weight * sin(phase * Double(index + 1))
                }
                sample = sample / harmonicSum * envelope * 0.22

                // Slight stereo widening per partial.
                let pan = (multiplier.truncatingRemainder(dividingBy: 1) - 0.5) * 0.3
                left[frame]  += Float(sample * (1 - pan)) * volume
                right[frame] += Float(sample * (1 + pan)) * volume
            }
        }

        // Soft-clip so stacked partials never crackle.
        for frame in 0..<Int(frames) {
            left[frame] = tanhf(left[frame])
            right[frame] = tanhf(right[frame])
        }
        return buffer
    }
}
