//
//  ThemeParticles.swift
//  FlowScope
//
//  High-fidelity native `Canvas` effect renderer.
//
//  The cinematic look comes from three techniques, no external libraries:
//   1. Additive blending (`.plusLighter`) so overlapping light accumulates
//      and blows out to white — the way real HDR bloom behaves.
//   2. Multi-pass strokes: a wide dim halo, a mid glow, then a thin white
//      hot core. That layering is what reads as *emitted light* rather than
//      a drawn line (the old single-stroke bolts looked like sticks).
//   3. Gradient shading (radial / linear) instead of flat fills, so every
//      particle has falloff instead of a hard edge.
//

import SwiftUI

// MARK: - Deterministic RNG

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private struct Particle {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: Double
    var phase: Double
}

/// Stable pseudo-random value in 0..<1 from any pair of numbers.
private func noise(_ a: Double, _ b: Double = 0) -> Double {
    abs(sin(a * 12.9898 + b * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1)
}

// MARK: - Theme Particles

struct ThemeParticles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let configuration: ParticleConfiguration
    let primary: Color
    let secondary: Color
    var depth: Double = 1
    var intensity: Double = 1
    var speed: Double = 1

    private let particles: [Particle]

    init(configuration: ParticleConfiguration,
         primary: Color,
         secondary: Color,
         depth: Double = 1,
         intensity: Double = 1,
         speed: Double = 1) {
        self.configuration = configuration
        self.primary = primary
        self.secondary = secondary
        self.depth = depth
        self.intensity = intensity
        self.speed = speed

        var rng = SeededGenerator(seed: String(describing: configuration).hashValue &+ Int(depth * 977))
        particles = (0..<90).map { _ in
            Particle(
                x: CGFloat.random(in: 0...1, using: &rng),
                y: CGFloat.random(in: 0...1, using: &rng),
                size: CGFloat.random(in: 2...7, using: &rng),
                speed: Double.random(in: 0.4...1.6, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng)
            )
        }
    }

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { ctx, size in render(&ctx, size, 0) }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        render(&ctx, size, timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Draw helpers

    /// Wide halo → mid glow → bright body → thin white core.
    private func bloomStroke(_ ctx: inout GraphicsContext,
                             _ path: Path,
                             color: Color,
                             width: CGFloat,
                             alpha: Double,
                             core: Bool = true) {
        guard alpha > 0.004 else { return }
        var c = ctx
        c.blendMode = .plusLighter
        func style(_ w: CGFloat) -> StrokeStyle { StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round) }
        c.stroke(path, with: .color(color.opacity(alpha * 0.13)), style: style(width * 5.5))
        c.stroke(path, with: .color(color.opacity(alpha * 0.26)), style: style(width * 2.7))
        c.stroke(path, with: .color(color.opacity(alpha * 0.72)), style: style(width))
        if core {
            c.stroke(path, with: .color(.white.opacity(alpha * 0.9)), style: style(max(0.6, width * 0.34)))
        }
    }

    /// Soft radial particle with falloff — no hard circle edges.
    private func bloomDot(_ ctx: inout GraphicsContext,
                          at point: CGPoint,
                          radius: CGFloat,
                          color: Color,
                          alpha: Double,
                          hotCore: Bool = true) {
        guard alpha > 0.004, radius > 0.5 else { return }
        var c = ctx
        c.blendMode = .plusLighter
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        c.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color.opacity(alpha), location: 0),
                    .init(color: color.opacity(alpha * 0.42), location: 0.35),
                    .init(color: color.opacity(0), location: 1)
                ]),
                center: point, startRadius: 0, endRadius: radius
            )
        )
        if hotCore {
            let r = radius * 0.2
            c.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                   with: .color(.white.opacity(alpha * 0.85)))
        }
    }

    /// Full-screen additive flash — lightning strikes, cycle pulses.
    private func flash(_ ctx: inout GraphicsContext, _ size: CGSize, color: Color, alpha: Double) {
        guard alpha > 0.002 else { return }
        var c = ctx
        c.blendMode = .plusLighter
        c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color.opacity(alpha)))
    }

    private func vignette(_ ctx: inout GraphicsContext, _ size: CGSize, strength: Double) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(strength)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: size.width * 0.25,
                endRadius: max(size.width, size.height) * 0.75
            )
        )
    }

    private func count(_ base: Int) -> Int {
        max(1, Int(Double(base) * min(2.0, max(0.2, intensity)) * (0.6 + 0.4 * depth)))
    }

    private var alphaScale: Double { intensity * (0.4 + 0.6 * depth) }

    // MARK: Render

    private func render(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        guard intensity > 0.01 else { return }
        let t = time * (0.45 + 0.55 * depth) * speed

        switch configuration {
        case let .embers(rising, fade): drawEmbers(&ctx, size, t, rising: rising, fade: fade)
        case .lightningBolts:           drawLightning(&ctx, size, t)
        case .neonGrid:                 drawNeonGrid(&ctx, size, t)
        case .scanlines:                drawScanlines(&ctx, size, t)
        case .glassOrbs:                drawOrbs(&ctx, size, t)
        case .auroraCurtains:           drawAuroraCurtains(&ctx, size, t)
        case .emberBed:                 drawEmberBed(&ctx, size, t)
        case .stars:                    drawStars(&ctx, size, t)
        case .lavaCracks:               drawLava(&ctx, size, t)
        case .retroGrid:                drawRetroGrid(&ctx, size, t)
        case .sparkles:                 drawSparkles(&ctx, size, t)
        }
    }

    // MARK: Flame / Burning Ember

    private func drawEmbers(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double, rising: Bool, fade: Bool) {
        for p in particles.prefix(count(16)) {
            let travel = (t * 0.055 * p.speed + p.phase).truncatingRemainder(dividingBy: 1)
            let progress = CGFloat(travel)
            let y = rising ? size.height * (1 - progress) : size.height * progress
            // Turbulent sway that widens as the ember rises through hot air.
            let sway = CGFloat(sin(t * 1.1 + p.phase) + 0.4 * sin(t * 2.7 + p.phase)) * (8 + 16 * progress)
            let x = p.x * size.width + sway

            let life = fade ? Double(1 - progress) : 1
            let flicker = 0.65 + 0.35 * noise(floor(t * 12) + p.phase)
            let alpha = life * flicker * 0.95 * alphaScale
            let radius = p.size * (2.2 - 0.9 * progress) * 2.6
            let color = p.phase > 3 ? secondary : primary

            bloomDot(&ctx, at: CGPoint(x: x, y: y), radius: radius, color: color, alpha: alpha)

            // Motion-blur tail on the faster embers.
            if p.speed > 1.0 {
                var tail = Path()
                tail.move(to: CGPoint(x: x, y: y))
                tail.addLine(to: CGPoint(x: x - sway * 0.15, y: y + (rising ? 18 : -18)))
                bloomStroke(&ctx, tail, color: color, width: 1.4, alpha: alpha * 0.45, core: false)
            }
        }
    }

    // MARK: Lightning — branching, tapered, with strike flash

    /// Recursively builds a forked bolt. Real lightning branches; a single
    /// zig-zag polyline is exactly what made the old version look like a stick.
    private func boltPath(from start: CGPoint,
                          angle: Double,
                          length: CGFloat,
                          seed: Double,
                          depthLeft: Int,
                          into paths: inout [(Path, CGFloat)]) {
        guard depthLeft > 0, length > 8 else { return }

        var path = Path()
        path.move(to: start)

        var point = start
        var heading = angle
        let segments = 5
        let segLength = length / CGFloat(segments)

        // Clamp toward straight-down. Without this the accumulated jitter could
        // rotate a bolt past horizontal, so strikes drifted sideways instead of
        // falling from the sky.
        let downward = Double.pi / 2
        for i in 0..<segments {
            heading += (noise(seed + Double(i) * 3.1, Double(depthLeft)) - 0.5) * 0.8
            heading = min(max(heading, downward - 0.55), downward + 0.55)
            point = CGPoint(x: point.x + CGFloat(cos(heading)) * segLength,
                            y: point.y + CGFloat(sin(heading)) * segLength)
            path.addLine(to: point)

            // Fork off a thinner, shorter tributary.
            if depthLeft > 1, noise(seed + Double(i) * 7.7, 2) > 0.7 {
                boltPath(from: point,
                         angle: heading + (noise(seed + Double(i), 5) - 0.5) * 1.1,
                         length: length * 0.45,
                         seed: seed + Double(i) * 13.3,
                         depthLeft: depthLeft - 1,
                         into: &paths)
            }
        }
        paths.append((path, CGFloat(depthLeft) * 2.1))   // trunk thick, branches thin
    }

    private func drawLightning(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        var totalFlash = 0.0

        for p in particles.prefix(count(4)) {
            let period = 1.6 + p.speed
            let cycle = (t * 0.9 + p.phase).truncatingRemainder(dividingBy: period)
            let window = 0.42
            guard cycle < window else { continue }

            // Multi-flicker envelope: strike, dip, re-strike, decay.
            let u = cycle / window
            let envelope = (1 - u) * (0.55 + 0.45 * abs(sin(u * 18)))
            let alpha = envelope * alphaScale

            // Re-seed per strike so every bolt is a different shape.
            let strikeIndex = floor((t * 0.9 + p.phase) / period)
            let seed = p.phase * 31 + strikeIndex * 7.13

            var paths: [(Path, CGFloat)] = []
            boltPath(from: CGPoint(x: p.x * size.width, y: -20),
                     angle: .pi / 2 + (noise(seed) - 0.5) * 0.5,
                     length: size.height * 0.85,
                     seed: seed,
                     depthLeft: 3,
                     into: &paths)

            for (path, width) in paths {
                bloomStroke(&ctx, path, color: primary, width: width, alpha: alpha)
            }
            totalFlash += envelope * 0.10
        }

        flash(&ctx, size, color: primary, alpha: min(0.22, totalFlash) * alphaScale)
    }

    // MARK: Laser — glowing neon grid

    private func drawNeonGrid(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let pulse = 0.62 + 0.3 * sin(t * 1.6)
        let cols = 8, rows = 8

        for i in 0...cols {
            let x = size.width * CGFloat(i) / CGFloat(cols)
            let a = pulse * (0.55 + 0.45 * sin(t * 2 + Double(i))) * alphaScale
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            bloomStroke(&ctx, path, color: primary, width: 1.1, alpha: a, core: false)
        }
        for j in 0...rows {
            let y = size.height * CGFloat(j) / CGFloat(rows)
            let a = pulse * (0.55 + 0.45 * sin(t * 2 + Double(j) * 1.3)) * alphaScale
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            bloomStroke(&ctx, path, color: secondary, width: 1.1, alpha: a, core: false)
        }

        // Bright nodes where beams cross.
        for i in 0...cols {
            for j in 0...rows where (i + j).isMultiple(of: 2) {
                let pt = CGPoint(x: size.width * CGFloat(i) / CGFloat(cols),
                                 y: size.height * CGFloat(j) / CGFloat(rows))
                let a = pulse * (0.4 + 0.6 * noise(Double(i) * 3 + Double(j), floor(t * 2))) * alphaScale
                bloomDot(&ctx, at: pt, radius: 7, color: primary, alpha: a * 0.7, hotCore: false)
            }
        }
        vignette(&ctx, size, strength: 0.35)
    }

    // MARK: Cyberpunk — CRT scanlines, sweep band, RGB split

    private func drawScanlines(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let spacing: CGFloat = 4
        let offset = CGFloat((t * 22).truncatingRemainder(dividingBy: Double(spacing)))
        var y = -spacing + offset
        while y < size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(path, with: .color(.white.opacity(0.11 * alphaScale)), lineWidth: 1)
            y += spacing
        }

        // CRT refresh band sweeping down the screen.
        let bandY = CGFloat((t * 0.22).truncatingRemainder(dividingBy: 1)) * size.height
        var band = ctx
        band.blendMode = .plusLighter
        // Wide, soft-edged falloff — the old 120pt block clipped to a hard
        // cyan rectangle instead of reading as a CRT refresh sweep.
        band.fill(
            Path(CGRect(x: 0, y: bandY - 170, width: size.width, height: 340)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: primary.opacity(0.05 * alphaScale), location: 0.35),
                    .init(color: primary.opacity(0.14 * alphaScale), location: 0.5),
                    .init(color: primary.opacity(0.05 * alphaScale), location: 0.65),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: CGPoint(x: 0, y: bandY - 170),
                endPoint: CGPoint(x: 0, y: bandY + 170)
            )
        )

        // RGB-split glitch bars.
        for p in particles.prefix(count(8)) {
            let cycle = (t * 1.7 + p.phase).truncatingRemainder(dividingBy: 1.4)
            guard cycle < 0.16 else { continue }
            let gy = p.y * size.height
            let shift = CGFloat(6 + 10 * noise(p.phase, floor(t * 8)))
            var g = ctx
            g.blendMode = .plusLighter
            g.fill(Path(CGRect(x: -shift, y: gy, width: size.width, height: 5)),
                   with: .color(primary.opacity(0.6 * alphaScale)))
            g.fill(Path(CGRect(x: shift, y: gy + 3, width: size.width, height: 3)),
                   with: .color(secondary.opacity(0.5 * alphaScale)))
            g.fill(Path(CGRect(x: 0, y: gy + 1, width: size.width, height: 2)),
                   with: .color(.white.opacity(0.35 * alphaScale)))
        }
        vignette(&ctx, size, strength: 0.45)
    }

    // MARK: Aurora — light curtains + glass orbs

    private func drawOrbs(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        for i in 0..<3 {
            let phase = t * 0.12 + Double(i) * 1.9
            var path = Path()
            var x: CGFloat = 0
            path.move(to: CGPoint(x: 0, y: size.height * 0.32 + CGFloat(i) * 60))
            while x <= size.width {
                let y = size.height * (0.32 + 0.12 * CGFloat(sin(Double(x) / 110 + phase))) + CGFloat(i) * 60
                path.addLine(to: CGPoint(x: x, y: y))
                x += 18
            }
            bloomStroke(&ctx, path,
                        color: i.isMultiple(of: 2) ? primary : secondary,
                        width: 26, alpha: 0.10 * alphaScale, core: false)
        }

        for (i, p) in particles.prefix(count(7)).enumerated() {
            let angle = t * 0.11 * p.speed + p.phase
            let c = CGPoint(x: p.x * size.width + CGFloat(cos(angle)) * 70,
                            y: p.y * size.height + CGFloat(sin(angle * 0.8)) * 70)
            bloomDot(&ctx, at: c, radius: 90 + p.size * 16,
                     color: i.isMultiple(of: 2) ? primary : secondary,
                     alpha: 0.30 * alphaScale, hotCore: false)
        }
    }

    // MARK: Aurora — borealis curtains over a star field

    /// Real aurora reads as vertical ribbons of light hanging from the sky,
    /// not blurred blobs. Each ribbon is a filled band whose top and bottom
    /// edges wave independently, shaded green→cyan→violet and faded at the
    /// bottom so it dissolves into the night.
    private func drawAuroraCurtains(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        // Night sky behind the curtains.
        for p in particles.prefix(count(30)) {
            let twinkle = 0.25 + 0.5 * abs(sin(t * 0.7 * p.speed + p.phase))
            bloomDot(&ctx, at: CGPoint(x: p.x * size.width, y: p.y * size.height * 0.75),
                     radius: p.size * 0.7, color: .white, alpha: twinkle * 0.5 * alphaScale, hotCore: false)
        }

        let ribbons = max(3, count(5))
        for i in 0..<ribbons {
            let phase = Double(i) * 1.7 + t * 0.22
            let baseX = size.width * (CGFloat(i) + 0.5) / CGFloat(ribbons)
            let width = size.width * 0.22
            let topY = size.height * 0.02
            let bottomY = size.height * (0.55 + 0.18 * CGFloat(sin(phase * 0.6)))

            // Build a closed band with independently waving left/right edges.
            var band = Path()
            let steps = 16
            band.move(to: CGPoint(x: baseX, y: topY))
            for stepIndex in 0...steps {
                let f = CGFloat(stepIndex) / CGFloat(steps)
                let y = topY + (bottomY - topY) * f
                let wobble = CGFloat(sin(Double(f) * 3.4 + phase)) * 26 * f
                band.addLine(to: CGPoint(x: baseX + wobble + width * 0.5 * f, y: y))
            }
            for stepIndex in stride(from: steps, through: 0, by: -1) {
                let f = CGFloat(stepIndex) / CGFloat(steps)
                let y = topY + (bottomY - topY) * f
                let wobble = CGFloat(sin(Double(f) * 3.4 + phase)) * 26 * f
                band.addLine(to: CGPoint(x: baseX + wobble - width * 0.5 * f, y: y))
            }
            band.closeSubpath()

            var c = ctx
            c.blendMode = .plusLighter
            c.fill(
                band,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: primary.opacity(0.42 * alphaScale), location: 0),
                        .init(color: primary.opacity(0.30 * alphaScale), location: 0.35),
                        .init(color: secondary.opacity(0.22 * alphaScale), location: 0.75),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: CGPoint(x: baseX, y: topY),
                    endPoint: CGPoint(x: baseX, y: bottomY)
                )
            )

            // Bright filament running down the spine of each ribbon.
            var spine = Path()
            spine.move(to: CGPoint(x: baseX, y: topY))
            for stepIndex in 0...steps {
                let f = CGFloat(stepIndex) / CGFloat(steps)
                let y = topY + (bottomY - topY) * f
                spine.addLine(to: CGPoint(x: baseX + CGFloat(sin(Double(f) * 3.4 + phase)) * 26 * f, y: y))
            }
            bloomStroke(&ctx, spine, color: primary, width: 2.2, alpha: 0.35 * alphaScale, core: false)
        }
    }

    // MARK: Burning Ember — coal bed + falling ash

    /// A *dying* fire, deliberately inverted from Flame: the heat lives in a
    /// glowing bed at the bottom and cool grey ash falls down through it.
    private func drawEmberBed(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let bedY = size.height * 0.9

        // Radiant heat haze rising off the coal bed.
        var haze = ctx
        haze.blendMode = .plusLighter
        haze.fill(
            Path(CGRect(x: 0, y: bedY - size.height * 0.34, width: size.width, height: size.height * 0.44)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: primary.opacity(0.10 * alphaScale), location: 0.55),
                    .init(color: primary.opacity(0.26 * alphaScale), location: 1)
                ]),
                startPoint: CGPoint(x: 0, y: bedY - size.height * 0.34),
                endPoint: CGPoint(x: 0, y: bedY + size.height * 0.1)
            )
        )

        // Coals: each breathes on its own phase, some flaring hot.
        for p in particles.prefix(count(14)) {
            let breathe = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 0.8 * p.speed + p.phase))
            let flare = noise(floor(t * 0.5) + p.phase) > 0.86 ? 1.7 : 1.0
            let x = p.x * size.width
            let y = bedY + CGFloat(sin(p.phase)) * 16
            bloomDot(&ctx, at: CGPoint(x: x, y: y),
                     radius: (10 + p.size * 4) * CGFloat(flare),
                     color: primary,
                     alpha: breathe * 0.85 * flare * alphaScale)
        }

        // Ash: cool grey flakes tumbling downward — the visual opposite of
        // Flame's rising orange sparks.
        for p in particles.prefix(count(22)) {
            let fall = (t * 0.045 * p.speed + p.phase).truncatingRemainder(dividingBy: 1)
            let y = size.height * CGFloat(fall)
            let sway = CGFloat(sin(t * 0.9 + p.phase * 2)) * 22
            let x = p.x * size.width + sway
            // Fades as it nears the hot bed, as if consumed.
            let alpha = (1 - Double(fall) * 0.75) * 0.5 * alphaScale
            bloomDot(&ctx, at: CGPoint(x: x, y: y), radius: p.size * 1.1,
                     color: secondary, alpha: alpha, hotCore: false)
        }
    }

    // MARK: Dark Matter — stars with diffraction spikes

    private func drawStars(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let drift = CGFloat(t * 1.6)
        for p in particles.prefix(count(46)) {
            var x = (p.x * size.width + drift).truncatingRemainder(dividingBy: size.width)
            var y = (p.y * size.height + drift * 0.6).truncatingRemainder(dividingBy: size.height)
            if x < 0 { x += size.width }
            if y < 0 { y += size.height }
            let point = CGPoint(x: x, y: y)

            let twinkle = 0.35 + 0.65 * abs(sin(t * 0.9 * p.speed + p.phase))
            let alpha = twinkle * 0.9 * alphaScale
            bloomDot(&ctx, at: point, radius: p.size * 1.5, color: .white, alpha: alpha * 0.8)

            // Camera-style diffraction spikes on the brightest stars.
            if p.size > 5 {
                let len = p.size * 5 * CGFloat(twinkle)
                var spikes = Path()
                spikes.move(to: CGPoint(x: x - len, y: y)); spikes.addLine(to: CGPoint(x: x + len, y: y))
                spikes.move(to: CGPoint(x: x, y: y - len)); spikes.addLine(to: CGPoint(x: x, y: y + len))
                bloomStroke(&ctx, spikes, color: .white, width: 0.8, alpha: alpha * 0.55, core: false)
            }
        }
    }

    // MARK: Lava — molten cracks with travelling hot nodes

    private func drawLava(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        for (i, p) in particles.prefix(count(7)).enumerated() {
            let baseY = p.y * size.height
            var path = Path()
            path.move(to: CGPoint(x: -20, y: baseY))
            var x: CGFloat = -20
            var step = 0
            while x < size.width + 20 {
                x += size.width / 7
                let wobble = CGFloat(sin(t * 0.45 + Double(step) * 0.9 + p.phase)) * 26
                    + CGFloat(sin(t * 0.17 + Double(step) * 2.2)) * 12
                path.addLine(to: CGPoint(x: x, y: baseY + wobble))
                step += 1
            }

            let heat = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 0.75 + p.phase))
            let color = i.isMultiple(of: 2) ? primary : secondary
            bloomStroke(&ctx, path, color: color, width: 3.4, alpha: heat * alphaScale, core: false)

            let travel = (t * 0.09 * p.speed + p.phase).truncatingRemainder(dividingBy: 1)
            let nx = CGFloat(travel) * size.width
            let ny = baseY + CGFloat(sin(t * 0.45 + Double(travel) * 6 + p.phase)) * 26
            bloomDot(&ctx, at: CGPoint(x: nx, y: ny), radius: 16, color: color, alpha: heat * 0.9 * alphaScale)
        }
    }

    // MARK: Neon 80s — synthwave horizon with sliced sun

    private func drawRetroGrid(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let horizon = size.height * 0.55
        let opacity = (0.5 + 0.16 * sin(t * 1.2)) * alphaScale

        let sunR = size.width * 0.26
        let sunC = CGPoint(x: size.width / 2, y: horizon - sunR * 0.45)
        var sun = ctx
        sun.blendMode = .plusLighter
        sun.fill(
            Path(ellipseIn: CGRect(x: sunC.x - sunR, y: sunC.y - sunR, width: sunR * 2, height: sunR * 2)),
            with: .linearGradient(
                Gradient(colors: [secondary.opacity(0.75 * alphaScale), primary.opacity(0.85 * alphaScale)]),
                startPoint: CGPoint(x: sunC.x, y: sunC.y - sunR),
                endPoint: CGPoint(x: sunC.x, y: sunC.y + sunR)
            )
        )
        // Classic horizontal slices through the lower half of the sun.
        var slice: CGFloat = 6
        while slice < sunR * 1.1 {
            ctx.fill(Path(CGRect(x: sunC.x - sunR, y: sunC.y + slice, width: sunR * 2, height: slice * 0.16 + 1.5)),
                     with: .color(.black.opacity(0.85)))
            slice *= 1.32
        }

        for i in -6...6 {
            var path = Path()
            path.move(to: CGPoint(x: size.width / 2, y: horizon))
            path.addLine(to: CGPoint(x: size.width / 2 + CGFloat(i) * size.width / 5, y: size.height))
            bloomStroke(&ctx, path, color: secondary, width: 1.0, alpha: opacity * 0.8, core: false)
        }

        let scroll = CGFloat((t * 0.4).truncatingRemainder(dividingBy: 1))
        for i in 0..<11 {
            let f = (CGFloat(i) + scroll) / 11
            let y = horizon + (size.height - horizon) * f * f
            guard y <= size.height else { continue }
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            bloomStroke(&ctx, path, color: secondary, width: 1.0, alpha: opacity * Double(0.35 + f), core: false)
        }

        var hz = Path()
        hz.move(to: CGPoint(x: 0, y: horizon)); hz.addLine(to: CGPoint(x: size.width, y: horizon))
        bloomStroke(&ctx, hz, color: primary, width: 2, alpha: 0.7 * alphaScale)
    }

    // MARK: Galaxy — nebula clouds + star flares

    private func drawSparkles(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        for i in 0..<3 {
            let a = t * 0.05 + Double(i) * 2.2
            let c = CGPoint(x: size.width * (0.25 + 0.5 * CGFloat(0.5 + 0.5 * sin(a))),
                            y: size.height * (0.3 + 0.4 * CGFloat(0.5 + 0.5 * cos(a * 0.7))))
            bloomDot(&ctx, at: c, radius: size.width * 0.42,
                     color: i.isMultiple(of: 2) ? primary : secondary,
                     alpha: 0.13 * alphaScale, hotCore: false)
        }

        for p in particles.prefix(count(52)) {
            let twinkle = 0.25 + 0.75 * abs(sin(t * 1.25 * p.speed + p.phase))
            let point = CGPoint(x: p.x * size.width, y: p.y * size.height)
            let alpha = twinkle * alphaScale
            let color = p.phase > 3.2 ? primary : Color.white

            bloomDot(&ctx, at: point, radius: p.size * 1.4, color: color, alpha: alpha * 0.85)

            if twinkle > 0.75 {
                let len = p.size * 4 * CGFloat(twinkle)
                var star = Path()
                star.move(to: CGPoint(x: point.x - len, y: point.y)); star.addLine(to: CGPoint(x: point.x + len, y: point.y))
                star.move(to: CGPoint(x: point.x, y: point.y - len)); star.addLine(to: CGPoint(x: point.x, y: point.y + len))
                bloomStroke(&ctx, star, color: color, width: 0.9, alpha: alpha * 0.7, core: false)
            }
        }
    }
}

// MARK: - Themed Background

/// Gradient + parallax particle planes for the current theme.
struct ThemedBackground: View {
    @ObservedObject private var settings = AppSettings.shared
    let configuration: ThemeConfiguration

    var body: some View {
        ZStack {
            configuration.backgroundGradient
                .ignoresSafeArea()

            if settings.effectIntensity != .off {
                Group {
                if settings.parallaxEnabled {
                    ThemeParticles(
                        configuration: configuration.particles,
                        primary: configuration.primary,
                        secondary: configuration.secondary,
                        depth: 0.3,
                        intensity: settings.effectIntensity.opacityScale,
                        speed: settings.animationSpeed.scale
                    )
                    .scaleEffect(1.3)
                    .blur(radius: 2.5)
                }

                ThemeParticles(
                    configuration: configuration.particles,
                    primary: configuration.primary,
                    secondary: configuration.secondary,
                    depth: 1,
                    intensity: settings.effectIntensity.opacityScale,
                    speed: settings.animationSpeed.scale
                )
                }
                // User-controlled softening, 0–100% → 0–28pt.
                .blur(radius: CGFloat(settings.backgroundBlur) * 0.28)
            }
        }
        .id(configuration.theme)
        .transition(.opacity)
    }
}

#Preview {
    ThemedBackground(configuration: ThemeProvider().configuration(for: .lightning))
}
