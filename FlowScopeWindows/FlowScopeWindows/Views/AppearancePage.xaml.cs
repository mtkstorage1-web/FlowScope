using FlowScopeWindows.Services;
using FlowScopeWindows.Theme;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using Microsoft.UI.Xaml.Shapes;

namespace FlowScopeWindows.Views;

public sealed partial class AppearancePage : Page
{
    private readonly AppSettings _settings = AppSettings.Shared;

    /// <summary>Suppresses change handlers while the controls are populated.</summary>
    private bool _loading;

    public AppearancePage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);

        _loading = true;

        BuildThemeGrid();
        LoadCustomization();

        SoundToggle.IsOn = _settings.SoundEnabled;
        VolumeSlider.Value = _settings.SoundVolume;
        AwakeToggle.IsOn = _settings.KeepScreenAwake;
        FloatingToggle.IsOn = _settings.FloatingControlEnabled;
        CycleBox.Value = _settings.FocusCycleMinutes;
        PromptBox.Value = _settings.MoodPromptMinutes;

        _loading = false;
    }

    /// <summary>
    /// One swatch per theme, painted with that theme's own gradient — the
    /// grid should preview the palettes, not describe them.
    /// </summary>
    private void BuildThemeGrid()
    {
        ThemeGrid.Items.Clear();

        foreach (var theme in Enum.GetValues<AppTheme>())
        {
            var config = ThemeProvider.For(theme);

            var swatch = new Ellipse
            {
                Width = 62,
                Height = 62,
                Fill = new LinearGradientBrush
                {
                    StartPoint = new Windows.Foundation.Point(0, 0),
                    EndPoint = new Windows.Foundation.Point(1, 1),
                    GradientStops =
                    {
                        new GradientStop { Color = config.Primary, Offset = 0 },
                        new GradientStop { Color = config.Secondary, Offset = 1 },
                    },
                },
                StrokeThickness = theme == _settings.Theme ? 3 : 0,
                Stroke = new SolidColorBrush(config.TextPrimary),
            };

            // Character themes preview their real emblem over the swatch,
            // matching what the timer ring actually shows once selected;
            // abstract themes stay gradient-only since they have none.
            var preview = new Grid { Width = 62, Height = 62, HorizontalAlignment = HorizontalAlignment.Center };
            preview.Children.Add(swatch);
            var emblem = ThemeEmblems.Build(config, size: 44, strength: 0.95, isLive: false);
            if (emblem is not null)
            {
                emblem.HorizontalAlignment = HorizontalAlignment.Center;
                emblem.VerticalAlignment = VerticalAlignment.Center;
                preview.Children.Add(emblem);
            }

            var cell = new StackPanel
            {
                Spacing = 6,
                Width = 92,
                Margin = new Thickness(4),
                Tag = theme,
                Children =
                {
                    preview,
                    new TextBlock
                    {
                        Text = theme.DisplayName(),
                        HorizontalAlignment = HorizontalAlignment.Center,
                        FontSize = 12,
                        Foreground = ThemeManager.Shared.TextSecondaryBrush,
                    },
                },
            };

            ThemeGrid.Items.Add(cell);

            if (theme == _settings.Theme) ThemeGrid.SelectedItem = cell;
        }
    }

    private void OnThemeSelected(object sender, SelectionChangedEventArgs e)
    {
        if (_loading) return;
        if (ThemeGrid.SelectedItem is not StackPanel { Tag: AppTheme theme }) return;

        ThemeManager.Shared.Apply(theme);

        // Repaint the swatch rings and the labels against the new palette,
        // and reload the customize sliders — every theme keeps its own delta.
        _loading = true;
        BuildThemeGrid();
        LoadCustomization();
        _loading = false;
    }

    // MARK: - Customize

    /// <summary>Seeds the sliders/hex boxes from the active theme's saved recolouring.</summary>
    private void LoadCustomization()
    {
        var state = ThemeManager.Shared.CurrentCustomization;
        HueSlider.Value = state.Delta.Hue;
        SaturationSlider.Value = state.Delta.Saturation * 100;
        BrightnessSlider.Value = state.Delta.Brightness * 100;
        PrimaryHexBox.Text = state.PrimaryHex ?? string.Empty;
        SecondaryHexBox.Text = state.SecondaryHex ?? string.Empty;
        BackgroundHexBox.Text = state.BackgroundHex ?? string.Empty;
    }

    private void OnCustomizationChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        if (_loading) return;
        PushCustomization();
    }

    private void OnHexBoxLostFocus(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        PushCustomization();
    }

    private void OnResetCustomization(object sender, RoutedEventArgs e)
    {
        _loading = true;
        HueSlider.Value = 0;
        SaturationSlider.Value = 0;
        BrightnessSlider.Value = 0;
        PrimaryHexBox.Text = string.Empty;
        SecondaryHexBox.Text = string.Empty;
        BackgroundHexBox.Text = string.Empty;
        _loading = false;

        ThemeManager.Shared.ApplyCustomization(new ThemeCustomizationState());
        BuildThemeGrid();
    }

    /// <summary>Reads the current controls and republishes the customization state.</summary>
    private void PushCustomization()
    {
        var state = new ThemeCustomizationState
        {
            Delta = new ColorDelta(HueSlider.Value, SaturationSlider.Value / 100, BrightnessSlider.Value / 100),
            PrimaryHex = NormalizedHex(PrimaryHexBox.Text),
            SecondaryHex = NormalizedHex(SecondaryHexBox.Text),
            BackgroundHex = NormalizedHex(BackgroundHexBox.Text),
        };

        ThemeManager.Shared.ApplyCustomization(state);

        // The swatches (and any character emblem preview) need to repaint
        // against the recoloured palette.
        _loading = true;
        BuildThemeGrid();
        _loading = false;
    }

    /// <summary>Accepts "#RRGGBB"/"RRGGBB"/"#AARRGGBB"; blank or malformed input clears the override.</summary>
    private static string? NormalizedHex(string? text)
    {
        var trimmed = text?.Trim().TrimStart('#');
        if (string.IsNullOrEmpty(trimmed)) return null;
        return trimmed.Length is 6 or 8 && trimmed.All(Uri.IsHexDigit) ? "#" + trimmed : null;
    }

    private void OnSoundToggled(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _settings.SoundEnabled = SoundToggle.IsOn;
    }

    private void OnVolumeChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        if (_loading) return;
        _settings.SoundVolume = e.NewValue;
    }

    private void OnAwakeToggled(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _settings.KeepScreenAwake = AwakeToggle.IsOn;
        KeepAwake.SetEnabled(SessionManager.Shared.IsRunning && AwakeToggle.IsOn);
    }

    private void OnFloatingToggled(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _settings.FloatingControlEnabled = FloatingToggle.IsOn;
    }

    private void OnCycleChanged(NumberBox sender, NumberBoxValueChangedEventArgs args)
    {
        if (_loading || double.IsNaN(args.NewValue)) return;
        _settings.FocusCycleMinutes = (int)args.NewValue;
    }

    private void OnPromptChanged(NumberBox sender, NumberBoxValueChangedEventArgs args)
    {
        if (_loading || double.IsNaN(args.NewValue)) return;
        _settings.MoodPromptMinutes = (int)args.NewValue;
    }
}
