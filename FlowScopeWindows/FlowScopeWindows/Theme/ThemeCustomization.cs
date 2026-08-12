using FlowScopeWindows.Services;
using Windows.UI;

namespace FlowScopeWindows.Theme;

/// <summary>
/// A hue/saturation/brightness shift applied on top of a base
/// <see cref="ThemeConfiguration"/>, mirroring the sliders in
/// ThemeCustomization.swift. Every theme keeps its own delta, so recolouring
/// Cyberpunk doesn't touch what Flame looks like.
/// </summary>
public readonly record struct ColorDelta(double Hue, double Saturation, double Brightness)
{
    /// <summary>Hue in degrees (-180..180); saturation/brightness as -1..1 shifts.</summary>
    public static readonly ColorDelta None = new(0, 0, 0);

    public bool IsIdentity => Hue == 0 && Saturation == 0 && Brightness == 0;
}

/// <summary>
/// The full customization a user has applied to one theme: the HSB delta plus
/// optional explicit hex overrides for the three colours people actually want
/// to pin exactly, rather than just nudge.
/// </summary>
public sealed record ThemeCustomizationState
{
    public ColorDelta Delta { get; init; } = ColorDelta.None;
    public string? PrimaryHex { get; init; }
    public string? SecondaryHex { get; init; }
    public string? BackgroundHex { get; init; }

    public bool IsIdentity => Delta.IsIdentity && PrimaryHex is null && SecondaryHex is null && BackgroundHex is null;
}

public static class ThemeCustomization
{
    /// <summary>Applies an HSB shift to one colour, alpha untouched.</summary>
    public static Color Adjusted(this Color c, ColorDelta delta)
    {
        if (delta.IsIdentity) return c;

        var (h, s, v) = ToHsv(c);
        h = (h + delta.Hue + 360) % 360;
        s = Math.Clamp(s + delta.Saturation, 0, 1);
        v = Math.Clamp(v + delta.Brightness, 0, 1);

        var (r, g, b) = FromHsv(h, s, v);
        return Color.FromArgb(c.A, r, g, b);
    }

    /// <summary>
    /// Composes a base theme with a user's customization: the HSB delta shifts
    /// every colour, then any explicit hex override replaces its target colour
    /// outright, matching ThemeCustomization.swift's "override wins" rule.
    /// </summary>
    public static ThemeConfiguration Applying(this ThemeConfiguration config, ThemeCustomizationState state)
    {
        if (state.IsIdentity) return config;

        var shifted = state.Delta.IsIdentity
            ? config
            : config with
            {
                Primary = config.Primary.Adjusted(state.Delta),
                Secondary = config.Secondary.Adjusted(state.Delta),
                BackgroundTop = config.BackgroundTop.Adjusted(state.Delta),
                BackgroundBottom = config.BackgroundBottom.Adjusted(state.Delta),
                TextSecondary = config.TextSecondary.Adjusted(state.Delta),
                Surface = config.Surface.Adjusted(state.Delta),
                DigitColors = config.DigitColors.Select(c => c.Adjusted(state.Delta)).ToArray(),
                RingColors = config.RingColors.Select(c => c.Adjusted(state.Delta)).ToArray(),
                Glow = config.Glow.Adjusted(state.Delta),
                // TextPrimary is deliberately left alone: it carries the app's
                // legibility contract and shifting it with everything else
                // risks washing text out against its own background.
            };

        if (state.PrimaryHex is null && state.SecondaryHex is null && state.BackgroundHex is null)
        {
            return shifted;
        }

        return shifted with
        {
            Primary = state.PrimaryHex is { } p ? ThemeProvider.Hex(p) : shifted.Primary,
            Secondary = state.SecondaryHex is { } sec ? ThemeProvider.Hex(sec) : shifted.Secondary,
            BackgroundTop = state.BackgroundHex is { } bg ? ThemeProvider.Hex(bg) : shifted.BackgroundTop,
            BackgroundBottom = state.BackgroundHex is { } bg2
                ? ThemeProvider.Hex(bg2).Adjusted(new ColorDelta(0, 0, -0.35))
                : shifted.BackgroundBottom,
        };
    }

    private static (double H, double S, double V) ToHsv(Color c)
    {
        double r = c.R / 255.0, g = c.G / 255.0, b = c.B / 255.0;
        var max = Math.Max(r, Math.Max(g, b));
        var min = Math.Min(r, Math.Min(g, b));
        var delta = max - min;

        double h;
        if (delta < 1e-6) h = 0;
        else if (max == r) h = 60 * (((g - b) / delta) % 6);
        else if (max == g) h = 60 * ((b - r) / delta + 2);
        else h = 60 * ((r - g) / delta + 4);
        if (h < 0) h += 360;

        var s = max < 1e-6 ? 0 : delta / max;
        return (h, s, max);
    }

    private static (byte R, byte G, byte B) FromHsv(double h, double s, double v)
    {
        var c = v * s;
        var x = c * (1 - Math.Abs(h / 60 % 2 - 1));
        var m = v - c;

        var (r, g, b) = h switch
        {
            < 60 => (c, x, 0.0),
            < 120 => (x, c, 0.0),
            < 180 => (0.0, c, x),
            < 240 => (0.0, x, c),
            < 300 => (x, 0.0, c),
            _ => (c, 0.0, x),
        };

        return ((byte)Math.Round((r + m) * 255), (byte)Math.Round((g + m) * 255), (byte)Math.Round((b + m) * 255));
    }
}

/// <summary>
/// Persists each theme's <see cref="ThemeCustomizationState"/> keyed by theme
/// id, so recolouring survives a relaunch the same way the base theme choice
/// already does.
/// </summary>
public sealed class ThemeCustomizationStore
{
    public static ThemeCustomizationStore Shared { get; } = new();

    private const string Key = "themeCustomization";
    private readonly KeyValueStore _store = KeyValueStore.Shared;
    private Dictionary<string, ThemeCustomizationState> _byTheme;

    private ThemeCustomizationStore()
    {
        _byTheme = _store.Get<Dictionary<string, ThemeCustomizationState>?>(Key, null) ?? new();
    }

    public ThemeCustomizationState Get(AppTheme theme) =>
        _byTheme.TryGetValue(theme.Id(), out var state) ? state : new ThemeCustomizationState();

    public void Set(AppTheme theme, ThemeCustomizationState state)
    {
        if (state.IsIdentity) _byTheme.Remove(theme.Id());
        else _byTheme[theme.Id()] = state;

        _store.Set(Key, _byTheme);
    }
}
