//
//  View+Theme.swift
//  FlowScope
//
//  The `.applyTheme(_:)` modifier plus the themed building blocks
//  (digits, progress ring, play button, tab label). All theme branching
//  lives here so screen-level views stay declarative.
//

import SwiftUI

// MARK: - applyTheme

/// Applies the theme's font, foreground, border and background to a view.
struct ThemeModifier: ViewModifier {
    let config: ThemeConfiguration

    func body(content: Content) -> some View {
        content
            .font(.system(.body, design: config.fontDesign).weight(config.fontWeight))
            .foregroundStyle(config.textPrimary)
            .tint(config.primary)
            .animation(config.transition.animation, value: config.theme)
    }
}

extension View {
    /// Apply the full theme configuration to this view.
    func applyTheme(_ config: ThemeConfiguration) -> some View {
        modifier(ThemeModifier(config: config))
    }

    /// Apply a stack of themed shadows (supports chromatic aberration).
    @ViewBuilder
    func themedShadows(_ shadows: [ThemeShadow]) -> some View {
        shadows.reduce(AnyView(self)) { view, shadow in
            AnyView(view.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y))
        }
    }

    /// Themed card surface — background, corner radius and hairline border.
    func themedSurface(_ config: ThemeConfiguration) -> some View {
        self
            .background(config.surface)
            .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .stroke(config.primary.opacity(0.25), lineWidth: 1)
            )
            .animation(config.transition.animation, value: config.theme)
    }
}

// MARK: - Themed Shapes

/// Hexagon used by the Cyberpunk theme.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = Double(i) * (.pi / 3) - .pi / 2
            let pt = CGPoint(x: c.x + r * CGFloat(cos(angle)), y: c.y + r * CGFloat(sin(angle)))
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

/// Irregular cracked-rock silhouette used by the Lava theme.
struct JaggedShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        // Fixed peaks/valleys so the silhouette is stable, not jittering.
        let radii: [CGFloat] = [1.0, 0.78, 0.95, 0.72, 1.0, 0.8, 0.92, 0.75, 1.0, 0.83, 0.9, 0.76]
        var path = Path()
        for (i, factor) in radii.enumerated() {
            let angle = Double(i) / Double(radii.count) * 2 * .pi - .pi / 2
            let rr = r * factor
            let pt = CGPoint(x: c.x + rr * CGFloat(cos(angle)), y: c.y + rr * CGFloat(sin(angle)))
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

/// Resolves a `ThemeButtonShapeStyle` into a concrete shape.
struct ThemeButtonShape: Shape {
    let style: ThemeButtonShapeStyle

    func path(in rect: CGRect) -> Path {
        switch style {
        case .circle:
            return Circle().path(in: rect)
        case .capsule:
            return Capsule().path(in: rect)
        case .sharpSquare, .rectangle:
            return Rectangle().path(in: rect)
        case let .roundedSquare(radius):
            return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        case .hexagon:
            return HexagonShape().path(in: rect)
        case .jagged:
            return JaggedShape().path(in: rect)
        }
    }
}

// MARK: - Themed Digits

/// The big timer readout. Gradient fill, stacked shadows, per-theme animation.
struct ThemedDigits: View {
    @ObservedObject private var settings = AppSettings.shared
    let text: String
    let config: ThemeConfiguration

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Text(text)
                .font(config.digits.font)
                .foregroundStyle(config.digitGradient)
                .blur(radius: config.digits.blur)
                .opacity(opacity(at: t))
                .themedShadows(shadows(at: t))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .animation(config.transition.animation, value: config.theme)
    }

    private func opacity(at t: Double) -> Double {
        guard settings.animatedDigits else { return 1 }
        switch config.digits.animation {
        case .none, .flicker, .gradientWave:
            return 1
        case let .breathing(period, minValue):
            let wave = (sin(t * (2 * .pi / period)) + 1) / 2
            return minValue + (1 - minValue) * wave
        case let .fadingStutter(period):
            // Slow fade with an abrupt "stutter" restart.
            let phase = t.truncatingRemainder(dividingBy: period) / period
            return phase < 0.15 ? 0.55 : 0.72 + 0.28 * (1 - phase)
        }
    }

    private func shadows(at t: Double) -> [ThemeShadow] {
        guard settings.glowEnabled else { return [] }
        guard settings.animatedDigits else { return config.digits.shadows }
        switch config.digits.animation {
        case let .flicker(minRadius, maxRadius):
            // Deterministic pseudo-random radius that changes ~10x/sec.
            let tick = floor(t * 10)
            let noise = abs(sin(tick * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            let radius = minRadius + (maxRadius - minRadius) * CGFloat(noise)
            return config.digits.shadows.map {
                ThemeShadow(color: $0.color, radius: radius, x: $0.x, y: $0.y)
            }
        default:
            return config.digits.shadows
        }
    }
}

// MARK: - Themed Progress Ring

/// Ring renderer. Each theme gets a distinct shape language — no dashed or
/// dotted strokes, which read as cheap at this diameter.
struct ThemedProgressRing: View {
    let progress: CGFloat
    let config: ThemeConfiguration
    var diameter: CGFloat = 280

    private var lineWidth: CGFloat { config.ring.lineWidth }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                track
                design(at: t)
            }
            .frame(width: diameter, height: diameter)
        }
        .animation(config.transition.animation, value: config.theme)
    }

    private var track: some View {
        Circle().stroke(config.ring.trackColor, lineWidth: lineWidth)
    }

    private var arcStyle: AnyShapeStyle {
        if config.ring.usesAngularGradient {
            return AnyShapeStyle(AngularGradient(colors: config.ring.colors + [config.ring.colors[0]], center: .center))
        }
        if config.ring.colors.count > 1 {
            return AnyShapeStyle(AngularGradient(colors: config.ring.colors, center: .center))
        }
        return AnyShapeStyle(config.ring.colors.first ?? config.primary)
    }

    @ViewBuilder
    private func design(at t: Double) -> some View {
        switch config.ring.design {
        case .solidGlow:    solidGlow(at: t)
        case .neonTube:     neonTube(at: t)
        case .cometTrail:   cometTrail(at: t)
        case .doubleOrbit:  doubleOrbit(at: t)
        case .segmentedArc: segmentedArc(at: t)
        case .taperedArc:   taperedArc(at: t)
        case .hairline:     hairline(at: t)
        case .pulseRing:    pulseRing(at: t)
        case .radarSweep:   radarSweep(at: t)
        }
    }

    // Base arc used by several designs.
    private func arc(_ trim: CGFloat, width: CGFloat, style: AnyShapeStyle, rotation: Double = 0) -> some View {
        Circle()
            .trim(from: 0, to: max(0.0001, min(trim, 1)))
            .stroke(style, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .rotationEffect(.degrees(-90 + rotation))
    }

    // MARK: Designs

    private func solidGlow(at t: Double) -> some View {
        ZStack {
            arc(progress, width: lineWidth, style: arcStyle)
                .blur(radius: lineWidth * 0.6)
                .opacity(0.85)
            arc(progress, width: lineWidth, style: arcStyle)
        }
        .shadowIfNeeded(config.ring.glow)
    }

    /// Thick outer tube with a bright thin inner highlight — real neon.
    private func neonTube(at t: Double) -> some View {
        ZStack {
            arc(progress, width: lineWidth * 2.2, style: arcStyle).opacity(0.28).blur(radius: 8)
            arc(progress, width: lineWidth, style: arcStyle)
            arc(progress, width: max(1, lineWidth * 0.3), style: AnyShapeStyle(Color.white.opacity(0.9)))
        }
        .shadowIfNeeded(config.ring.glow)
    }

    /// Arc that fades toward its tail with a bright head — reads as speed.
    private func cometTrail(at t: Double) -> some View {
        let head = progress
        return ZStack {
            Circle()
                .trim(from: max(0, head - 0.42), to: max(0.0001, head))
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: config.primary.opacity(0), location: 0),
                            .init(color: config.primary.opacity(0.55), location: 0.7),
                            .init(color: .white, location: 1)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            // Bright head.
            Circle()
                .fill(.white)
                .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
                .shadow(color: config.primary, radius: 10)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(Double(head) * 360))
        }
        .shadowIfNeeded(config.ring.glow)
    }

    /// Two concentric arcs turning opposite ways.
    private func doubleOrbit(at t: Double) -> some View {
        ZStack {
            arc(progress, width: lineWidth * 1.6, style: arcStyle, rotation: t * 12)
            Circle()
                .trim(from: 0, to: max(0.0001, min(progress * 0.7, 1)))
                .stroke(config.secondary.opacity(0.8), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90 - t * 20))
                .scaleEffect(0.86)
        }
        .shadowIfNeeded(config.ring.glow)
    }

    /// Chunky gauge segments — precise and technical, never dotty.
    private func segmentedArc(at t: Double) -> some View {
        let segments = 36
        let filled = Int(progress * CGFloat(segments))
        return ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let on = i < filled
                Capsule()
                    .fill(on ? AnyShapeStyle(config.accentGradient) : AnyShapeStyle(config.primary.opacity(0.12)))
                    .frame(width: lineWidth * 1.6, height: on ? 16 : 10)
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(Double(i) / Double(segments) * 360))
                    .shadow(color: on ? config.primary.opacity(0.9) : .clear, radius: 6)
            }
        }
    }

    /// Sweep that grows from hairline to full width.
    private func taperedArc(at t: Double) -> some View {
        let steps = 28
        return ZStack {
            ForEach(0..<steps, id: \.self) { i in
                let f = CGFloat(i) / CGFloat(steps)
                let seg = progress / CGFloat(steps)
                Circle()
                    .trim(from: f * progress, to: min(f * progress + seg * 1.4, 1))
                    .stroke(
                        config.ring.colors.first ?? config.primary,
                        style: StrokeStyle(lineWidth: lineWidth * (0.25 + 0.75 * f), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(0.35 + 0.65 * Double(f))
            }
        }
        .blur(radius: 1.5)
        .shadowIfNeeded(config.ring.glow)
    }

    private func hairline(at t: Double) -> some View {
        ZStack {
            arc(progress, width: lineWidth, style: arcStyle)
            Circle()
                .fill(config.primary)
                .frame(width: lineWidth * 2.4, height: lineWidth * 2.4)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(Double(progress) * 360))
        }
    }

    private func pulseRing(at t: Double) -> some View {
        let wave = (sin(t * (2 * .pi / 2)) + 1) / 2
        return ZStack {
            arc(progress, width: lineWidth, style: arcStyle)
                .blur(radius: 10)
                .opacity(0.35 + 0.4 * wave)
                .scaleEffect(1 + 0.05 * CGFloat(wave))
            arc(progress, width: lineWidth, style: arcStyle)
        }
        .shadowIfNeeded(config.ring.glow)
    }

    private func radarSweep(at t: Double) -> some View {
        let angle = (t / 4).truncatingRemainder(dividingBy: 1)
        return ZStack {
            arc(progress, width: lineWidth, style: arcStyle)
            Circle()
                .trim(from: 0, to: 0.12)
                .stroke(
                    LinearGradient(colors: [config.primary.opacity(0), .white], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90 + angle * 360))
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .shadow(color: config.primary, radius: 8)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(angle * 360 + 43))
        }
        .shadowIfNeeded(config.ring.glow)
    }
}

private extension View {
    @ViewBuilder
    func shadowIfNeeded(_ shadow: ThemeShadow?) -> some View {
        if let shadow {
            self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        } else {
            self
        }
    }
}

// MARK: - Themed Icon Button

/// The play / pause / stop control, styled entirely from the configuration.
struct ThemedIconButton: View {
    let systemName: String
    let config: ThemeConfiguration
    var size: CGFloat = 76
    var action: () -> Void

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Button(action: action) {
                ZStack {
                    shapeBackground
                    Image(systemName: systemName)
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(config.button.iconColor)
                }
                .frame(width: size, height: size)
                .overlay(borderOverlay)
                .shadowIfNeeded(config.button.shadow)
                .scaleEffect(pulseScale(at: t))
            }
            .buttonStyle(.plain)
        }
        .animation(config.transition.animation, value: config.theme)
    }

    @ViewBuilder
    private var shapeBackground: some View {
        if config.button.usesMaterial {
            ThemeButtonShape(style: config.button.shape)
                .fill(.ultraThinMaterial)
        } else {
            ThemeButtonShape(style: config.button.shape)
                .fill(
                    LinearGradient(
                        colors: config.button.backgroundColors.count > 1
                            ? config.button.backgroundColors
                            : [config.button.backgroundColors.first ?? config.primary,
                               config.button.backgroundColors.first ?? config.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if let borderColor = config.button.borderColor, config.button.borderWidth > 0 {
            ThemeButtonShape(style: config.button.shape)
                .stroke(borderColor, lineWidth: config.button.borderWidth)
        }
    }

    private func pulseScale(at t: Double) -> CGFloat {
        guard config.button.pulse else { return 1 }
        let wave = (sin(t * (2 * .pi / 3)) + 1) / 2
        return 1 + 0.05 * CGFloat(wave)
    }
}

// MARK: - Themed Tab Label

struct ThemedTabLabel: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let config: ThemeConfiguration

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
                .font(.system(.caption2, design: config.fontDesign))
        }
        .foregroundStyle(
            isSelected
                ? AnyShapeStyle(LinearGradient(colors: config.tabs.selectedColors.count > 1
                    ? config.tabs.selectedColors
                    : [config.tabs.selectedColors.first ?? config.primary,
                       config.tabs.selectedColors.first ?? config.primary],
                    startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(config.tabs.unselectedColor)
        )
        .animation(config.transition.animation, value: config.theme)
    }
}
