//
//  ThemeCustomization.swift
//  FlowScope
//
//  Per-theme user overrides. Lets you recolor any theme without leaving its
//  identity — e.g. Flame at +210° hue becomes blue fire, keeping the embers,
//  the heavy digits and the breathing glow.
//

import SwiftUI
import Combine

// MARK: - Ring design

/// The shape language of the progress ring. Deliberately no dashed/dotted
/// options — those read as cheap at this size.
enum RingDesign: String, CaseIterable, Identifiable, Codable {
    case solidGlow      // thick continuous arc with bloom
    case neonTube       // thick arc with a bright inner highlight
    case cometTrail     // arc fading to a bright leading head
    case doubleOrbit    // two counter-rotating concentric arcs
    case segmentedArc   // chunky gauge segments (premium, not dotty)
    case taperedArc     // thin → thick sweep
    case hairline       // ultra-thin, minimal
    case pulseRing      // solid arc that breathes
    case radarSweep     // solid arc + orbiting head dot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solidGlow:    return "Solid Glow"
        case .neonTube:     return "Neon Tube"
        case .cometTrail:   return "Comet"
        case .doubleOrbit:  return "Orbit"
        case .segmentedArc: return "Segments"
        case .taperedArc:   return "Tapered"
        case .hairline:     return "Hairline"
        case .pulseRing:    return "Pulse"
        case .radarSweep:   return "Radar"
        }
    }
}

// MARK: - Customization

struct ThemeCustomization: Codable, Equatable {
    /// Degrees, -180...180. This is what turns red fire into blue fire.
    var hueShift: Double = 0
    /// Multiplier, 0...1.6.
    var saturation: Double = 1
    /// Multiplier, 0.6...1.5.
    var brightness: Double = 1
    /// Overrides the theme's default ring design when set.
    var ringDesign: RingDesign?

    static let none = ThemeCustomization()
    var isCustomized: Bool { self != .none }
}

// MARK: - Store

final class ThemeCustomizationStore: ObservableObject {
    static let shared = ThemeCustomizationStore()

    @AppStorage("theme.customizations") private var raw: Data = Data()
    @Published private var cache: [String: ThemeCustomization] = [:]

    private init() {
        if let decoded = try? JSONDecoder().decode([String: ThemeCustomization].self, from: raw) {
            cache = decoded
        }
    }

    func customization(for theme: AppTheme) -> ThemeCustomization {
        cache[theme.rawValue] ?? .none
    }

    func set(_ customization: ThemeCustomization, for theme: AppTheme) {
        cache[theme.rawValue] = customization
        persist()
    }

    func reset(_ theme: AppTheme) {
        cache.removeValue(forKey: theme.rawValue)
        persist()
    }

    func resetAll() {
        cache.removeAll()
        persist()
    }

    private func persist() {
        objectWillChange.send()
        raw = (try? JSONEncoder().encode(cache)) ?? Data()
    }
}

// MARK: - Color transform

extension Color {
    /// Shifts hue and scales saturation/brightness, preserving alpha.
    /// This is what lets one theme ship in any color family.
    func adjusted(hueShift: Double, saturation satScale: Double, brightness brightScale: Double) -> Color {
        guard hueShift != 0 || satScale != 1 || brightScale != 1 else { return self }

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }

        // Greys have no meaningful hue — only scale their brightness so
        // monochrome themes (Dark Matter) don't turn muddy.
        // 0.15 covers Dark Matter's #9CA3AF (s ~0.09), which would otherwise
        // tint olive and destroy the monochrome identity.
        if s < 0.15 {
            return Color(hue: Double(h),
                         saturation: Double(s),
                         brightness: min(1, Double(b) * brightScale),
                         opacity: Double(a))
        }

        var hue = Double(h) + hueShift / 360
        hue = hue.truncatingRemainder(dividingBy: 1)
        if hue < 0 { hue += 1 }

        return Color(hue: hue,
                     saturation: min(1, Double(s) * satScale),
                     brightness: min(1, Double(b) * brightScale),
                     opacity: Double(a))
    }

    func adjusted(_ customization: ThemeCustomization) -> Color {
        adjusted(hueShift: customization.hueShift,
                 saturation: customization.saturation,
                 brightness: customization.brightness)
    }
}
