using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;
using Windows.UI;

namespace FlowScopeWindows.Theme;

/// <summary>
/// Vector chest emblems that sit inside the timer ring, ported from
/// ThemeEmblems.swift (and matching ThemeEmblems.kt on Android).
///
/// Every path is built from unit (0..1) coordinates and scaled to whatever
/// size the caller asks for, so one emblem serves the 340px timer ring and a
/// small settings swatch without a single bitmap in the build output.
///
/// These are original stylized marks in each character's visual language —
/// not reproductions of the published logos.
///
/// Fidelity note: the Apple build overlays a struck-metal wear texture (16
/// mottling blobs + 46 scratches per emblem). That is cheap on an immediate-
/// mode Canvas and expensive in XAML's retained tree, so this build keeps the
/// shaded body and defined edge and drops the texture — the same trade the
/// Windows particle field already makes.
/// </summary>
public static class ThemeEmblems
{
    // MARK: - Unit-space helpers

    /// <summary>Builds paths from unit coordinates so every emblem is resolution-free.</summary>
    private sealed class UnitPath
    {
        private readonly double _size;
        private readonly PathFigure _figure = new() { IsFilled = true };

        public UnitPath(double size) => _size = size;

        private Point P(double x, double y) => new(x * _size, y * _size);

        public void Move(double x, double y) => _figure.StartPoint = P(x, y);

        public void Line(double x, double y) => _figure.Segments.Add(new LineSegment { Point = P(x, y) });

        public void Curve(double x, double y, double c1x, double c1y, double c2x, double c2y) =>
            _figure.Segments.Add(new BezierSegment
            {
                Point1 = P(c1x, c1y),
                Point2 = P(c2x, c2y),
                Point3 = P(x, y),
            });

        /// <summary>
        /// Straight-line run. The angular emblems are pure polygons, so listing
        /// their vertices beats a wall of <see cref="Line"/> calls.
        /// </summary>
        public void Polygon(IReadOnlyList<(double X, double Y)> points, bool startNew = true)
        {
            if (points.Count == 0) return;

            var first = points[0];
            if (startNew) Move(first.X, first.Y);
            else Line(first.X, first.Y);

            var run = new PointCollection();
            for (var i = 1; i < points.Count; i++) run.Add(P(points[i].X, points[i].Y));
            _figure.Segments.Add(new PolyLineSegment { Points = run });
        }

        public PathGeometry Close(bool closed = true)
        {
            _figure.IsClosed = closed;
            var geometry = new PathGeometry();
            geometry.Figures.Add(_figure);
            return geometry;
        }
    }

    /// <summary>Mirrors a run of unit points across the vertical centreline.</summary>
    private static List<(double X, double Y)> Mirrored(IEnumerable<(double X, double Y)> points) =>
        points.Select(p => (1 - p.X, p.Y)).ToList();

    private static List<(double X, double Y)> Reversed(IEnumerable<(double X, double Y)> points) =>
        points.Reverse().ToList();

    // MARK: - Superman

    /// <summary>
    /// The shield, as a diamond: a peak at the top, the widest points at the
    /// shoulders about a third of the way down, then long straight flanks
    /// running to a single bottom point.
    ///
    /// Not a pentagon with a flat top — that reads as a crest. Control points
    /// sit close to each chord so the edges stay near-straight with only the
    /// corners softened.
    /// </summary>
    private static PathGeometry SupermanShield(double s)
    {
        var u = new UnitPath(s);
        u.Move(0.500, 0.105);                                  // top peak
        u.Curve(0.955, 0.330, 0.700, 0.150, 0.905, 0.255);     // right shoulder
        u.Curve(0.500, 0.960, 0.900, 0.530, 0.700, 0.790);     // right flank to the point
        u.Curve(0.045, 0.330, 0.300, 0.790, 0.100, 0.530);     // left flank
        u.Curve(0.500, 0.105, 0.095, 0.255, 0.300, 0.150);     // left shoulder
        return u.Close();
    }

    /// <summary>
    /// Centreline of the S, stroked into a ribbon by the caller.
    ///
    /// The control points stay inside the curve's own turn — pulling them
    /// further out (the obvious way to get a tighter hook) makes the stroke
    /// fold back on itself and grow a spur off the left flank.
    /// </summary>
    private static PathGeometry SupermanS(double s)
    {
        var u = new UnitPath(s);
        // Tuned to clear the shield's flanks once stroked at 0.145 wide.
        //
        // NOTE: iOS and Android carry a bolder revision of this mark (wider
        // sweep, 0.165 stroke). This build was deliberately left on the
        // original — bring the coordinates across from ThemeEmblems.swift if
        // you want the Windows app to match.
        u.Move(0.675, 0.315);
        u.Curve(0.355, 0.330, 0.585, 0.248, 0.415, 0.248);   // top hook, sweeping left
        u.Curve(0.640, 0.515, 0.305, 0.418, 0.505, 0.430);   // diagonal down to the right
        u.Curve(0.360, 0.645, 0.710, 0.598, 0.505, 0.710);   // bottom hook, back left
        return u.Close(closed: false);
    }

    // MARK: - Batman

    /// <summary>
    /// Wide, low and entirely straight-edged: wings that rise from a sharp tip
    /// to a high shoulder then step back down toward a narrow head, two small
    /// close-set ears, and a flat-bottomed body.
    ///
    /// Everything sits between y 0.35 and 0.65 of the square — the silhouette
    /// is roughly 3:1, and squeezing it any taller turns it into a moth.
    /// </summary>
    private static readonly (double X, double Y)[] BatLeftTop =
    {
        (0.000, 0.438),          // wing tip
        (0.265, 0.361),          // shoulder
        (0.360, 0.407),
        (0.425, 0.432),
        (0.450, 0.432),
        (0.468, 0.351),          // ear
        (0.486, 0.426),
    };

    /// <summary>Underside of the left wing, body to tip.</summary>
    private static readonly (double X, double Y)[] BatLeftUnderside =
    {
        (0.415, 0.649),          // corner of the flat body
        (0.330, 0.568),
        (0.215, 0.581),
        (0.150, 0.506),
        (0.000, 0.438),
    };

    private static PathGeometry BatSilhouette(double s)
    {
        var walk = new List<(double X, double Y)>();
        walk.AddRange(BatLeftTop);
        walk.Add((0.500, 0.444));                                   // notch between ears
        walk.AddRange(Reversed(Mirrored(BatLeftTop)));              // right half of the top
        walk.AddRange(Reversed(Mirrored(BatLeftUnderside)).Skip(1));
        walk.AddRange(BatLeftUnderside);                            // flat body, then out

        var u = new UnitPath(s);
        u.Polygon(walk);
        return u.Close();
    }

    // MARK: - Nightwing

    /// <summary>
    /// A bird in a dive: two long wings sweeping up and out to sharp tips,
    /// feather serrations along the undersides, and a body that tapers to a
    /// tail spike. One continuous polygon — the wings are not separate shapes,
    /// which is what keeps it reading as a bird rather than two arrows.
    ///
    /// Each dip/rise pair along the underside is one feather serration.
    /// </summary>
    private static readonly (double X, double Y)[] NightwingLeftUnderside =
    {
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
        (0.000, 0.260),
    };

    /// <summary>Top edge, left tip to head apex to right tip.</summary>
    private static readonly (double X, double Y)[] NightwingTopEdge =
    {
        (0.000, 0.260),
        (0.230, 0.250), (0.225, 0.295),          // notch under the left tip
        (0.455, 0.395), (0.472, 0.375), (0.487, 0.352),
        (0.500, 0.345),                          // head apex
        (0.513, 0.352), (0.528, 0.375), (0.545, 0.395),
        (0.775, 0.295), (0.770, 0.250),
        (1.000, 0.260),
    };

    private static PathGeometry NightwingWings(double s)
    {
        // Clockwise: top edge out to the right tip, back along the right
        // underside, down the tail, then out along the left underside.
        var walk = new List<(double X, double Y)>();
        walk.AddRange(NightwingTopEdge);
        walk.AddRange(Reversed(Mirrored(NightwingLeftUnderside)).Skip(1));
        walk.AddRange(new (double, double)[] { (0.522, 0.740), (0.500, 0.980), (0.478, 0.740) });
        walk.AddRange(NightwingLeftUnderside);

        var u = new UnitPath(s);
        u.Polygon(walk);
        return u.Close();
    }

    // MARK: - Deathstroke

    // The real mark is a crosshair, not a portrait: a circle split down the
    // middle, tech reticle on the dark half, one eye on the light half.

    /// <summary>The disc Deathstroke is struck on.</summary>
    private static EllipseGeometry PlateDisc(double s)
    {
        var inset = s * 0.02;
        var r = (s - inset * 2) / 2;
        return new EllipseGeometry { Center = new Point(s / 2, s / 2), RadiusX = r, RadiusY = r };
    }

    private enum CrosshairArm { Vertical, LeftHorizontal, RightHorizontal }

    /// <summary>
    /// The crosshair rules — vertical through the split, horizontal at eye
    /// level. Both overshoot the circle, which is what makes it read as a scope.
    /// </summary>
    private static PathGeometry DeathstrokeCrosshair(double s, CrosshairArm arm)
    {
        const double t = 0.022;   // half-thickness
        var points = arm switch
        {
            CrosshairArm.Vertical => new (double, double)[]
                { (0.5 - t, 0.02), (0.5 + t, 0.02), (0.5 + t, 0.98), (0.5 - t, 0.98) },
            CrosshairArm.LeftHorizontal => new (double, double)[]
                { (0.04, 0.52 - t), (0.50, 0.52 - t), (0.50, 0.52 + t), (0.04, 0.52 + t) },
            _ => new (double, double)[]
                { (0.50, 0.52 - t), (0.96, 0.52 - t), (0.96, 0.52 + t), (0.50, 0.52 + t) },
        };

        var u = new UnitPath(s);
        u.Polygon(points);
        return u.Close();
    }

    /// <summary>
    /// Stepped circuit traces on the dark half. Drawn open and stroked — at
    /// swatch size this blurs into "tech detail", which is exactly its job.
    /// </summary>
    private static GeometryGroup DeathstrokeReticle(double s)
    {
        var group = new GeometryGroup();
        void Run(params (double X, double Y)[] pts)
        {
            var u = new UnitPath(s);
            u.Polygon(pts);
            group.Children.Add(u.Close(closed: false));
        }

        Run((0.27, 0.36), (0.40, 0.36), (0.40, 0.66));
        Run((0.19, 0.52), (0.34, 0.52));
        Run((0.24, 0.66), (0.40, 0.66));
        Run((0.30, 0.42), (0.36, 0.42), (0.36, 0.48), (0.30, 0.48), (0.30, 0.42));
        return group;
    }

    /// <summary>The single eye, tilted, with a tail that flicks up past the socket.</summary>
    private static PathGeometry DeathstrokeEye(double s)
    {
        var u = new UnitPath(s);
        u.Move(0.50, 0.600);
        u.Curve(0.80, 0.435, 0.585, 0.535, 0.695, 0.445);   // upper lid
        u.Curve(0.50, 0.600, 0.735, 0.515, 0.600, 0.605);   // lower lid
        return u.Close();
    }

    /// <summary>The brow flick past the eye's outer corner.</summary>
    private static PathGeometry DeathstrokeBrow(double s)
    {
        var u = new UnitPath(s);
        u.Move(0.755, 0.455);
        u.Curve(0.865, 0.330, 0.815, 0.420, 0.850, 0.370);
        u.Curve(0.790, 0.470, 0.845, 0.395, 0.805, 0.430);
        return u.Close();
    }

    // MARK: - Red Hood

    /// <summary>
    /// Red Hood's chest mark: a bat, but a fully angular one — every edge is a
    /// straight line and the wings step rather than scallop. That hard geometry
    /// is what separates it from Batman's silhouette.
    /// </summary>
    private static readonly (double X, double Y)[] RedHoodTopEdge =
    {
        (0.00, 0.46),
        (0.18, 0.29),                 // left shoulder
        (0.41, 0.37),                 // valley
        (0.45, 0.29),                 // left ear
        (0.50, 0.34),                 // centre notch
        (0.55, 0.29),                 // right ear
        (0.59, 0.37),                 // valley
        (0.82, 0.29),                 // right shoulder
        (1.00, 0.46),
    };

    /// <summary>
    /// Underside of the left wing, body outward to the tip, including the small
    /// downward tooth.
    /// </summary>
    private static readonly (double X, double Y)[] RedHoodLeftUnderside =
    {
        (0.335, 0.570), (0.315, 0.612), (0.300, 0.570),
        (0.160, 0.520),
        (0.000, 0.460),
    };

    private static PathGeometry RedHoodBat(double s)
    {
        var walk = new List<(double X, double Y)>();
        walk.AddRange(RedHoodTopEdge);
        walk.AddRange(Reversed(Mirrored(RedHoodLeftUnderside)).Skip(1));
        walk.Add((0.50, 0.72));                                   // body point
        walk.AddRange(RedHoodLeftUnderside);

        var u = new UnitPath(s);
        u.Polygon(walk);
        return u.Close();
    }

    // MARK: - Colour helpers

    /// <summary>Linear RGB blend toward <paramref name="other"/>, keeping alpha.</summary>
    private static Color Mixed(this Color c, Color other, double amount)
    {
        var t = Math.Clamp(amount, 0, 1);
        return Color.FromArgb(
            c.A,
            (byte)(c.R * (1 - t) + other.R * t),
            (byte)(c.G * (1 - t) + other.G * t),
            (byte)(c.B * (1 - t) + other.B * t));
    }

    private static Color WithAlpha(this Color c, double alpha) =>
        Color.FromArgb((byte)(Math.Clamp(alpha, 0, 1) * 255), c.R, c.G, c.B);

    private static readonly Color White = Color.FromArgb(255, 255, 255, 255);
    private static readonly Color Black = Color.FromArgb(255, 0, 0, 0);
    private static readonly Color Ink = Color.FromArgb(255, 13, 13, 13);

    private static LinearGradientBrush Vertical(params Color[] stops)
    {
        var brush = new LinearGradientBrush
        {
            StartPoint = new Point(0, 0),
            EndPoint = new Point(0, 1),
        };
        for (var i = 0; i < stops.Length; i++)
        {
            brush.GradientStops.Add(new GradientStop
            {
                Color = stops[i],
                Offset = stops.Length == 1 ? 0 : (double)i / (stops.Length - 1),
            });
        }
        return brush;
    }

    private static LinearGradientBrush Diagonal(params Color[] stops)
    {
        var brush = new LinearGradientBrush
        {
            StartPoint = new Point(0, 0),
            EndPoint = new Point(1, 1),
        };
        for (var i = 0; i < stops.Length; i++)
        {
            brush.GradientStops.Add(new GradientStop
            {
                Color = stops[i],
                Offset = stops.Length == 1 ? 0 : (double)i / (stops.Length - 1),
            });
        }
        return brush;
    }

    // MARK: - Public API

    /// <summary>
    /// Builds the emblem for a theme, or null for the abstract themes.
    /// </summary>
    /// <param name="config">Supplies the emblem choice and its colours.</param>
    /// <param name="size">Square edge, in DIPs.</param>
    /// <param name="strength">
    /// Overall opacity. The timer drops this to a watermark while a session
    /// runs so the readout on top of it stays legible.
    /// </param>
    /// <param name="isLive">True while the timer runs — lights the edge.</param>
    public static FrameworkElement? Build(
        ThemeConfiguration config,
        double size = 172,
        double strength = 0.95,
        bool isLive = false)
    {
        if (config.Emblem is not { } emblem) return null;

        // Superman's accent is the red of the S; everyone else rides their
        // theme accent, which is already the colour the character is known by.
        var accent = emblem == ThemeEmblem.Superman ? config.Secondary : config.Primary;

        var host = new Canvas
        {
            Width = size,
            Height = size,
            Opacity = strength,
            IsHitTestVisible = false,
        };

        switch (emblem)
        {
            case ThemeEmblem.Superman:
                BuildSuperman(host, config, size);
                break;

            // Black body, gold edge — the mark from the reference, not a split.
            case ThemeEmblem.Batman:
                BuildSolidMark(host, BatSilhouette(size), Color.FromArgb(255, 31, 31, 31),
                    config.Primary, 0.030, size, glow: true);
                break;

            case ThemeEmblem.Nightwing:
                BuildSolidMark(host, NightwingWings(size), config.Primary,
                    config.Primary.Mixed(White, 0.55), 0.016, size);
                break;

            case ThemeEmblem.RedHood:
                BuildSolidMark(host, RedHoodBat(size), config.Primary,
                    config.Primary.Mixed(Black, 0.55), 0.018, size);
                break;

            case ThemeEmblem.Deathstroke:
                BuildDeathstroke(host, accent, size);
                break;
        }

        if (isLive) AddEdgeLight(host, Outline(emblem, size), accent, size);

        return host;
    }

    /// <summary>
    /// The silhouette the running light travels around. All five emblems feed
    /// one animator.
    /// </summary>
    private static Geometry Outline(ThemeEmblem emblem, double s) => emblem switch
    {
        ThemeEmblem.Superman => SupermanShield(s),
        ThemeEmblem.Batman => BatSilhouette(s),
        ThemeEmblem.Nightwing => NightwingWings(s),
        ThemeEmblem.Deathstroke => PlateDisc(s),
        _ => RedHoodBat(s),
    };

    /// <summary>A single-colour mark: shaded body and a defined edge.</summary>
    private static void BuildSolidMark(
        Canvas host,
        Geometry mark,
        Color body,
        Color edge,
        double edgeWidth,
        double size,
        bool glow = false)
    {
        host.Children.Add(new Path
        {
            Data = mark,
            Fill = Vertical(body.Mixed(White, 0.16), body.Mixed(Black, 0.32)),
        });

        if (glow)
        {
            // Weight, not bloom — one wide faint pass stands in for the
            // SwiftUI shadow, which XAML shapes have no direct equivalent for.
            host.Children.Add(new Path
            {
                Data = mark,
                Stroke = new SolidColorBrush(edge.WithAlpha(0.28)),
                StrokeThickness = Math.Max(0.8, size * edgeWidth) * 3,
                StrokeLineJoin = PenLineJoin.Round,
            });
        }

        host.Children.Add(new Path
        {
            Data = mark,
            Stroke = new SolidColorBrush(edge),
            StrokeThickness = Math.Max(0.8, size * edgeWidth),
            StrokeLineJoin = PenLineJoin.Round,
        });
    }

    /// <summary>
    /// Red field, gold border, gold S — struck like the reference, with the
    /// border stroked rather than inset so it keeps an even weight all the way
    /// round the shield instead of thinning out at the point.
    /// </summary>
    private static void BuildSuperman(Canvas host, ThemeConfiguration config, double size)
    {
        var shield = SupermanShield(size);

        // The gold Superman uses for its border and its S. Lives in the
        // theme's digit ramp already, so it stays in step with any recolouring.
        var gold = config.DigitColors.Count > 0 ? config.DigitColors[0] : Color.FromArgb(255, 255, 216, 77);
        LinearGradientBrush GoldRamp() =>
            Diagonal(gold.Mixed(White, 0.35), gold, gold.Mixed(Black, 0.40));

        // Deep maroon, not the theme's bright red — the field in the real mark
        // is dark enough that the gold reads as the brighter element.
        host.Children.Add(new Path
        {
            Data = shield,
            Fill = Vertical(config.Secondary.Mixed(Black, 0.42), config.Secondary.Mixed(Black, 0.72)),
        });

        host.Children.Add(new Path
        {
            Data = shield,
            Stroke = GoldRamp(),
            StrokeThickness = size * 0.052,
            StrokeLineJoin = PenLineJoin.Round,
        });

        host.Children.Add(new Path
        {
            Data = shield,
            Stroke = new SolidColorBrush(gold.Mixed(White, 0.5).WithAlpha(0.8)),
            StrokeThickness = Math.Max(0.7, size * 0.008),
            StrokeLineJoin = PenLineJoin.Round,
        });

        // The S as a stroked ribbon; flat caps keep its terminals hard-edged.
        host.Children.Add(new Path
        {
            Data = SupermanS(size),
            Stroke = GoldRamp(),
            StrokeThickness = size * 0.145,
            StrokeStartLineCap = PenLineCap.Flat,
            StrokeEndLineCap = PenLineCap.Flat,
            StrokeLineJoin = PenLineJoin.Round,
        });
    }

    /// <summary>
    /// Deathstroke already *is* a split plate, but its halves run the other way
    /// round: the reticle lives on the shadowed left, the eye on the lit right.
    ///
    /// Its crosshair is drawn per-arm rather than inverted across the seam —
    /// running it through a shared mark doubled the rule right on the join.
    /// </summary>
    private static void BuildDeathstroke(Canvas host, Color accent, double size)
    {
        var half = size / 2;
        LinearGradientBrush AccentFill() => Vertical(accent.Mixed(White, 0.12), accent.Mixed(Black, 0.30));
        // Kept off pure black so the plate still reads against a black backdrop.
        LinearGradientBrush ShadeFill() =>
            Vertical(Color.FromArgb(255, 54, 54, 54), Color.FromArgb(255, 18, 18, 18));

        host.Children.Add(new Path
        {
            Data = PlateDisc(size),
            Fill = ShadeFill(),
            Clip = new RectangleGeometry { Rect = new Rect(0, 0, half, size) },
        });

        host.Children.Add(new Path
        {
            Data = PlateDisc(size),
            Fill = AccentFill(),
            Clip = new RectangleGeometry { Rect = new Rect(half, 0, half, size) },
        });

        host.Children.Add(new Path
        {
            Data = PlateDisc(size),
            Stroke = new SolidColorBrush(accent.WithAlpha(0.45)),
            StrokeThickness = Math.Max(0.75, size * 0.008),
        });

        host.Children.Add(new Path
        {
            Data = DeathstrokeReticle(size),
            Stroke = AccentFill(),
            StrokeThickness = size * 0.024,
            StrokeLineJoin = PenLineJoin.Miter,
        });

        host.Children.Add(new Path
        {
            Data = DeathstrokeCrosshair(size, CrosshairArm.Vertical),
            Fill = AccentFill(),
        });
        host.Children.Add(new Path
        {
            Data = DeathstrokeCrosshair(size, CrosshairArm.LeftHorizontal),
            Fill = AccentFill(),
        });
        host.Children.Add(new Path
        {
            Data = DeathstrokeCrosshair(size, CrosshairArm.RightHorizontal),
            Fill = new SolidColorBrush(Ink),
        });

        host.Children.Add(new Path { Data = DeathstrokeBrow(size), Fill = new SolidColorBrush(Ink) });
        host.Children.Add(new Path
        {
            Data = DeathstrokeEye(size),
            Fill = new SolidColorBrush(Color.FromArgb(255, 240, 240, 240)),
        });
        host.Children.Add(new Path
        {
            Data = DeathstrokeEye(size),
            Stroke = new SolidColorBrush(Ink),
            StrokeThickness = size * 0.028,
            StrokeLineJoin = PenLineJoin.Round,
        });
    }

    // MARK: - Running edge light

    /// <summary>
    /// White light chasing around an emblem's outline while the timer runs.
    ///
    /// SwiftUI trims the silhouette to a moving window; XAML shapes have no
    /// trim, so this uses a dashed stroke whose offset animates — one long gap
    /// and one short dash gives the same "runner travelling the edge" read, and
    /// the dash follows whatever geometry it is handed.
    /// </summary>
    private static void AddEdgeLight(Canvas host, Geometry outline, Color tint, double size)
    {
        // Standing rim glow so the whole mark reads as energised, not just the
        // moving highlight.
        host.Children.Add(new Path
        {
            Data = outline,
            Stroke = new SolidColorBrush(tint.WithAlpha(0.45)),
            StrokeThickness = size * 0.030,
            StrokeLineJoin = PenLineJoin.Round,
        });

        // Tail then hot head, each shorter and brighter than the last.
        AddRunner(host, outline, White.WithAlpha(0.35), size * 0.020, 6, size);
        AddRunner(host, outline, White, size * 0.030, 2, size);
    }

    private static void AddRunner(
        Canvas host,
        Geometry outline,
        Color color,
        double thickness,
        double dashLength,
        double size)
    {
        // Two runners half a lap apart, so there is always one in view no
        // matter which way the emblem faces.
        const double gap = 60;
        var runner = new Path
        {
            Data = outline,
            Stroke = new SolidColorBrush(color),
            StrokeThickness = thickness,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
            StrokeDashCap = PenLineCap.Round,
            StrokeDashArray = new DoubleCollection { dashLength, gap },
        };
        host.Children.Add(runner);

        var animation = new DoubleAnimation
        {
            From = 0,
            To = -(dashLength + gap) * 2,
            Duration = new Duration(TimeSpan.FromSeconds(4.5)),
            RepeatBehavior = RepeatBehavior.Forever,
            // StrokeDashOffset is not a composition property, so the animation
            // has to be allowed to run on the UI thread explicitly.
            EnableDependentAnimation = true,
        };
        Storyboard.SetTarget(animation, runner);
        Storyboard.SetTargetProperty(animation, "(Shape.StrokeDashOffset)");

        var storyboard = new Storyboard();
        storyboard.Children.Add(animation);

        // Build() returns before the host is parented, and starting a
        // storyboard against an element outside the live tree does nothing.
        // Waiting for Loaded also restarts the runner on each rebuild.
        runner.Loaded += (_, _) => storyboard.Begin();
        runner.Unloaded += (_, _) => storyboard.Stop();
    }
}
