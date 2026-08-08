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
    case flame, cyberpunk, lava, neon80s
    case superman, batman, nightwing, deathstroke, redHood

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flame: return "Flame"
        case .cyberpunk: return "Cyberpunk"
        case .lava: return "Lava"
        case .neon80s: return "Neon 80s"
        case .superman: return "Superman"
        case .batman: return "Batman"
        case .nightwing: return "Nightwing"
        case .deathstroke: return "Deathstroke"
        case .redHood: return "Red Hood"
        }
    }

    /// Fallback glyph. Themes that ship an emblem draw that instead.
    var icon: String {
        switch self {
        case .flame: return "flame.fill"
        case .cyberpunk: return "square.stack.3d.up.slash.fill"
        case .lava: return "mountain.2.fill"
        case .neon80s: return "square.grid.3x3.fill"
        case .superman: return "shield.fill"
        case .batman: return "moon.fill"
        case .nightwing: return "bird.fill"
        case .deathstroke: return "scope"
        case .redHood: return "helmet.fill"
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

/// How a theme animates in when selected. Cyberpunk should glitch, Lava
/// should crossfade — a single shared crossfade made them all feel identical.
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
    case rain              // Gotham downpour: streaks with a wind lean
    case carbon            // clean technical weave — no bloom, no sparkle
    case fire              // real flame tongues licking up from the bottom
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

    /// Chest emblem drawn inside the timer ring. Nil for the abstract themes.
    var emblem: ThemeEmblem? = nil

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

/// Concrete `ThemeEngine`. Every visual specification lives here.
final class ThemeProvider: ThemeEngine {

    /// Applies the user's per-theme overrides (hue / saturation / brightness /
    /// ring design / explicit accent, secondary and background colors) on top
    /// of the designed palette.
    func configuration(for theme: AppTheme) -> ThemeConfiguration {
        var config = baseConfiguration(for: theme)
        let custom = ThemeCustomizationStore.shared.customization(for: theme)
        guard custom.isCustomized else { return config }

        applyGlobalAdjustment(custom, to: &config)
        applyAccentOverride(custom, to: &config)
        applySecondaryOverride(custom, to: &config)
        applyBackgroundOverride(custom, to: &config)

        if let design = custom.ringDesign { config.ring.design = design }
        return config
    }

    /// Hue / saturation / brightness sliders — recolor everything at once.
    private func applyGlobalAdjustment(_ custom: ThemeCustomization,
                                       to config: inout ThemeConfiguration) {
        guard custom.hasGlobalAdjustment else { return }
        transform(&config) { $0.adjusted(custom) }
        config.textSecondary = config.textSecondary.adjusted(custom)
        config.surface = config.surface.adjusted(custom)
        config.backgroundTop = config.backgroundTop.adjusted(custom)
        config.backgroundBottom = config.backgroundBottom.adjusted(custom)
        config.secondary = config.secondary.adjusted(custom)
    }

    /// The picked accent becomes `primary` exactly; everything in the accent
    /// family (digits, ring, button, tabs, charts) shifts by the same delta so
    /// the theme keeps its identity instead of turning into a single flat hue.
    private func applyAccentOverride(_ custom: ThemeCustomization,
                                     to config: inout ThemeConfiguration) {
        guard let hex = custom.primaryHex else { return }
        let target = Color(hex: hex)
        let delta = ColorDelta(from: config.primary, to: target)
        transform(&config) { delta.apply($0) }
        config.primary = target
    }

    private func applySecondaryOverride(_ custom: ThemeCustomization,
                                        to config: inout ThemeConfiguration) {
        guard let hex = custom.secondaryHex else { return }
        config.secondary = Color(hex: hex)
    }

    /// One picked color drives the whole backdrop: the gradient's top stop is
    /// the color itself, the bottom stop a darkened version, and `surface` a
    /// slightly lifted version so cards stay readable on any background.
    private func applyBackgroundOverride(_ custom: ThemeCustomization,
                                         to config: inout ThemeConfiguration) {
        guard let hex = custom.backgroundHex else { return }
        let top = Color(hex: hex)
        config.backgroundTop = top
        config.backgroundBottom = top.mixed(with: .black, amount: 0.6)
        config.surface = top.mixed(with: .white, amount: 0.10)
    }

    /// Applies a color transform across every accent-family property.
    private func transform(_ config: inout ThemeConfiguration,
                           _ adj: (Color) -> Color) {
        config.primary = adj(config.primary)
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

        config.button.backgroundColors = config.button.backgroundColors.map(adj)
        config.button.iconColor = adj(config.button.iconColor)
        if let border = config.button.borderColor { config.button.borderColor = adj(border) }
        if let shadow = config.button.shadow {
            config.button.shadow = ThemeShadow(color: adj(shadow.color), radius: shadow.radius, x: shadow.x, y: shadow.y)
        }
        config.tabs.selectedColors = config.tabs.selectedColors.map(adj)
        config.tabs.unselectedColor = adj(config.tabs.unselectedColor)
    }

    private func baseConfiguration(for theme: AppTheme) -> ThemeConfiguration {
        switch theme {
        case .flame: return flame
        case .cyberpunk: return cyberpunk
        case .lava: return lava
        case .neon80s: return neon80s
        case .superman: return superman
        case .batman: return batman
        case .nightwing: return nightwing
        case .deathstroke: return deathstroke
        case .redHood: return redHood
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
            particles: .fire,
            transition: .crossfade,
            chartColors: [.red, .orange, .yellow]
        )
    }

    // MARK: 2. Cyberpunk

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

    // MARK: 3. Lava

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

    // MARK: 4. Neon 80s

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

    // MARK: 5. Superman

    private var superman: ThemeConfiguration {
        ThemeConfiguration(
            theme: .superman,
            fontDesign: .default,
            fontWeight: .heavy,
            cornerRadius: 16,
            primary: Color(hex: "#1E5BFF"),
            secondary: Color(hex: "#E63030"),
            backgroundTop: Color(hex: "#0A1338"),
            backgroundBottom: Color(hex: "#04091E"),
            textPrimary: .white,
            textSecondary: Color(hex: "#93B4FF"),
            surface: Color(hex: "#101A45"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .heavy, design: .default),
                gradientColors: [Color(hex: "#FFD84D"), Color(hex: "#F5A623")],
                shadows: [ThemeShadow(color: Color(hex: "#E63030").opacity(0.75), radius: 28)],
                animation: .breathing(period: 3, min: 0.92)
            ),
            ring: RingStyle(
                lineWidth: 14,
                colors: [Color(hex: "#1E5BFF"), Color(hex: "#E63030"), Color(hex: "#F5C518"), Color(hex: "#1E5BFF")],
                usesAngularGradient: true,
                design: .solidGlow,
                glow: ThemeShadow(color: Color(hex: "#1E5BFF"), radius: 12),
                trackColor: Color(hex: "#1E5BFF").opacity(0.28),
                animation: .rotate(period: 24)
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [Color(hex: "#E63030"), Color(hex: "#B01B1B")],
                iconColor: Color(hex: "#FFD84D"),
                shadow: ThemeShadow(color: Color(hex: "#1E5BFF"), radius: 24),
                pulse: true
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#FFD84D")],
                unselectedColor: Color(hex: "#5878C7"),
                backgroundTint: Color(hex: "#1E5BFF").opacity(0.16)
            ),
            particles: .carbon,
            transition: .crossfade,
            chartColors: [Color(hex: "#1E5BFF"), Color(hex: "#E63030"), Color(hex: "#F5C518")],
            emblem: .superman
        )
    }

    // MARK: 6. Batman

    private var batman: ThemeConfiguration {
        ThemeConfiguration(
            theme: .batman,
            fontDesign: .default,
            fontWeight: .black,
            cornerRadius: 6,
            primary: Color(hex: "#FFDF00"),
            secondary: Color(hex: "#4A4A4A"),
            backgroundTop: Color(hex: "#12131A"),
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#8A8D99"),
            surface: Color(hex: "#17181F"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .black, design: .default),
                gradientColors: [Color(hex: "#FFDF00"), Color(hex: "#B99A00")],
                shadows: [ThemeShadow(color: Color(hex: "#FFDF00").opacity(0.5), radius: 24)],
                animation: .none
            ),
            ring: RingStyle(
                lineWidth: 10,
                colors: [Color(hex: "#FFDF00")],
                design: .solidGlow,
                glow: ThemeShadow(color: Color(hex: "#FFDF00"), radius: 10),
                trackColor: Color.white.opacity(0.14),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [.black, Color(hex: "#15161C")],
                iconColor: Color(hex: "#FFDF00"),
                borderColor: Color(hex: "#FFDF00"),
                borderWidth: 1.5,
                shadow: ThemeShadow(color: Color(hex: "#FFDF00").opacity(0.55), radius: 18)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#FFDF00")],
                unselectedColor: Color(hex: "#55575F"),
                backgroundTint: Color.black.opacity(0.4)
            ),
            particles: .carbon,
            transition: .flashCut,
            chartColors: [Color(hex: "#FFDF00"), Color(hex: "#8A8D99"), Color(hex: "#4A4A4A")],
            emblem: .batman
        )
    }

    // MARK: 7. Nightwing

    private var nightwing: ThemeConfiguration {
        ThemeConfiguration(
            theme: .nightwing,
            fontDesign: .rounded,
            fontWeight: .medium,
            cornerRadius: 18,
            primary: Color(hex: "#1E90FF"),
            secondary: Color(hex: "#0B2545"),
            backgroundTop: Color(hex: "#06101F"),
            backgroundBottom: .black,
            textPrimary: .white,
            textSecondary: Color(hex: "#7FB4E8"),
            surface: Color(hex: "#0C1626"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .medium, design: .rounded),
                gradientColors: [Color(hex: "#4FC3FF"), .white],
                shadows: [ThemeShadow(color: Color(hex: "#1E90FF").opacity(0.85), radius: 34)],
                animation: .breathing(period: 2.2, min: 0.9)
            ),
            ring: RingStyle(
                lineWidth: 7,
                colors: [Color(hex: "#1E90FF"), Color(hex: "#7FDBFF")],
                design: .cometTrail,
                glow: ThemeShadow(color: Color(hex: "#1E90FF"), radius: 10),
                trackColor: Color(hex: "#1E90FF").opacity(0.22),
                animation: .none
            ),
            button: ButtonStyleConfig(
                shape: .circle,
                backgroundColors: [Color(hex: "#0B2545")],
                iconColor: Color(hex: "#4FC3FF"),
                borderColor: Color(hex: "#1E90FF"),
                borderWidth: 1.5,
                shadow: ThemeShadow(color: Color(hex: "#1E90FF"), radius: 22)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#4FC3FF")],
                unselectedColor: Color(hex: "#3D5A80"),
                backgroundTint: Color(hex: "#1E90FF").opacity(0.12)
            ),
            particles: .carbon,
            transition: .glitch,
            chartColors: [Color(hex: "#1E90FF"), Color(hex: "#7FDBFF"), Color(hex: "#3D5A80")],
            emblem: .nightwing
        )
    }

    // MARK: 8. Deathstroke

    private var deathstroke: ThemeConfiguration {
        ThemeConfiguration(
            theme: .deathstroke,
            fontDesign: .monospaced,
            fontWeight: .semibold,
            cornerRadius: 4,
            primary: Color(hex: "#F26A21"),
            secondary: Color(hex: "#2B3A67"),
            backgroundTop: Color(hex: "#10131C"),
            backgroundBottom: Color(hex: "#05070D"),
            textPrimary: .white,
            textSecondary: Color(hex: "#9AA3B8"),
            surface: Color(hex: "#161A26"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .semibold, design: .monospaced),
                gradientColors: [Color(hex: "#FFB067"), Color(hex: "#F26A21")],
                shadows: [ThemeShadow(color: Color(hex: "#F26A21").opacity(0.7), radius: 22)],
                animation: .fadingStutter(period: 3)
            ),
            ring: RingStyle(
                lineWidth: 8,
                colors: [Color(hex: "#F26A21")],
                design: .radarSweep,
                glow: ThemeShadow(color: Color(hex: "#F26A21"), radius: 8),
                trackColor: Color(hex: "#2B3A67").opacity(0.5),
                animation: .radarSweep(period: 4)
            ),
            button: ButtonStyleConfig(
                shape: .hexagon,
                backgroundColors: [Color(hex: "#2B3A67")],
                iconColor: Color(hex: "#F26A21"),
                borderColor: Color(hex: "#F26A21"),
                borderWidth: 1.5,
                shadow: ThemeShadow(color: Color(hex: "#F26A21").opacity(0.6), radius: 18)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#F26A21")],
                unselectedColor: Color(hex: "#4A5578"),
                backgroundTint: Color(hex: "#2B3A67").opacity(0.3)
            ),
            particles: .carbon,
            transition: .glitch,
            chartColors: [Color(hex: "#F26A21"), Color(hex: "#2B3A67"), Color(hex: "#9AA3B8")],
            emblem: .deathstroke
        )
    }

    // MARK: 9. Red Hood

    private var redHood: ThemeConfiguration {
        ThemeConfiguration(
            theme: .redHood,
            fontDesign: .default,
            fontWeight: .bold,
            cornerRadius: 10,
            primary: Color(hex: "#C8102E"),
            secondary: Color(hex: "#6E6E6E"),
            backgroundTop: Color(hex: "#1A0A0C"),
            backgroundBottom: .black,
            textPrimary: Color(hex: "#F0E6E7"),
            textSecondary: Color(hex: "#C08A8F"),
            surface: Color(hex: "#210E11"),
            digits: DigitStyle(
                font: .system(size: 72, weight: .bold, design: .default),
                gradientColors: [Color(hex: "#FF3B3B"), Color(hex: "#8B0A19")],
                shadows: [ThemeShadow(color: Color(hex: "#C8102E").opacity(0.8), radius: 26)],
                animation: .breathing(period: 1.6, min: 0.86)
            ),
            ring: RingStyle(
                lineWidth: 13,
                colors: [Color(hex: "#C8102E"), Color(hex: "#FF4D4D")],
                design: .pulseRing,
                glow: ThemeShadow(color: Color(hex: "#C8102E"), radius: 12),
                trackColor: Color(hex: "#6E6E6E").opacity(0.3),
                animation: .pulse(period: 2, amount: 0.1)
            ),
            button: ButtonStyleConfig(
                shape: .roundedSquare(20),
                backgroundColors: [Color(hex: "#241012"), .black],
                iconColor: Color(hex: "#FF3B3B"),
                borderColor: Color(hex: "#6E6E6E"),
                borderWidth: 1.5,
                shadow: ThemeShadow(color: Color(hex: "#C8102E").opacity(0.6), radius: 20)
            ),
            tabs: TabStyleConfig(
                selectedColors: [Color(hex: "#FF3B3B")],
                unselectedColor: Color(hex: "#6E6E6E"),
                backgroundTint: Color(hex: "#C8102E").opacity(0.14)
            ),
            particles: .carbon,
            transition: .crossfade,
            chartColors: [Color(hex: "#C8102E"), Color(hex: "#FF4D4D"), Color(hex: "#6E6E6E")],
            emblem: .redHood
        )
    }
}
