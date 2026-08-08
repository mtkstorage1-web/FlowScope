using System.ComponentModel;
using FlowScopeWindows.Controls;
using FlowScopeWindows.Services;
using FlowScopeWindows.Theme;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Navigation;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;

namespace FlowScopeWindows.Views;

public sealed partial class TimerPage : Page
{
    private readonly SessionManager _session = SessionManager.Shared;
    private readonly AppSettings _settings = AppSettings.Shared;

    private const double RingSize = 320;
    private const double RingInset = 10;

    public TimerPage()
    {
        InitializeComponent();

        _session.PropertyChanged += OnSessionChanged;
        _session.CycleCompleted += OnCycleCompleted;
        _session.MoodPromptDue += OnMoodPromptDue;

        Unloaded += (_, _) =>
        {
            _session.PropertyChanged -= OnSessionChanged;
            _session.CycleCompleted -= OnCycleCompleted;
            _session.MoodPromptDue -= OnMoodPromptDue;
        };
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        DrawParticles();
        Sync();
    }

    // MARK: - State → UI

    private void OnSessionChanged(object? sender, PropertyChangedEventArgs e) => Sync();

    private void Sync()
    {
        ElapsedText.Text = _session.ElapsedDisplay;
        SessionNameText.Text = _session.IsActive ? _session.SessionName : "Ready when you are";
        SessionCategoryText.Text = _session.IsActive ? _session.SessionCategory : string.Empty;

        MoodCountText.Text = _session.IsActive ? $"{_session.MoodCount} logs" : string.Empty;
        CurrentMoodText.Text = _session is { IsActive: true, MoodCount: > 0 }
            ? $"{_session.CurrentMood}% focus"
            : string.Empty;

        // Play when idle or paused, pause while running.
        PrimaryIcon.Glyph = _session.IsRunning ? "\uE769" : "\uE768"; // Pause : Play

        StopButton.Visibility = _session.IsActive ? Visibility.Visible : Visibility.Collapsed;
        LogMoodButton.Visibility = _session.IsActive ? Visibility.Visible : Visibility.Collapsed;

        FloatingControl.Visibility = _session.IsRunning && _settings.FloatingControlEnabled
            ? Visibility.Visible
            : Visibility.Collapsed;

        UpdateRing();
    }

    /// <summary>
    /// The ring tracks progress through the current focus cycle. With cycles
    /// switched off there is no target to fill toward, so it shows a slow
    /// minute sweep instead of sitting empty.
    /// </summary>
    private void UpdateRing()
    {
        var cycleSeconds = _settings.FocusCycleMinutes * 60;
        var fraction = cycleSeconds > 0
            ? _session.ElapsedSeconds % cycleSeconds / cycleSeconds
            : _session.ElapsedSeconds % 60 / 60;

        if (!_session.IsActive) fraction = 0;

        RingProgress.Data = ArcGeometry(fraction);
    }

    /// <summary>Arc from 12 o'clock, clockwise, as a fraction of the circle.</summary>
    private static Geometry ArcGeometry(double fraction)
    {
        fraction = Math.Clamp(fraction, 0, 0.9999);
        var radius = RingSize / 2;
        var centre = new Point(RingInset + radius, RingInset + radius);

        if (fraction <= 0.0001)
        {
            return new PathGeometry();
        }

        var angle = fraction * 2 * Math.PI;
        var start = new Point(centre.X, centre.Y - radius);
        var end = new Point(
            centre.X + radius * Math.Sin(angle),
            centre.Y - radius * Math.Cos(angle));

        var figure = new PathFigure { StartPoint = start, IsClosed = false };
        figure.Segments.Add(new ArcSegment
        {
            Point = end,
            Size = new Size(radius, radius),
            SweepDirection = SweepDirection.Clockwise,
            IsLargeArc = fraction > 0.5,
        });

        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);
        return geometry;
    }

    // MARK: - Commands

    private async void OnPrimaryClick(object sender, RoutedEventArgs e)
    {
        if (_session.IsRunning)
        {
            _session.PauseSession();
            SoundService.Shared.Play(SoundCue.Pause);
            return;
        }

        if (_session.IsPaused)
        {
            _session.ResumeSession();
            SoundService.Shared.Play(SoundCue.Resume);
            return;
        }

        var dialog = new SessionSetupDialog { XamlRoot = XamlRoot };
        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            _session.StartSession(dialog.SessionName, dialog.Category);
            SoundService.Shared.Play(SoundCue.Start);
        }
    }

    private async void OnStopClick(object sender, RoutedEventArgs e)
    {
        var confirm = new ContentDialog
        {
            XamlRoot = XamlRoot,
            Title = "End session?",
            Content = $"'{_session.SessionName}' will be saved with {_session.MoodCount} mood logs.",
            PrimaryButtonText = "End",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
        };

        if (await confirm.ShowAsync() == ContentDialogResult.Primary)
        {
            await _session.StopSessionAsync();
            SoundService.Shared.Play(SoundCue.Stop);
            Sync();
        }
    }

    private async void OnLogMoodClick(object sender, RoutedEventArgs e)
    {
        var dialog = new MoodDialog { XamlRoot = XamlRoot, Satisfaction = _session.CurrentMood };
        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            _session.LogMood(dialog.Satisfaction, dialog.Note);
            SoundService.Shared.Play(SoundCue.MoodLogged);
        }
    }

    private void OnQuickMoodChanged(object sender, RangeBaseValueChangedEventArgs e)
    {
        if (QuickMoodValue is not null) QuickMoodValue.Text = ((int)e.NewValue).ToString();
    }

    private void OnQuickLogClick(object sender, RoutedEventArgs e)
    {
        _session.LogMood((int)QuickMoodSlider.Value);
        SoundService.Shared.Play(SoundCue.MoodLogged);
    }

    private void OnCycleCompleted(object? sender, EventArgs e)
    {
        // A one-shot flash so a completed cycle is felt, not just heard.
        var flash = new DoubleAnimation
        {
            From = 0.35,
            To = 0,
            Duration = new Duration(TimeSpan.FromSeconds(0.9)),
            EnableDependentAnimation = true,
        };

        var overlay = new Rectangle
        {
            Fill = ThemeManager.Shared.PrimaryBrush,
            IsHitTestVisible = false,
            Opacity = 0.35,
        };

        if (Content is Grid root)
        {
            root.Children.Add(overlay);
            Storyboard.SetTarget(flash, overlay);
            Storyboard.SetTargetProperty(flash, "Opacity");

            var storyboard = new Storyboard();
            storyboard.Children.Add(flash);
            storyboard.Completed += (_, _) => root.Children.Remove(overlay);
            storyboard.Begin();
        }
    }

    private async void OnMoodPromptDue(object? sender, EventArgs e)
    {
        if (!_session.IsRunning) return;
        OnLogMoodClick(this, new RoutedEventArgs());
        await Task.CompletedTask;
    }

    // MARK: - Background field

    /// <summary>
    /// A lightweight stand-in for the per-theme Canvas art on Apple platforms:
    /// same colours and density, drawn once as static geometry.
    /// </summary>
    private void DrawParticles()
    {
        ParticleCanvas.Children.Clear();
        var config = ThemeManager.Shared.Configuration;
        var random = new Random(config.Theme.GetHashCode());

        switch (config.Particles)
        {
            case ParticleStyle.RetroGrid:
                for (var i = 0; i < 24; i++)
                {
                    ParticleCanvas.Children.Add(new Line
                    {
                        X1 = 0, Y1 = 220 + i * 26,
                        X2 = 2000, Y2 = 220 + i * 26,
                        Stroke = ThemeManager.Shared.PrimaryBrush,
                        StrokeThickness = 1,
                        Opacity = 0.10,
                    });
                }
                break;

            case ParticleStyle.Scanlines:
                for (var i = 0; i < 90; i++)
                {
                    ParticleCanvas.Children.Add(new Line
                    {
                        X1 = 0, Y1 = i * 10,
                        X2 = 2000, Y2 = i * 10,
                        Stroke = ThemeManager.Shared.PrimaryBrush,
                        StrokeThickness = 1,
                        Opacity = 0.06,
                    });
                }
                break;

            default:
                // Embers / carbon speckle for every other theme.
                for (var i = 0; i < 70; i++)
                {
                    var dot = new Ellipse
                    {
                        Width = random.Next(2, 6),
                        Height = random.Next(2, 6),
                        Fill = ThemeManager.Shared.PrimaryBrush,
                        Opacity = 0.05 + random.NextDouble() * 0.15,
                    };
                    Canvas.SetLeft(dot, random.Next(0, 1400));
                    Canvas.SetTop(dot, random.Next(0, 900));
                    ParticleCanvas.Children.Add(dot);
                }
                break;
        }
    }
}
