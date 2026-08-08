using Windows.UI;

namespace FlowScopeWindows.Theme;

/// <summary>
/// The nine visual identities, matching <c>AppTheme</c> in ThemeEngine.swift.
/// Ids are kept identical across platforms so a settings export ports over.
/// </summary>
public enum AppTheme
{
    Flame,
    Cyberpunk,
    Lava,
    Neon80s,
    Superman,
    Batman,
    Nightwing,
    Deathstroke,
    RedHood,
}

public static class AppThemeInfo
{
    public static string Id(this AppTheme theme) => theme switch
    {
        AppTheme.Flame => "flame",
        AppTheme.Cyberpunk => "cyberpunk",
        AppTheme.Lava => "lava",
        AppTheme.Neon80s => "neon80s",
        AppTheme.Superman => "superman",
        AppTheme.Batman => "batman",
        AppTheme.Nightwing => "nightwing",
        AppTheme.Deathstroke => "deathstroke",
        AppTheme.RedHood => "redHood",
        _ => "flame",
    };

    public static string DisplayName(this AppTheme theme) => theme switch
    {
        AppTheme.Flame => "Flame",
        AppTheme.Cyberpunk => "Cyberpunk",
        AppTheme.Lava => "Lava",
        AppTheme.Neon80s => "Neon 80s",
        AppTheme.Superman => "Superman",
        AppTheme.Batman => "Batman",
        AppTheme.Nightwing => "Nightwing",
        AppTheme.Deathstroke => "Deathstroke",
        AppTheme.RedHood => "Red Hood",
        _ => "Flame",
    };

    public static AppTheme FromId(string? id) =>
        Enum.GetValues<AppTheme>().FirstOrDefault(t => t.Id() == id, AppTheme.Flame);
}

/// <summary>
/// Every styling value a screen is allowed to read. Screens never branch on
/// the theme — they bind to these, exactly as on iOS and Android.
/// </summary>
public sealed record ThemeConfiguration
{
    public required AppTheme Theme { get; init; }

    public required string FontFamily { get; init; }
    public required Windows.UI.Text.FontWeight FontWeight { get; init; }
    public required double CornerRadius { get; init; }

    public required Color Primary { get; init; }
    public required Color Secondary { get; init; }
    public required Color BackgroundTop { get; init; }
    public required Color BackgroundBottom { get; init; }
    public required Color TextPrimary { get; init; }
    public required Color TextSecondary { get; init; }
    public required Color Surface { get; init; }

    /// <summary>Gradient stops for the big clock digits.</summary>
    public required IReadOnlyList<Color> DigitColors { get; init; }

    /// <summary>Gradient stops for the progress ring.</summary>
    public required IReadOnlyList<Color> RingColors { get; init; }

    /// <summary>Colour of the glow behind digits and the primary button.</summary>
    public required Color Glow { get; init; }

    /// <summary>Which animated background the timer page draws.</summary>
    public required ParticleStyle Particles { get; init; }
}

/// <summary>
/// The background field behind the timer. The Windows build renders these
/// with Composition animations rather than the per-theme Canvas art the
/// Apple build uses; the intent (motion, colour, density) is the same.
/// </summary>
public enum ParticleStyle
{
    Fire,
    Scanlines,
    LavaCracks,
    RetroGrid,
    Carbon,
}
