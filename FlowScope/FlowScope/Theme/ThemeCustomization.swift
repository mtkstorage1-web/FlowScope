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

    /// Explicit color picks, as "#RRGGBB". These sit on top of the sliders, so
    /// you can nudge the whole palette *and* pin one exact color.
    var primaryHex: String?
    var secondaryHex: String?
    var backgroundHex: String?

    static let none = ThemeCustomization()
    var isCustomized: Bool { self != .none }

    /// True when the hue/saturation/brightness sliders are off their defaults.
    var hasGlobalAdjustment: Bool {
        hueShift != 0 || saturation != 1 || brightness != 1
    }
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
        // Screens that only observe ThemeManager (the timer, the log, the
        // widgets) would otherwise keep the old palette until the next theme
        // switch.
        ThemeManager.shared.themeCustomizationDidChange()
    }
}

// MARK: - Color transform

extension Color {
    /// Shifts hue and scales saturation/brightness, preserving alpha.
    /// This is what lets one theme ship in any color family.
    func adjusted(hueShift: Double, saturation satScale: Double, brightness brightScale: Double) -> Color {
        guard hueShift != 0 || satScale != 1 || brightScale != 1 else { return self }

        guard let (h, s, b, a) = hsbaComponents() else { return self }

        // Greys have no meaningful hue — only scale their brightness so
        // near-monochrome accents (Lava's charcoal, Neon 80s' white digits)
        // don't tint olive and lose their identity.
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

    /// Linear blend toward another color. Used to derive a background's darker
    /// bottom stop and its lifted surface from a single picked color — plain
    /// brightness scaling can't do that when the pick is pure black.
    func mixed(with other: Color, amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        let (r1, g1, b1, a1) = rgbaComponents()
        let (r2, g2, b2, _) = other.rgbaComponents()
        return Color(
            .sRGB,
            red: Double(r1) * (1 - t) + Double(r2) * t,
            green: Double(g1) * (1 - t) + Double(g2) * t,
            blue: Double(b1) * (1 - t) + Double(b2) * t,
            opacity: Double(a1)
        )
    }
}

// MARK: - Color delta

/// The HSB difference between two colors, reusable as a transform.
///
/// Picking a new accent shouldn't flatten the theme into one hue — it should
/// move the whole accent family by the same amount, so Flame's red→orange→yellow
/// digit ramp survives being turned blue.
struct ColorDelta {
    let hueShift: Double
    let saturationScale: Double
    let brightnessScale: Double

    init(from source: Color, to target: Color) {
        guard let (h1, s1, b1, _) = source.hsbaComponents(),
              let (h2, s2, b2, _) = target.hsbaComponents() else {
            hueShift = 0; saturationScale = 1; brightnessScale = 1
            return
        }

        var shift = (Double(h2) - Double(h1)) * 360
        if shift > 180 { shift -= 360 }
        if shift < -180 { shift += 360 }
        hueShift = shift

        // Guard against a division by ~0 when the source is grey or black.
        saturationScale = s1 > 0.02 ? min(2, Double(s2) / Double(s1)) : 1
        brightnessScale = b1 > 0.02 ? min(2, Double(b2) / Double(b1)) : 1
    }

    func apply(_ color: Color) -> Color {
        color.adjusted(hueShift: hueShift,
                       saturation: saturationScale,
                       brightness: brightnessScale)
    }
}
