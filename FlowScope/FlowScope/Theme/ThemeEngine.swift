//
//  ThemeEngine.swift
//  FlowScope
//
//  The Dynamic Theme Engine's data layer: the AppTheme enum, the
//  ThemeConfiguration "CSS variables" struct that holds every styling
//  property, and the ThemeProvider that maps one to the other.
//
//  Views never branch on the theme — they read a ThemeConfiguration.
//

import SwiftUI

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable, Hashable {
    case flame, lightning, laser, cyberpunk, aurora
    case darkMatter, lava, neon80s, galaxy, burningEmber

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flame: return "Flame"
        case .lightning: return "Lightning"
        case .laser: return "Laser"
        case .cyberpunk: return "Cyberpunk"
        case .aurora: return "Aurora"
        case .darkMatter: return "Dark Matter"
        case .lava: return "Lava"
        case .neon80s: return "Neon 80s"
        case .galaxy: return "Galaxy"
        case .burningEmber: return "Burning Ember"
        }
    }

    var icon: String {
        switch self {
        case .flame: return "flame.fill"
        case .lightning: return "bolt.fill"
        case .laser: return "grid"
        case .cyberpunk: return "square.stack.3d.up.slash.fill"
        case .aurora: return "sparkles"
        case .darkMatter: return "moon.stars.fill"
        case .lava: return "mountain.2.fill"
        case .neon80s: return "square.grid.3x3.fill"
        case .galaxy: return "star.circle.fill"
        case .burningEmber: return "smoke.fill"
        }
    }
}

// MARK: - Style Value Types

/// A shadow layer. Themes can stack several (e.g. Cyberpunk's chromatic aberration).
struct ThemeShadow: Equatable {
    var color: Color
    var radius: CGFloat
    var x: CGFloat = 0
    var y: CGFloat = 0
}

/// Shapes a themed button can take. The switch lives in `ThemeButtonShape`,
/// never in a screen-level view.
enum ThemeButtonShapeStyle: Equatable {
    case circle
    case roundedSquare(CGFloat)
    case sharpSquare
    case rectangle
    case capsule
    case hexagon
    case jagged
}

/// How a themed progress ring animates.
enum RingAnimationStyle: Equatable {
    case none
    case rotate(period: Double)
    case dashPhase(speed: Double)
    case pulse(period: Double, amount: CGFloat)
    case radarSweep(period: Double)
    case stutterDash(speed: Double)
}

/// How the digits animate.
enum DigitAnimationStyle: Equatable {
    case none
    case breathing(period: Double, min: Double)
    case flicker(min: CGFloat, max: CGFloat)
    case gradientWave(period: Double)
    case fadingStutter(period: Double)
}

/// How a theme animates in when selected. Lightning should snap, Aurora
/// should dissolve — a single shared crossfade made all 10 feel identical.
enum ThemeTransitionStyle: Equatable {
    case flashCut       // near-instant with a bright blink
    case dissolve       // slow, soft
    case crossfade      // balanced default
    case glitch         // fast, snappy, slightly overshooting

    var animation: Animation {
        switch self {
        case .flashCut:  return .easeOut(duration: 0.28)
        case .dissolve:  return .easeInOut(duration: 1.1)
        case .crossfade: return .easeInOut(duration: 0.8)
        case .glitch:    return .spring(response: 0.32, dampingFraction: 0.55)
        }
    }
}

/// Which native `Canvas` particle field the background renders.
enum ParticleConfiguration: Equatable {
    case embers(rising: Bool, fade: Bool)
    case lightningBolts
    case neonGrid
    case scanlines
    case glassOrbs
    case auroraCurtains   // real borealis: vertical light ribbons over a star field
    case emberBed         // dying fire: glowing coal bed + falling ash
    case stars
    case lavaCracks
    case retroGrid
    case sparkles
}

// MARK: - Sub-configurations

struct DigitStyle: Equatable {
    var font: Font
    var gradientColors: [Color]
    var gradientStart: UnitPoint = .topLeading
    var gradientEnd: UnitPoint = .bottomTrailing
    var blur: CGFloat = 0
    var shadows: [ThemeShadow]
    var animation: DigitAnimationStyle
}

struct RingStyle: Equatable {
    var lineWidth: CGFloat
    var colors: [Color]
    var usesAngularGradient: Bool = false
    /// Shape language of the ring. No dashed/dotted options — they read cheap.
    var design: RingDesign = .solidGlow
    var glow: ThemeShadow?
    var trackColor: Color
    var animation: RingAnimationStyle
}

struct ButtonStyleConfig: Equatable {
    var shape: ThemeButtonShapeStyle
    var backgroundColors: [Color]
    var usesMaterial: Bool = false
    var iconColor: Color
    var borderColor: Color? = nil
    var borderWidth: CGFloat = 0
    var shadow: ThemeShadow?
    var pulse: Bool = false
}

struct TabStyleConfig: Equatable {
    var selectedColors: [Color]
    var unselectedColor: Color
    var usesMaterialBackground: Bool = true
    var backgroundTint: Color = .clear
}

// MARK: - Theme Configuration

/// Holds *all* styling properties for a theme — the app's "CSS variables".
struct ThemeConfiguration: Equatable {
    var theme: AppTheme

    // Typography / general
    var fontDesign: Font.Design
    var fontWeight: Font.Weight
    var cornerRadius: CGFloat

    // Colors
    var primary: Color
    var secondary: Color
    var backgroundTop: Color
    var backgroundBottom: Color
    var textPrimary: Color
    var textSecondary: Color
    var surface: Color

    // Component styles
    var digits: DigitStyle
    var ring: RingStyle
    var button: ButtonStyleConfig
    var tabs: TabStyleConfig
    var particles: ParticleConfiguration
    var transition: ThemeTransitionStyle

    /// Palette used for Swift Charts marks.
    var chartColors: [Color]

    // Convenience derived styles
    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    var digitGradient: LinearGradient {
        LinearGradient(colors: digits.gradientColors, startPoint: digits.gradientStart, endPoint: digits.gradientEnd)
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Theme Engine Protocol

/// Abstracts the enum → configuration mapping so `ThemeManager` holds
/// state only, never styling logic (dependency injection).
protocol ThemeEngine {
    func configuration(for theme: AppTheme) -> ThemeConfiguration
}

// MARK: - Theme Provider

/// Concrete `ThemeEngine`. All 10 visual specifications live here.
final class ThemeProvider: ThemeEngine {

    /// Applies the user's per-theme overrides (hue / saturation / brightness /
    /// ring design) on top of the designed palette.
    func configuration(for theme: AppTheme) -> ThemeConfiguration {
        var config = baseConfiguration(for: theme)
        let custom = ThemeCustomizationStore.shared.customization(for: theme)
        guard custom.isCustomized else { return config }

        func adj(_ c: Color) -> Color { c.adjusted(custom) }

        config.primary = adj(config.primary)
        config.secondary = adj(config.secondary)
        config.backgroundTop = adj(config.backgroundTop)
        config.backgroundBottom = adj(config.backgroundBottom)
        config.textSecondary = adj(config.textSecondary)
        config.surface = adj(config.surface)
        config.chartColors = config.chartColors.map(adj)

        config.digits.gradientColors = config.digits.gradientColors.map(adj)
        config.digits.shadows = config.digits.shadows.map {
            ThemeShadow(color: adj($0.color), radius: $0.radius, x: $0.x, y: $0.y)
        }
        config.ring.colors = config.ring.colors.map(adj)
        config.ring.trackColor = adj(config.ring.trackColor)
        if let glow = config.ring.glow {
            config.ring.glow = ThemeShadow(color: adj(glow.color), radius: glow.radius, x: glow.x, y: glow.y)
        }
        if let design = custom.ringDesign { config.ring.design = design }

        config.button.backgroundColors = config.button.backgroundColors.map(adj)
        config.button.iconColor = adj(config.button.iconColor)
        if let border = config.button.borderColor { config.button.borderColor = adj(border) }
        if let shadow = config.button.shadow {
            config.button.shadow = ThemeShadow(color: adj(shadow.color), radius: shadow.radius, x: shadow.x, y: shadow.y)
        }
        config.tabs.selectedColors = config.tabs.selectedColors.map(adj)
        config.tabs.unselectedColor = adj(config.tabs.unselectedColor)
        return config
    }

    private func baseConfiguration(for theme: AppTheme) -> ThemeConfiguration {
        switch theme {
        case .flame: return flame
        case .lightning: return lightning
        case .laser: return laser
        case .cyberpunk: return cyberpunk
        case .aurora: return aurora
        case .darkMatter: return darkMatter
        case .lava: return lava
        case .neon80s: return neon80s
        case .galaxy: return galaxy
        case .burningEmber: return burningEmber
        }
    }

    // MARK: 1. Flame

    private var flame: ThemeConfiguration {
        ThemeConfiguration(
            theme: .flame,
            fontDesign: .default,
            fontWeight: .heavy,
            cornerRadius: 14,
            primary: Color(hex: "#FF6B1A"),
            secondary: Color(hex: "#FFC300"),
            backgroundTop: Color(hex: "#3B0A02"),
            backgroundBottom: Color(hex: "#1A0B04"),
            textPrimary: .white,
            textSecondary: Color(hex: "#FFB088"),
            surface: Color(hex: "#2A0D05"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .heavy, design: .default),
                gradientColors: [.red, .orange, .yellow],
                shadows: [ThemeShadow(color: .orange.opacity(0.8), radius: 30)],
                animation: .breathing(period: 0.2, min: 0.95)
            ),
            ring: RingStyle(
                lineWidth: 12,
                colors: [.red, .orange, .yellow, .red],
                usesAngularGradient: true,
                design: .solidGlow,
                glow: ThemeShadow(color: .orange, radius: 10),
                trackColor: Color.orange.opacity(0.30),
                animation: .rotate(period: 20)
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [.orange, .red],
                iconColor: .yellow,
                shadow: ThemeShadow(color: .orange, radius: 25),
                pulse: true
            ),
            tabs: TabStyleConfig(
                selectedColors: [.yellow, .red],
                unselectedColor: .orange,
                backgroundTint: Color.red.opacity(0.15)
            ),
            particles: .embers(rising: true, fade: true),
            transition: .crossfade,
            chartColors: [.red, .orange, .yellow]
        )
    }

    // MARK: 2. Lightning

    private var lightning: ThemeConfiguration {
        ThemeConfiguration(
            theme: .lightning,
            fontDesign: .default,
            fontWeight: .light,
            cornerRadius: 4,
            primary: Color(hex: "#00E5FF"),
            secondary: Color(hex: "#2B6BFF"),
            backgroundTop: Color(hex: "#0A1230"),
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#7FD8FF"),
            surface: Color(hex: "#0D1838"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .light, design: .default),
                gradientColors: [Color(hex: "#00A6FF"), .white],
                shadows: [ThemeShadow(color: .cyan.opacity(0.9), radius: 40)],
                animation: .flicker(min: 20, max: 45)
            ),
            ring: RingStyle(
                lineWidth: 6,
                colors: [.cyan, .blue],
                design: .cometTrail,
                glow: ThemeShadow(color: .cyan, radius: 8),
                trackColor: Color.cyan.opacity(0.30),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [Color(hex: "#0091AD"), Color(hex: "#00C2E0")],
                iconColor: .white,
                shadow: ThemeShadow(color: .cyan, radius: 20)
            ),
            tabs: TabStyleConfig(
                selectedColors: [.white],
                unselectedColor: Color.cyan.opacity(0.5),
                backgroundTint: Color.blue.opacity(0.12)
            ),
            particles: .lightningBolts,
            transition: .flashCut,
            chartColors: [.cyan, Color(hex: "#2B6BFF"), .white]
        )
    }

    // MARK: 3. Laser

    private var laser: ThemeConfiguration {
        ThemeConfiguration(
            theme: .laser,
            fontDesign: .default,
            fontWeight: .medium,
            cornerRadius: 2,
            primary: Color(hex: "#39FF14"),
            secondary: Color(hex: "#FF3EC9"),
            backgroundTop: Color(hex: "#050A12"),
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#8FFF7A"),
            surface: Color(hex: "#0A1018"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .medium, design: .default),
                gradientColors: [Color(hex: "#39FF14"), Color(hex: "#FF3EC9")],
                gradientStart: .leading,
                gradientEnd: .trailing,
                shadows: [ThemeShadow(color: Color(hex: "#FF3EC9"), radius: 35)],
                animation: .gradientWave(period: 3)
            ),
            ring: RingStyle(
                lineWidth: 4,
                colors: [Color(hex: "#39FF14")],
                design: .segmentedArc,
                glow: ThemeShadow(color: Color(hex: "#39FF14"), radius: 8),
                trackColor: Color.green.opacity(0.30),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [Color(hex: "#FF3EC9")],
                iconColor: Color(hex: "#39FF14"),
                shadow: ThemeShadow(color: Color(hex: "#39FF14"), radius: 15)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#39FF14")],
                unselectedColor: Color(hex: "#4A4A4A"),
                backgroundTint: Color.green.opacity(0.08)
            ),
            particles: .neonGrid,
            transition: .glitch,
            chartColors: [Color(hex: "#39FF14"), Color(hex: "#FF3EC9"), .cyan]
        )
    }

    // MARK: 4. Cyberpunk

    private var cyberpunk: ThemeConfiguration {
        ThemeConfiguration(
            theme: .cyberpunk,
            fontDesign: .monospaced,
            fontWeight: .semibold,
            cornerRadius: 6,
            primary: Color(hex: "#00E5FF"),
            secondary: Color(hex: "#B026FF"),
            backgroundTop: Color(hex: "#1A0033"),
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#C79BFF"),
            surface: Color(hex: "#200A3A"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .semibold, design: .monospaced),
                gradientColors: [.cyan, Color(hex: "#B026FF")],
                shadows: [
                    ThemeShadow(color: .cyan, radius: 0, x: -3, y: -3),
                    ThemeShadow(color: .red, radius: 0, x: 3, y: 3)
                ],
                animation: .none
            ),
            ring: RingStyle(
                lineWidth: 8,
                colors: [.cyan],
                design: .radarSweep,
                glow: ThemeShadow(color: .cyan, radius: 6),
                trackColor: Color.purple.opacity(0.30),
                animation: .radarSweep(period: 4)
            ),
            button: ButtonStyleConfig(
                shape: .hexagon,
                backgroundColors: [Color(hex: "#3B0A5E")],
                iconColor: .cyan,
                borderColor: .cyan,
                borderWidth: 1.5,
                shadow: ThemeShadow(color: Color(hex: "#B026FF"), radius: 18)
            ),
            tabs: TabStyleConfig(
                selectedColors: [.cyan],
                unselectedColor: Color(hex: "#B026FF"),
                backgroundTint: Color.purple.opacity(0.18)
            ),
            particles: .scanlines,
            transition: .glitch,
            chartColors: [.cyan, Color(hex: "#B026FF"), Color(hex: "#FF2079")]
        )
    }

    // MARK: 5. Aurora

    private var aurora: ThemeConfiguration {
        ThemeConfiguration(
            theme: .aurora,
            fontDesign: .rounded,
            fontWeight: .medium,
            cornerRadius: 26,
            primary: Color(hex: "#4ADE80"),
            secondary: Color(hex: "#8B5CF6"),
            backgroundTop: Color(hex: "#04121C"),
            backgroundBottom: Color(hex: "#0A0620"),
            textPrimary: .white,
            textSecondary: Color(hex: "#B8E8E0"),
            surface: Color.white.opacity(0.06),
            digits: DigitStyle(
                font: .system(size: 72, weight: .medium, design: .rounded),
                gradientColors: [Color(hex: "#4ADE80"), Color(hex: "#22D3EE"), Color(hex: "#8B5CF6")],
                blur: 0.5,
                shadows: [ThemeShadow(color: .white.opacity(0.4), radius: 50)],
                animation: .breathing(period: 4, min: 0.9)
            ),
            ring: RingStyle(
                lineWidth: 20,
                colors: [.white.opacity(0.55), .white.opacity(0.25)],
                design: .taperedArc,
                glow: ThemeShadow(color: .white.opacity(0.5), radius: 5),
                trackColor: Color.white.opacity(0.30),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .capsule,
                backgroundColors: [.clear],
                usesMaterial: true,
                iconColor: Color(hex: "#4ADE80"),
                borderColor: .white.opacity(0.25),
                borderWidth: 1,
                shadow: ThemeShadow(color: .white.opacity(0.25), radius: 20)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#4ADE80")],
                unselectedColor: .white.opacity(0.55),
                backgroundTint: .white.opacity(0.06)
            ),
            particles: .auroraCurtains,
            transition: .dissolve,
            chartColors: [Color(hex: "#4ADE80"), Color(hex: "#22D3EE"), Color(hex: "#8B5CF6")]
        )
    }

    // MARK: 6. Dark Matter

    private var darkMatter: ThemeConfiguration {
        ThemeConfiguration(
            theme: .darkMatter,
            fontDesign: .default,
            fontWeight: .regular,
            cornerRadius: 10,
            primary: .white,
            secondary: Color(hex: "#9CA3AF"),
            backgroundTop: .black,
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#6B7280"),
            surface: Color(hex: "#0E0E0E"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .regular, design: .default),
                gradientColors: [.white, .white],
                shadows: [],
                animation: .none
            ),
            ring: RingStyle(
                lineWidth: 3,
                colors: [Color.gray.opacity(0.5)],
                design: .hairline,
                glow: nil,
                trackColor: Color.gray.opacity(0.30),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [.black],
                iconColor: .white,
                borderColor: .white,
                borderWidth: 1,
                shadow: nil
            ),
            tabs: TabStyleConfig(
                selectedColors: [.white],
                unselectedColor: Color(hex: "#4B5563"),
                backgroundTint: .clear
            ),
            particles: .stars,
            transition: .dissolve,
            chartColors: [.white, Color(hex: "#9CA3AF"), Color(hex: "#6B7280")]
        )
    }

    // MARK: 7. Lava

    private var lava: ThemeConfiguration {
        ThemeConfiguration(
            theme: .lava,
            fontDesign: .default,
            fontWeight: .bold,
            cornerRadius: 8,
            primary: Color(hex: "#DC143C"),
            secondary: Color(hex: "#FF4500"),
            backgroundTop: Color(hex: "#1F1F1F"),
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#A66A5E"),
            surface: Color(hex: "#171717"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .bold, design: .default),
                gradientColors: [Color(hex: "#7A0A1E"), Color(hex: "#FF2D2D")],
                shadows: [ThemeShadow(color: Color(hex: "#8B0000"), radius: 25)],
                animation: .breathing(period: 1.2, min: 0.82)
            ),
            ring: RingStyle(
                lineWidth: 15,
                colors: [Color(hex: "#DC143C")],
                design: .pulseRing,
                glow: ThemeShadow(color: Color(hex: "#DC143C"), radius: 12),
                trackColor: Color.red.opacity(0.30),
                animation: .pulse(period: 2, amount: 0.1)
            ),
            button: ButtonStyleConfig(
                shape: .jagged,
                backgroundColors: [.black, Color(hex: "#1A0000")],
                iconColor: .orange,
                borderColor: Color(hex: "#8B0000"),
                borderWidth: 1.5,
                shadow: ThemeShadow(color: Color(hex: "#8B0000"), radius: 22)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#FF2D2D")],
                unselectedColor: Color(hex: "#5C3A2E"),
                backgroundTint: Color.red.opacity(0.1)
            ),
            particles: .lavaCracks,
            transition: .crossfade,
            chartColors: [Color(hex: "#DC143C"), Color(hex: "#FF4500"), Color(hex: "#8B0000")]
        )
    }

    // MARK: 8. Neon 80s

    private var neon80s: ThemeConfiguration {
        ThemeConfiguration(
            theme: .neon80s,
            fontDesign: .default,
            fontWeight: .regular,
            cornerRadius: 0,
            primary: Color(hex: "#FF2D95"),
            secondary: Color(hex: "#00E5FF"),
            backgroundTop: Color(hex: "#12005E"),
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#00E5FF"),
            surface: Color(hex: "#1A0A4A"),
            digits: DigitStyle(
                font: .custom("AvenirNext-Regular", size: 72),
                gradientColors: [Color(hex: "#FF2D95"), .cyan],
                shadows: [ThemeShadow(color: .cyan, radius: 35)],
                animation: .none
            ),
            ring: RingStyle(
                lineWidth: 6,
                colors: [.yellow],
                design: .neonTube,
                glow: ThemeShadow(color: .yellow, radius: 10),
                trackColor: Color.cyan.opacity(0.30),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [.yellow],
                iconColor: Color(hex: "#FF2D95"),
                shadow: ThemeShadow(color: Color(hex: "#FF2D95"), radius: 20)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#FF2D95")],
                unselectedColor: Color(hex: "#2B3A9E"),
                backgroundTint: Color.blue.opacity(0.2)
            ),
            particles: .retroGrid,
            transition: .glitch,
            chartColors: [Color(hex: "#FF2D95"), .cyan, .yellow]
        )
    }

    // MARK: 9. Galaxy

    private var galaxy: ThemeConfiguration {
        ThemeConfiguration(
            theme: .galaxy,
            fontDesign: .rounded,
            fontWeight: .thin,
            cornerRadius: 22,
            primary: Color(hex: "#A78BFA"),
            secondary: Color(hex: "#3B4FA8"),
            backgroundTop: Color(hex: "#0B1030"),
            backgroundBottom: Color(hex: "#05061A"),
            textPrimary: .white,
            textSecondary: Color(hex: "#9AA6E0"),
            surface: Color(hex: "#111740"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .thin, design: .rounded),
                gradientColors: [Color(hex: "#A78BFA"), Color(hex: "#1E3A8A")],
                blur: 1,
                shadows: [ThemeShadow(color: .purple.opacity(0.5), radius: 40)],
                animation: .breathing(period: 5, min: 0.88)
            ),
            ring: RingStyle(
                lineWidth: 2,
                colors: [Color(hex: "#A78BFA"), .white],
                design: .doubleOrbit,
                glow: ThemeShadow(color: .purple.opacity(0.6), radius: 8),
                trackColor: Color.white.opacity(0.30),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [Color.white.opacity(0.2)],
                iconColor: Color(hex: "#C4B5FD"),
                borderColor: .white.opacity(0.2),
                borderWidth: 1,
                shadow: ThemeShadow(color: .purple.opacity(0.5), radius: 25)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#C4B5FD")],
                unselectedColor: Color(hex: "#4C3B87"),
                backgroundTint: Color.purple.opacity(0.12)
            ),
            particles: .sparkles,
            transition: .dissolve,
            chartColors: [Color(hex: "#A78BFA"), Color(hex: "#60A5FA"), Color(hex: "#F472B6")]
        )
    }

    // MARK: 10. Burning Ember

    private var burningEmber: ThemeConfiguration {
        ThemeConfiguration(
            theme: .burningEmber,
            fontDesign: .default,
            fontWeight: .bold,
            cornerRadius: 12,
            primary: Color(hex: "#E2551B"),
            secondary: Color(hex: "#6E6A66"),
            backgroundTop: Color(hex: "#171514"),
            backgroundBottom: .black,
            textPrimary: Color(hex: "#E8E0DA"),
            textSecondary: Color(hex: "#8A8078"),
            surface: Color(hex: "#1C1A18"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .bold, design: .default),
                gradientColors: [Color(hex: "#3A3A3A"), Color(hex: "#C2762E")],
                shadows: [ThemeShadow(color: Color(hex: "#C25A2E").opacity(0.7), radius: 20)],
                animation: .fadingStutter(period: 2.4)
            ),
            ring: RingStyle(
                lineWidth: 12,
                colors: [Color(hex: "#3F3F3F")],
                design: .solidGlow,
                glow: ThemeShadow(color: Color(hex: "#C25A2E").opacity(0.4), radius: 8),
                trackColor: Color.white.opacity(0.30),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .roundedSquare(26),
                backgroundColors: [Color(hex: "#2E2C2A")],
                iconColor: Color(hex: "#C2762E"),
                borderColor: Color(hex: "#3F3B38"),
                borderWidth: 1,
                shadow: ThemeShadow(color: Color(hex: "#C25A2E").opacity(0.35), radius: 16)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#C2762E")],
                unselectedColor: Color(hex: "#4A4A4A"),
                backgroundTint: Color.black.opacity(0.3)
            ),
            particles: .emberBed,
            transition: .dissolve,
            chartColors: [Color(hex: "#C2762E"), Color(hex: "#8A5A3A"), Color(hex: "#4A4A4A")]
        )
    }
}
