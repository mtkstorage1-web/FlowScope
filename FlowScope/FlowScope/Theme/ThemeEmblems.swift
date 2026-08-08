//
//  ThemeEmblems.swift
//  FlowScope
//
//  Vector chest emblems that sit inside the timer ring.
//
//  Every path here is drawn from scratch in a unit (0...1) square and scaled
//  to whatever size the caller asks for, so one emblem serves the 280pt timer
//  ring, the 120pt settings preview and the 58pt theme swatch without assets
//  and without a single bitmap in the bundle.
//
//  These are original stylized marks in each character's visual language —
//  not reproductions of the published logos.
//

import SwiftUI

// MARK: - Emblem

enum ThemeEmblem: String, Equatable, CaseIterable {
    case superman, batman, nightwing, deathstroke, redHood
}

// MARK: - Unit-space path helper

/// Builds a path from unit coordinates so every emblem is resolution-free.
private struct UnitPath {
    let rect: CGRect
    var path = Path()

    init(_ rect: CGRect) { self.rect = rect }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }

    mutating func move(_ x: CGFloat, _ y: CGFloat) { path.move(to: p(x, y)) }
    mutating func line(_ x: CGFloat, _ y: CGFloat) { path.addLine(to: p(x, y)) }

    mutating func curve(_ x: CGFloat, _ y: CGFloat,
                        _ c1x: CGFloat, _ c1y: CGFloat,
                        _ c2x: CGFloat, _ c2y: CGFloat) {
        path.addCurve(to: p(x, y), control1: p(c1x, c1y), control2: p(c2x, c2y))
    }

    mutating func quad(_ x: CGFloat, _ y: CGFloat, _ cx: CGFloat, _ cy: CGFloat) {
        path.addQuadCurve(to: p(x, y), control: p(cx, cy))
    }

    /// Straight-line run. The angular emblems are pure polygons, so listing
    /// their vertices beats a wall of `line(_:_:)` calls.
    mutating func polygon(_ points: [(CGFloat, CGFloat)], startNew: Bool = true) {
        guard let first = points.first else { return }
        if startNew { move(first.0, first.1) } else { line(first.0, first.1) }
        for pt in points.dropFirst() { line(pt.0, pt.1) }
    }

    mutating func close() { path.closeSubpath() }
}

/// Mirrors a run of unit points across the vertical centerline.
private func mirrored(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
    points.map { (1 - $0.0, $0.1) }
}

/// Fits a square inside the given rect so emblems never stretch.
private func squared(_ rect: CGRect) -> CGRect {
    let side = min(rect.width, rect.height)
    return CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
}

// MARK: - Superman

/// The shield, as a diamond: a peak at the top, the widest points at the
/// shoulders about a third of the way down, then long straight flanks running
/// to a single bottom point.
///
/// Not a pentagon with a flat top — that reads as a crest, and it was the main
/// thing making the mark look wrong next to the real logo. Control points sit
/// close to each chord so the edges stay near-straight with only the corners
/// softened.
struct SupermanShield: Shape {
    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))
        u.move(0.500, 0.105)                                    // top peak
        u.curve(0.955, 0.330, 0.700, 0.150, 0.905, 0.255)       // right shoulder
        u.curve(0.500, 0.960, 0.900, 0.530, 0.700, 0.790)       // right flank to the point
        u.curve(0.045, 0.330, 0.300, 0.790, 0.100, 0.530)       // left flank
        u.curve(0.500, 0.105, 0.095, 0.255, 0.300, 0.150)       // left shoulder
        u.close()
        return u.path
    }
}

/// Centreline of the S, stroked into a ribbon by `SupermanSMark`.
///
/// The control points stay inside the curve's own turn — pulling them further
/// out (the obvious way to get a tighter hook) makes the stroke fold back on
/// itself and grow a spur off the left flank.
struct SupermanS: Shape {
    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))
        // Tuned to clear the shield's flanks once stroked at 0.145 wide. The
        // shield narrows fast below the shoulders, so the bottom hook has to
        // finish well inside 0.36 or it punches out through the left flank.
        u.move(0.675, 0.315)
        u.curve(0.355, 0.330, 0.585, 0.248, 0.415, 0.248)   // top hook, sweeping left
        u.curve(0.640, 0.515, 0.305, 0.418, 0.505, 0.430)   // diagonal down to the right
        u.curve(0.360, 0.645, 0.710, 0.598, 0.505, 0.710)   // bottom hook, back left
        return u.path
    }
}

// MARK: - Batman

/// Wide bat silhouette: two pointed ears, scalloped wings, a single body point.
///
/// Kept deliberately low and wide (all of it lives between y 0.22 and y 0.68).
/// A taller, more tapered version reads as a moth — the width is what makes it
/// a bat.
/// Wide, low and entirely straight-edged: wings that rise from a sharp tip to a
/// high shoulder then step back down toward a narrow head, two small close-set
/// ears, and a flat-bottomed body.
///
/// Everything sits between y 0.35 and 0.65 of the square — the silhouette is
/// roughly 3:1, and squeezing it any taller is what kept turning it into a moth
/// or an EKG trace in earlier passes.
struct BatSilhouette: Shape {

    /// Top edge, left wing tip → just short of centre.
    private static let leftTop: [(CGFloat, CGFloat)] = [
        (0.000, 0.438),          // wing tip
        (0.265, 0.361),          // shoulder
        (0.360, 0.407),
        (0.425, 0.432),
        (0.450, 0.432),
        (0.468, 0.351),          // ear
        (0.486, 0.426)
    ]

    /// Underside of the left wing, body → tip.
    private static let leftUnderside: [(CGFloat, CGFloat)] = [
        (0.415, 0.649),          // corner of the flat body
        (0.330, 0.568),
        (0.215, 0.581),
        (0.150, 0.506),
        (0.000, 0.438)
    ]

    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))

        var walk = Self.leftTop
        walk += [(0.500, 0.444)]                              // notch between ears
        walk += mirrored(Self.leftTop).reversed()             // right half of the top
        walk += mirrored(Self.leftUnderside).reversed().dropFirst()
        walk += Self.leftUnderside                            // flat body, then out

        u.polygon(walk)
        u.close()
        return u.path
    }
}

// MARK: - Nightwing

/// A bird in a dive: two long wings sweeping up and out to sharp tips, feather
/// serrations along the undersides, and a body that tapers to a tail spike.
///
/// One continuous polygon — the wings are not separate shapes, which is what
/// keeps the silhouette reading as a single bird rather than two arrows.
struct NightwingWings: Shape {

    /// Underside of the left wing, walked from the body outward to the tip.
    /// Each dip/rise pair is one feather serration.
    private static let leftUnderside: [(CGFloat, CGFloat)] = [
        (0.455, 0.600),
        (0.442, 0.665), (0.428, 0.585),
        (0.375, 0.545),
        (0.365, 0.600), (0.352, 0.530),
        (0.300, 0.490),
        (0.290, 0.535), (0.278, 0.475),
        (0.220, 0.435),
        (0.212, 0.472), (0.200, 0.420),
        (0.130, 0.375),
        (0.122, 0.405), (0.112, 0.363),
        (0.000, 0.260)
    ]

    /// Top edge, left tip → head apex → right tip.
    private static let topEdge: [(CGFloat, CGFloat)] = [
        (0.000, 0.260),
        (0.230, 0.250), (0.225, 0.295),          // notch under the left tip
        (0.455, 0.395), (0.472, 0.375), (0.487, 0.352),
        (0.500, 0.345),                           // head apex
        (0.513, 0.352), (0.528, 0.375), (0.545, 0.395),
        (0.775, 0.295), (0.770, 0.250),
        (1.000, 0.260)
    ]

    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))

        // Clockwise: top edge out to the right tip, back along the right
        // underside, down the tail, then out along the left underside.
        var walk = Self.topEdge
        walk += mirrored(Self.leftUnderside).reversed().dropFirst()   // right underside, tip → body
        walk += [(0.522, 0.740), (0.500, 0.980), (0.478, 0.740)]      // tail spike
        walk += Self.leftUnderside

        u.polygon(walk)
        u.close()
        return u.path
    }
}

// MARK: - Deathstroke

// The real mark is a crosshair, not a portrait: a circle split down the middle,
// tech reticle on the dark half, one eye on the light half.

/// Body of the emblem.
struct DeathstrokeCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let s = squared(rect)
        return Circle().path(in: s.insetBy(dx: s.width * 0.10, dy: s.height * 0.10))
    }
}

/// The crosshair rules — vertical through the split, horizontal at eye level.
/// Both overshoot the circle, which is what makes it read as a scope.
struct DeathstrokeCrosshair: Shape {
    enum Arm { case vertical, leftHorizontal, rightHorizontal }
    let arm: Arm

    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))
        let t: CGFloat = 0.022   // half-thickness
        switch arm {
        case .vertical:
            u.polygon([(0.5 - t, 0.02), (0.5 + t, 0.02), (0.5 + t, 0.98), (0.5 - t, 0.98)])
        case .leftHorizontal:
            u.polygon([(0.04, 0.52 - t), (0.50, 0.52 - t), (0.50, 0.52 + t), (0.04, 0.52 + t)])
        case .rightHorizontal:
            u.polygon([(0.50, 0.52 - t), (0.96, 0.52 - t), (0.96, 0.52 + t), (0.50, 0.52 + t)])
        }
        u.close()
        return u.path
    }
}

/// Stepped circuit traces on the dark half. Drawn open and stroked — at swatch
/// size this blurs into "tech detail", which is exactly its job.
struct DeathstrokeReticle: Shape {
    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))
        u.polygon([(0.27, 0.36), (0.40, 0.36), (0.40, 0.66)])
        u.polygon([(0.19, 0.52), (0.34, 0.52)])
        u.polygon([(0.24, 0.66), (0.40, 0.66)])
        u.polygon([(0.30, 0.42), (0.36, 0.42), (0.36, 0.48), (0.30, 0.48), (0.30, 0.42)])
        return u.path
    }
}

/// The single eye, tilted, with a tail that flicks up past the socket.
struct DeathstrokeEye: Shape {
    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))
        u.move(0.50, 0.600)
        u.curve(0.80, 0.435, 0.585, 0.535, 0.695, 0.445)   // upper lid
        u.curve(0.50, 0.600, 0.735, 0.515, 0.600, 0.605)   // lower lid
        u.close()
        return u.path
    }
}

/// The brow flick past the eye's outer corner.
struct DeathstrokeBrow: Shape {
    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))
        u.move(0.755, 0.455)
        u.curve(0.865, 0.330, 0.815, 0.420, 0.850, 0.370)
        u.curve(0.790, 0.470, 0.845, 0.395, 0.805, 0.430)
        u.close()
        return u.path
    }
}

// MARK: - Red Hood

/// Red Hood's chest mark: a bat, but a fully angular one — every edge is a
/// straight line and the wings step rather than scallop. That hard geometry is
/// what separates it from Batman's silhouette.
struct RedHoodBat: Shape {

    /// Top edge, left tip → centre ears → right tip.
    private static let topEdge: [(CGFloat, CGFloat)] = [
        (0.00, 0.46),
        (0.18, 0.29),                 // left shoulder
        (0.41, 0.37),                 // valley
        (0.45, 0.29),                 // left ear
        (0.50, 0.34),                 // centre notch
        (0.55, 0.29),                 // right ear
        (0.59, 0.37),                 // valley
        (0.82, 0.29),                 // right shoulder
        (1.00, 0.46)
    ]

    /// Underside of the left wing, walked from the body outward to the tip,
    /// including the small downward tooth.
    private static let leftUnderside: [(CGFloat, CGFloat)] = [
        (0.335, 0.570), (0.315, 0.612), (0.300, 0.570),
        (0.160, 0.520),
        (0.000, 0.460)
    ]

    func path(in rect: CGRect) -> Path {
        var u = UnitPath(squared(rect))

        var walk = Self.topEdge
        walk += mirrored(Self.leftUnderside).reversed().dropFirst()   // right underside
        walk += [(0.50, 0.72)]                                        // body point
        walk += Self.leftUnderside

        u.polygon(walk)
        u.close()
        return u.path
    }
}


// MARK: - Split Plate

/// The house style for every emblem: a two-tone plate split down the middle,
/// with the mark inverting as it crosses the seam — dark on the accent half,
/// accent on the dark half.
///
/// Deliberately flat. Depth comes from a restrained top-to-bottom gradient
/// inside each half and a hairline groove where the mark meets the field —
/// never from bevels, bloom or gloss, which is what made the first pass read
/// as a sticker instead of a mark.
struct SplitPlate<Field: Shape, Mark: Shape>: View {
    let field: Field
    let mark: Mark
    let accent: Color
    let size: CGFloat
    /// Shrinks the mark inside the plate. Marks drawn edge-to-edge in their own
    /// unit square get their wing tips shaved off by a circular field.
    var markScale: CGFloat = 1

    var body: some View {
        ZStack {
            half(field.fill(Self.accentFill(accent)), .leading)
            half(field.fill(Self.shadeFill), .trailing)
            // Hairline so the shadowed half separates from a black backdrop.
            field.stroke(accent.opacity(0.45), lineWidth: max(0.75, size * 0.008))

            // The mark inverts across the seam. Scaling happens before the
            // mask so the seam stays on the plate's centreline either way.
            half(mark.fill(Self.shadeFill).scaleEffect(markScale), .leading)
            half(mark.fill(Self.accentFill(accent)).scaleEffect(markScale), .trailing)

            // Groove between mark and field, mirrored the same way.
            half(mark.stroke(accent.opacity(0.55), lineWidth: max(0.6, size * 0.007))
                    .scaleEffect(markScale), .leading)
            half(mark.stroke(Color(white: 0.05).opacity(0.65), lineWidth: max(0.6, size * 0.007))
                    .scaleEffect(markScale), .trailing)
        }
    }

    /// Clips a layer to one side of the seam.
    private func half<V: View>(_ view: V, _ edge: Alignment) -> some View {
        view.mask(alignment: edge) {
            Rectangle().frame(width: size / 2)
        }
    }

    static func accentFill(_ accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [accent.mixed(with: .white, amount: 0.12),
                     accent.mixed(with: .black, amount: 0.30)],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Kept off pure black so the plate still reads against a black backdrop.
    static var shadeFill: LinearGradient {
        LinearGradient(colors: [Color(white: 0.21), Color(white: 0.07)],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Emblem View

/// Renders an emblem in the active theme's colors.
///
/// Sits behind the timer's cycle readout, so the caller drops `strength` to a
/// watermark while a session runs and raises it when the ring centre is empty.
struct ThemeEmblemView: View {
    let emblem: ThemeEmblem
    let config: ThemeConfiguration
    var size: CGFloat = 160
    var strength: Double = 0.4
    /// True while the timer is running — lights the emblem's edge.
    var isLive: Bool = false

    var body: some View {
        ZStack {
            content
                .opacity(strength)
                // Weight, not bloom — enough to lift the plate off the backdrop.
                .shadow(color: .black.opacity(0.55), radius: size * 0.03, y: size * 0.012)

            if isLive {
                EdgeLight(shape: outline, size: size, tint: accent)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(config.transition.animation, value: config.theme)
    }

    /// The silhouette the running lights travel around. Type-erased so all five
    /// emblems can feed one animator.
    private var outline: AnyShape {
        switch emblem {
        case .superman:    AnyShape(SupermanShield())
        case .batman:      AnyShape(BatSilhouette())
        case .nightwing:   AnyShape(NightwingWings())
        case .deathstroke: AnyShape(PlateDisc())
        case .redHood:     AnyShape(RedHoodBat())
        }
    }

    /// Superman's accent is the red of the S; everyone else rides their theme
    /// accent, which is already the color the character is known by.
    private var accent: Color {
        emblem == .superman ? config.secondary : config.primary
    }

    /// The gold Superman uses for its border and its S. Lives in the theme's
    /// digit ramp already, so it stays in step with any recolouring.
    private var gold: Color { config.digits.gradientColors.first ?? .yellow }

    @ViewBuilder
    private var content: some View {
        switch emblem {
        case .superman:
            superman
        case .batman:
            // Black body, gold edge — the mark from the reference, not a split.
            solidMark(BatSilhouette(),
                      body: Color(white: 0.12),
                      edge: config.primary,
                      edgeWidth: 0.030,
                      seed: 21,
                      glow: true)
        case .nightwing:
            solidMark(NightwingWings(),
                      body: config.primary,
                      edge: config.primary.mixed(with: .white, amount: 0.55),
                      edgeWidth: 0.016,
                      seed: 37)
        case .redHood:
            solidMark(RedHoodBat(),
                      body: config.primary,
                      edge: config.primary.mixed(with: .black, amount: 0.55),
                      edgeWidth: 0.018,
                      seed: 53)
        case .deathstroke:
            deathstroke
        }
    }

    /// A single-colour mark: shaded body, worn surface, defined edge.
    private func solidMark<S: Shape>(_ shape: S,
                                     body: Color,
                                     edge: Color,
                                     edgeWidth: CGFloat,
                                     seed: Int,
                                     glow: Bool = false) -> some View {
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [body.mixed(with: .white, amount: 0.16),
                             body.mixed(with: .black, amount: 0.32)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            EmblemTexture(seed: seed).mask(shape).blendMode(.overlay)

            shape.stroke(edge, lineWidth: max(0.8, size * edgeWidth))
                .shadow(color: glow ? edge.opacity(0.7) : .clear, radius: size * 0.035)
        }
    }

    /// Red field, gold border, gold S — struck like the reference, with the
    /// border stroked rather than inset so it keeps an even weight all the way
    /// round the shield instead of thinning out at the point.
    private var superman: some View {
        ZStack {
            // Deep maroon, not the theme's bright red — the field in the real
            // mark is dark enough that the gold reads as the brighter element.
            SupermanShield().fill(
                LinearGradient(
                    colors: [config.secondary.mixed(with: .black, amount: 0.42),
                             config.secondary.mixed(with: .black, amount: 0.72)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            EmblemTexture(seed: 11).mask(SupermanShield()).blendMode(.overlay)

            SupermanShield()
                .stroke(goldRamp, lineWidth: size * 0.052)
            SupermanShield()
                .stroke(gold.mixed(with: .white, amount: 0.5).opacity(0.8),
                        lineWidth: max(0.7, size * 0.008))

            SupermanSMark().fill(goldRamp)
        }
    }

    private var goldRamp: LinearGradient {
        LinearGradient(
            colors: [gold.mixed(with: .white, amount: 0.35),
                     gold,
                     gold.mixed(with: .black, amount: 0.40)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Deathstroke already *is* a split plate, but its halves run the other way
    /// round: the reticle lives on the shadowed left, the eye on the lit right.
    /// Its crosshair is also drawn per-arm rather than inverted across the seam
    /// — running it through the shared mark doubled the rule right on the join.
    private var deathstroke: some View {
        let accentFill = SplitPlate<PlateDisc, PlateDisc>.accentFill(accent)
        let shadeFill = SplitPlate<PlateDisc, PlateDisc>.shadeFill
        let ink = Color(white: 0.05)

        return ZStack {
            PlateDisc().fill(shadeFill)
                .mask(alignment: .leading) { Rectangle().frame(width: size / 2) }
            PlateDisc().fill(accentFill)
                .mask(alignment: .trailing) { Rectangle().frame(width: size / 2) }
            PlateDisc().stroke(accent.opacity(0.45), lineWidth: max(0.75, size * 0.008))

            DeathstrokeReticle()
                .stroke(accentFill, style: StrokeStyle(lineWidth: size * 0.024, lineJoin: .miter))

            DeathstrokeCrosshair(arm: .vertical).fill(accentFill)
            DeathstrokeCrosshair(arm: .leftHorizontal).fill(accentFill)
            DeathstrokeCrosshair(arm: .rightHorizontal).fill(ink)

            DeathstrokeBrow().fill(ink)
            DeathstrokeEye().fill(Color(white: 0.94))
            DeathstrokeEye()
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.028, lineJoin: .round))
        }
    }
}

// MARK: - Running edge light

/// White light chasing around an emblem's outline while the timer runs.
///
/// Built from `trim(from:to:)` on the silhouette, so it follows whatever shape
/// it's handed rather than needing a per-emblem path of light points. Two
/// runners sit half a lap apart so there is always one in view no matter which
/// way the emblem is facing.
///
/// The comet is three nested trims of decreasing length and increasing
/// brightness — a single stroke reads as a moving dash, and the taper is what
/// makes it read as light travelling along an edge.
struct EdgeLight<S: Shape>: View {
    let shape: S
    let size: CGFloat
    var tint: Color
    var runners: Int = 2
    var lapsPerSecond: Double = 0.22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let lap = timeline.date.timeIntervalSinceReferenceDate * lapsPerSecond
            let breathe = 0.72 + 0.28 * sin(timeline.date.timeIntervalSinceReferenceDate * 2.2)

            ZStack {
                // Standing rim glow so the whole mark reads as energised, not
                // just the moving highlight.
                shape
                    .stroke(tint, lineWidth: size * 0.022)
                    .blur(radius: size * 0.035)
                    .opacity(0.55 + 0.35 * breathe)

                ForEach(0..<runners, id: \.self) { index in
                    let head = (lap + Double(index) / Double(runners))
                        .truncatingRemainder(dividingBy: 1)
                    comet(head: head)
                }
            }
            .shadow(color: .white.opacity(0.55), radius: size * 0.05)
            .shadow(color: tint.opacity(0.7), radius: size * 0.09)
        }
    }

    /// Tail → body → hot head, each shorter and brighter than the last.
    @ViewBuilder
    private func comet(head: Double) -> some View {
        arc(head: head, length: 0.30, width: size * 0.020, color: .white.opacity(0.22))
        arc(head: head, length: 0.15, width: size * 0.024, color: .white.opacity(0.60))
        arc(head: head, length: 0.05, width: size * 0.030, color: .white)
    }

    /// Draws the trailing window, split into two strokes when it crosses the
    /// path's start — `trim` can't express a wrapped range on its own.
    @ViewBuilder
    private func arc(head: Double, length: Double, width: CGFloat, color: Color) -> some View {
        let tail = head - length
        if tail < 0 {
            shape.trim(from: 0, to: CGFloat(head))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
            shape.trim(from: CGFloat(1 + tail), to: 1)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
        } else {
            shape.trim(from: CGFloat(tail), to: CGFloat(head))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }
}

// MARK: - Surface texture

/// Wear on a struck-metal surface: broad mottling plus fine scratches.
///
/// Drawn once and composited with `.overlay`, which lightens where the base is
/// light and darkens where it's dark — so one texture serves a red shield, a
/// black bat and a blue bird without being retinted for each.
///
/// Everything is derived from a hash of the index, so a given `seed` always
/// produces the same wear pattern and the emblem never crawls between frames.
struct EmblemTexture: View {
    var seed: Int

    private func rand(_ index: Int, _ salt: Int) -> Double {
        abs(sin(Double(index &* 37 &+ seed &* 91 &+ salt &* 7) * 12.9898) * 43758.5453)
            .truncatingRemainder(dividingBy: 1)
    }

    var body: some View {
        Canvas { ctx, size in
            let span = min(size.width, size.height)

            // Broad mottling — the cloudiness of cast or brushed metal.
            for i in 0..<16 {
                let r = span * CGFloat(0.10 + 0.22 * rand(i, 1))
                let c = CGPoint(x: size.width * CGFloat(rand(i, 2)),
                                y: size.height * CGFloat(rand(i, 3)))
                let light = rand(i, 4) > 0.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(
                        Gradient(colors: [
                            (light ? Color.white : Color.black).opacity(0.16),
                            .clear
                        ]),
                        center: c, startRadius: 0, endRadius: r
                    )
                )
            }

            // Fine scratches, all raked within a narrow angle band so they read
            // as tooling marks rather than random noise.
            for i in 0..<46 {
                let angle = (-0.55 + 0.5 * rand(i, 5)) * Double.pi
                let length = span * CGFloat(0.12 + 0.55 * rand(i, 6))
                let start = CGPoint(x: size.width * CGFloat(rand(i, 7)),
                                    y: size.height * CGFloat(rand(i, 8)))
                var line = Path()
                line.move(to: start)
                line.addLine(to: CGPoint(x: start.x + length * CGFloat(cos(angle)),
                                         y: start.y + length * CGFloat(sin(angle))))
                let light = rand(i, 9) > 0.45
                ctx.stroke(
                    line,
                    with: .color((light ? Color.white : Color.black)
                        .opacity(0.05 + 0.09 * rand(i, 10))),
                    style: StrokeStyle(lineWidth: 0.5 + CGFloat(rand(i, 11)), lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// The disc Deathstroke is struck on.
struct PlateDisc: Shape {
    func path(in rect: CGRect) -> Path {
        let s = squared(rect)
        return Circle().path(in: s.insetBy(dx: s.width * 0.02, dy: s.height * 0.02))
    }
}

/// The S as a filled mark rather than a stroked ribbon, so its terminals stay
/// hard-edged at any size.
struct SupermanSMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = squared(rect)
        return SupermanS()
            .path(in: s)
            .strokedPath(StrokeStyle(lineWidth: s.width * 0.145, lineCap: .butt, lineJoin: .round))
    }
}

