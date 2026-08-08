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

            var cell = new StackPanel
            {
                Spacing = 6,
                Width = 92,
                Margin = new Thickness(4),
                Tag = theme,
                Children =
                {
                    swatch,
                    new TextBlock
                    {
                        Text = theme.DisplayName(),
                        HorizontalAlignment = HorizontalAlignment.Center,
                        FontSize = 12,
                        Foreground = ThemeManager.Shared.TextSecondaryBrush,
                    },
                },
            };

            swatch.HorizontalAlignment = HorizontalAlignment.Center;
            ThemeGrid.Items.Add(cell);

            if (theme == _settings.Theme) ThemeGrid.SelectedItem = cell;
        }
    }

    private void OnThemeSelected(object sender, SelectionChangedEventArgs e)
    {
        if (_loading) return;
        if (ThemeGrid.SelectedItem is not StackPanel { Tag: AppTheme theme }) return;

        ThemeManager.Shared.Apply(theme);

        // Repaint the swatch rings and the labels against the new palette.
        _loading = true;
        BuildThemeGrid();
        _loading = false;
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
