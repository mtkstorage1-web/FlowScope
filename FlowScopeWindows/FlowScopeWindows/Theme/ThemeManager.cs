using FlowScopeWindows.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;

namespace FlowScopeWindows.Theme;

/// <summary>
/// Holds the active <see cref="ThemeConfiguration"/> and republishes it into
/// the app's resource dictionary, so XAML can bind themed brushes with
/// <c>{ThemeResource}</c> and every page restyles at once.
/// </summary>
public sealed class ThemeManager : Observable
{
    public static ThemeManager Shared { get; } = new();

    private ThemeManager()
    {
        _baseTheme = AppSettings.Shared.Theme;
        _customization = ThemeCustomizationStore.Shared.Get(_baseTheme);
        _configuration = ThemeProvider.For(_baseTheme).Applying(_customization);
    }

    private AppTheme _baseTheme;
    private ThemeCustomizationState _customization;

    private ThemeConfiguration _configuration;
    public ThemeConfiguration Configuration
    {
        get => _configuration;
        private set
        {
            if (!Set(ref _configuration, value)) return;
            Raise(nameof(PrimaryBrush));
            Raise(nameof(SecondaryBrush));
            Raise(nameof(SurfaceBrush));
            Raise(nameof(TextPrimaryBrush));
            Raise(nameof(TextSecondaryBrush));
            Raise(nameof(BackgroundBrush));
            Raise(nameof(DigitBrush));
            Raise(nameof(RingBrush));
            Raise(nameof(CornerRadius));
            Raise(nameof(FontFamily));
        }
    }

    public AppTheme Current => Configuration.Theme;

    /// <summary>The active theme's saved recolouring, so a settings page can seed its sliders.</summary>
    public ThemeCustomizationState CurrentCustomization => _customization;

    public void Apply(AppTheme theme)
    {
        AppSettings.Shared.Theme = theme;
        _baseTheme = theme;
        _customization = ThemeCustomizationStore.Shared.Get(theme);
        Recompute();
    }

    /// <summary>
    /// Applies a new hue/saturation/brightness + hex-override state to the
    /// *current* theme and persists it, so recolouring one theme never bleeds
    /// into another.
    /// </summary>
    public void ApplyCustomization(ThemeCustomizationState state)
    {
        _customization = state;
        ThemeCustomizationStore.Shared.Set(_baseTheme, state);
        Recompute();
    }

    private void Recompute()
    {
        Configuration = ThemeProvider.For(_baseTheme).Applying(_customization);
        PublishResources();
    }

    /// <summary>
    /// Pushes the palette into Application.Resources under stable keys. Pages
    /// that use {ThemeResource FlowScopePrimaryBrush} pick the new values up
    /// without each one subscribing to this manager.
    /// </summary>
    public void PublishResources()
    {
        var resources = Application.Current.Resources;
        resources["FlowScopePrimaryBrush"] = PrimaryBrush;
        resources["FlowScopeSecondaryBrush"] = SecondaryBrush;
        resources["FlowScopeSurfaceBrush"] = SurfaceBrush;
        resources["FlowScopeTextPrimaryBrush"] = TextPrimaryBrush;
        resources["FlowScopeTextSecondaryBrush"] = TextSecondaryBrush;
        resources["FlowScopeBackgroundBrush"] = BackgroundBrush;
        resources["FlowScopeDigitBrush"] = DigitBrush;
        resources["FlowScopeRingBrush"] = RingBrush;
        resources["FlowScopeCornerRadius"] = CornerRadius;
        resources["FlowScopeFontFamily"] = FontFamily;
    }

    // MARK: - Brushes

    public SolidColorBrush PrimaryBrush => new(Configuration.Primary);
    public SolidColorBrush SecondaryBrush => new(Configuration.Secondary);
    public SolidColorBrush SurfaceBrush => new(Configuration.Surface);
    public SolidColorBrush TextPrimaryBrush => new(Configuration.TextPrimary);
    public SolidColorBrush TextSecondaryBrush => new(Configuration.TextSecondary);

    /// <summary>Top-to-bottom page wash.</summary>
    public LinearGradientBrush BackgroundBrush =>
        Vertical(Configuration.BackgroundTop, Configuration.BackgroundBottom);

    /// <summary>Left-to-right ramp painted through the clock digits.</summary>
    public LinearGradientBrush DigitBrush => Horizontal(Configuration.DigitColors);

    public LinearGradientBrush RingBrush => Horizontal(Configuration.RingColors);

    public CornerRadius CornerRadius => new(Configuration.CornerRadius);

    public FontFamily FontFamily => new(Configuration.FontFamily);

    private static LinearGradientBrush Vertical(Windows.UI.Color top, Windows.UI.Color bottom) =>
        Build(new[] { top, bottom }, new Windows.Foundation.Point(0.5, 0), new Windows.Foundation.Point(0.5, 1));

    private static LinearGradientBrush Horizontal(IReadOnlyList<Windows.UI.Color> colors) =>
        Build(colors, new Windows.Foundation.Point(0, 0.5), new Windows.Foundation.Point(1, 0.5));

    private static LinearGradientBrush Build(
        IReadOnlyList<Windows.UI.Color> colors,
        Windows.Foundation.Point start,
        Windows.Foundation.Point end)
    {
        var brush = new LinearGradientBrush { StartPoint = start, EndPoint = end };

        if (colors.Count == 1)
        {
            // A one-stop gradient renders as nothing; duplicate it into a flat fill.
            brush.GradientStops.Add(new GradientStop { Color = colors[0], Offset = 0 });
            brush.GradientStops.Add(new GradientStop { Color = colors[0], Offset = 1 });
            return brush;
        }

        for (var i = 0; i < colors.Count; i++)
        {
            brush.GradientStops.Add(new GradientStop
            {
                Color = colors[i],
                Offset = i / (double)(colors.Count - 1),
            });
        }

        return brush;
    }
}
