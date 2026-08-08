using Windows.UI;
using Windows.UI.Text;

namespace FlowScopeWindows.Theme;

/// <summary>
/// All nine palettes, ported value-for-value from <c>ThemeProvider</c> in
/// ThemeEngine.swift. Keeping the hexes identical is the whole point: a user
/// who picks Deathstroke on their phone should see the same app on their PC.
/// </summary>
public static class ThemeProvider
{
    public static ThemeConfiguration For(AppTheme theme) => theme switch
    {
        AppTheme.Flame => Flame,
        AppTheme.Cyberpunk => Cyberpunk,
        AppTheme.Lava => Lava,
        AppTheme.Neon80s => Neon80s,
        AppTheme.Superman => Superman,
        AppTheme.Batman => Batman,
        AppTheme.Nightwing => Nightwing,
        AppTheme.Deathstroke => Deathstroke,
        AppTheme.RedHood => RedHood,
        _ => Flame,
    };

    // Apple's system colours, so the ported gradients land on the same hues.
    private static readonly Color SystemRed = Hex("#FF3B30");
    private static readonly Color SystemOrange = Hex("#FF9500");
    private static readonly Color SystemYellow = Hex("#FFCC00");
    private static readonly Color SystemCyan = Hex("#32ADE6");
    private static readonly Color White = Hex("#FFFFFF");
    private static readonly Color Black = Hex("#000000");

    // Windows equivalents of SwiftUI's three font designs.
    private const string FontDefault = "Segoe UI Variable Display";
    private const string FontRounded = "Segoe UI Variable Display";
    private const string FontMono = "Cascadia Mono";

    // MARK: 1. Flame

    private static readonly ThemeConfiguration Flame = new()
    {
        Theme = AppTheme.Flame,
        FontFamily = FontDefault,
        FontWeight = FontWeights.Black,
        CornerRadius = 14,
        Primary = Hex("#FF6B1A"),
        Secondary = Hex("#FFC300"),
        BackgroundTop = Hex("#3B0A02"),
        BackgroundBottom = Hex("#1A0B04"),
        TextPrimary = White,
        TextSecondary = Hex("#FFB088"),
        Surface = Hex("#2A0D05"),
        DigitColors = new[] { SystemRed, SystemOrange, SystemYellow },
        RingColors = new[] { SystemRed, SystemOrange, SystemYellow, SystemRed },
        Glow = SystemOrange,
        Particles = ParticleStyle.Fire,
    };

    // MARK: 2. Cyberpunk

    private static readonly ThemeConfiguration Cyberpunk = new()
    {
        Theme = AppTheme.Cyberpunk,
        FontFamily = FontMono,
        FontWeight = FontWeights.SemiBold,
        CornerRadius = 6,
        Primary = Hex("#00E5FF"),
        Secondary = Hex("#B026FF"),
        BackgroundTop = Hex("#1A0033"),
        BackgroundBottom = Black,
        TextPrimary = White,
        TextSecondary = Hex("#C79BFF"),
        Surface = Hex("#200A3A"),
        DigitColors = new[] { SystemCyan, Hex("#B026FF") },
        RingColors = new[] { SystemCyan },
        Glow = Hex("#00E5FF"),
        Particles = ParticleStyle.Scanlines,
    };

    // MARK: 3. Lava

    private static readonly ThemeConfiguration Lava = new()
    {
        Theme = AppTheme.Lava,
        FontFamily = FontDefault,
        FontWeight = FontWeights.Bold,
        CornerRadius = 8,
        Primary = Hex("#DC143C"),
        Secondary = Hex("#FF4500"),
        BackgroundTop = Hex("#1F1F1F"),
        BackgroundBottom = Black,
        TextPrimary = White,
        TextSecondary = Hex("#A66A5E"),
        Surface = Hex("#171717"),
        DigitColors = new[] { Hex("#7A0A1E"), Hex("#FF2D2D") },
        RingColors = new[] { Hex("#DC143C") },
        Glow = Hex("#FF4500"),
        Particles = ParticleStyle.LavaCracks,
    };

    // MARK: 4. Neon 80s

    private static readonly ThemeConfiguration Neon80s = new()
    {
        Theme = AppTheme.Neon80s,
        FontFamily = FontDefault,
        FontWeight = FontWeights.Bold,
        CornerRadius = 0,
        Primary = Hex("#FF2D95"),
        Secondary = Hex("#00E5FF"),
        BackgroundTop = Hex("#12005E"),
        BackgroundBottom = Black,
        TextPrimary = White,
        TextSecondary = Hex("#00E5FF"),
        Surface = Hex("#1A0A4A"),
        DigitColors = new[] { Hex("#FF2D95"), SystemCyan },
        RingColors = new[] { SystemYellow },
        Glow = Hex("#FF2D95"),
        Particles = ParticleStyle.RetroGrid,
    };

    // MARK: 5. Superman

    private static readonly ThemeConfiguration Superman = new()
    {
        Theme = AppTheme.Superman,
        FontFamily = FontDefault,
        FontWeight = FontWeights.Black,
        CornerRadius = 16,
        Primary = Hex("#1E5BFF"),
        Secondary = Hex("#E63030"),
        BackgroundTop = Hex("#0A1338"),
        BackgroundBottom = Hex("#04091E"),
        TextPrimary = White,
        TextSecondary = Hex("#93B4FF"),
        Surface = Hex("#101A45"),
        DigitColors = new[] { Hex("#FFD84D"), Hex("#F5A623") },
        RingColors = new[] { Hex("#1E5BFF"), Hex("#E63030"), Hex("#F5C518"), Hex("#1E5BFF") },
        Glow = Hex("#1E5BFF"),
        Particles = ParticleStyle.Carbon,
    };

    // MARK: 6. Batman

    private static readonly ThemeConfiguration Batman = new()
    {
        Theme = AppTheme.Batman,
        FontFamily = FontDefault,
        FontWeight = FontWeights.Bold,
        CornerRadius = 6,
        Primary = Hex("#FFDF00"),
        Secondary = Hex("#4A4A4A"),
        BackgroundTop = Hex("#12131A"),
        BackgroundBottom = Black,
        TextPrimary = White,
        TextSecondary = Hex("#8A8D99"),
        Surface = Hex("#17181F"),
        DigitColors = new[] { Hex("#FFDF00"), Hex("#B99A00") },
        RingColors = new[] { Hex("#FFDF00") },
        Glow = Hex("#FFDF00"),
        Particles = ParticleStyle.Carbon,
    };

    // MARK: 7. Nightwing

    private static readonly ThemeConfiguration Nightwing = new()
    {
        Theme = AppTheme.Nightwing,
        FontFamily = FontRounded,
        FontWeight = FontWeights.SemiBold,
        CornerRadius = 18,
        Primary = Hex("#1E90FF"),
        Secondary = Hex("#0B2545"),
        BackgroundTop = Hex("#06101F"),
        BackgroundBottom = Black,
        TextPrimary = White,
        TextSecondary = Hex("#7FB4E8"),
        Surface = Hex("#0C1626"),
        DigitColors = new[] { Hex("#4FC3FF"), White },
        RingColors = new[] { Hex("#1E90FF"), Hex("#7FDBFF") },
        Glow = Hex("#1E90FF"),
        Particles = ParticleStyle.Carbon,
    };

    // MARK: 8. Deathstroke

    private static readonly ThemeConfiguration Deathstroke = new()
    {
        Theme = AppTheme.Deathstroke,
        FontFamily = FontMono,
        FontWeight = FontWeights.Bold,
        CornerRadius = 4,
        Primary = Hex("#F26A21"),
        Secondary = Hex("#2B3A67"),
        BackgroundTop = Hex("#10131C"),
        BackgroundBottom = Hex("#05070D"),
        TextPrimary = White,
        TextSecondary = Hex("#9AA3B8"),
        Surface = Hex("#161A26"),
        DigitColors = new[] { Hex("#FFB067"), Hex("#F26A21") },
        RingColors = new[] { Hex("#F26A21") },
        Glow = Hex("#F26A21"),
        Particles = ParticleStyle.Carbon,
    };

    // MARK: 9. Red Hood

    private static readonly ThemeConfiguration RedHood = new()
    {
        Theme = AppTheme.RedHood,
        FontFamily = FontDefault,
        FontWeight = FontWeights.Bold,
        CornerRadius = 10,
        Primary = Hex("#C8102E"),
        Secondary = Hex("#6E6E6E"),
        BackgroundTop = Hex("#1A0A0C"),
        BackgroundBottom = Black,
        TextPrimary = Hex("#F0E6E7"),
        TextSecondary = Hex("#C08A8F"),
        Surface = Hex("#210E11"),
        DigitColors = new[] { Hex("#FF3B3B"), Hex("#8B0A19") },
        RingColors = new[] { Hex("#C8102E"), Hex("#FF4D4D") },
        Glow = Hex("#C8102E"),
        Particles = ParticleStyle.Carbon,
    };

    /// <summary>Parses "#RRGGBB" or "#AARRGGBB".</summary>
    public static Color Hex(string hex)
    {
        var cleaned = hex.TrimStart('#');
        if (cleaned.Length == 6) cleaned = "FF" + cleaned;
        var value = uint.Parse(cleaned, System.Globalization.NumberStyles.HexNumber);
        return Color.FromArgb(
            (byte)((value >> 24) & 0xFF),
            (byte)((value >> 16) & 0xFF),
            (byte)((value >> 8) & 0xFF),
            (byte)(value & 0xFF));
    }

    /// <summary>Same colour at a different opacity — used for tracks and tints.</summary>
    public static Color WithOpacity(this Color color, double opacity) =>
        Color.FromArgb((byte)Math.Clamp(opacity * 255, 0, 255), color.R, color.G, color.B);
}
