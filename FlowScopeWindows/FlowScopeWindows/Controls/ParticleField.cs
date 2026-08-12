using System.Diagnostics;
using FlowScopeWindows.Theme;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;

namespace FlowScopeWindows.Controls;

/// <summary>
/// Drives the timer page's themed background field with real per-frame
/// motion, the retained-tree analogue of the Apple build's
/// <c>TimelineView(.animation) { Canvas { ... } }</c> particle renderer.
///
/// Rather than redrawing 70-90 shapes from scratch every frame (cheap in
/// SwiftUI's immediate-mode Canvas, expensive against XAML's retained tree),
/// a fixed pool of shapes is built once per <see cref="Start"/> and only their
/// transform/opacity is touched on <see cref="CompositionTarget.Rendering"/>.
/// </summary>
public sealed class ParticleField
{
    private readonly Canvas _host;
    private readonly Stopwatch _clock = new();
    private readonly Random _random;
    private readonly List<Ember> _embers = new();
    private readonly List<Crack> _cracks = new();
    private readonly List<Speckle> _speckles = new();
    private readonly List<Line> _gridLines = new();
    private readonly List<Line> _scanLines = new();

    private ParticleStyle _style = ParticleStyle.Carbon;
    private double _width = 1400;
    private double _height = 900;
    private bool _running;

    public ParticleField(Canvas host, int seed)
    {
        _host = host;
        _random = new Random(seed);
    }

    /// <summary>Rebuilds the pool for <paramref name="config"/> and starts animating it.</summary>
    public void Start(ThemeConfiguration config)
    {
        Stop();

        _width = _host.ActualWidth > 0 ? _host.ActualWidth : 1400;
        _height = _host.ActualHeight > 0 ? _host.ActualHeight : 900;

        _host.Children.Clear();
        _embers.Clear();
        _cracks.Clear();
        _speckles.Clear();
        _gridLines.Clear();
        _scanLines.Clear();

        _style = config.Particles;
        var primary = new SolidColorBrush(config.Primary);
        var glow = new SolidColorBrush(config.Glow);

        switch (_style)
        {
            case ParticleStyle.Fire:
                BuildEmbers(glow, primary);
                break;
            case ParticleStyle.LavaCracks:
                BuildCracks(primary, glow);
                break;
            case ParticleStyle.RetroGrid:
                BuildGrid(primary);
                break;
            case ParticleStyle.Scanlines:
                BuildScanlines(primary);
                break;
            case ParticleStyle.Carbon:
            default:
                BuildSpeckles(primary);
                break;
        }

        _clock.Restart();
        _running = true;
        CompositionTarget.Rendering += OnRendering;
    }

    public void Stop()
    {
        if (!_running) return;
        _running = false;
        _clock.Stop();
        CompositionTarget.Rendering -= OnRendering;
    }

    private void OnRendering(object? sender, object e)
    {
        var t = _clock.Elapsed.TotalSeconds;
        switch (_style)
        {
            case ParticleStyle.Fire: AnimateEmbers(t); break;
            case ParticleStyle.LavaCracks: AnimateCracks(t); break;
            case ParticleStyle.RetroGrid: AnimateGrid(t); break;
            case ParticleStyle.Scanlines: AnimateScanlines(t); break;
            case ParticleStyle.Carbon: default: AnimateSpeckles(t); break;
        }
    }

    // MARK: - Fire: embers drifting up, swaying, fading, respawning

    private readonly record struct Ember(Ellipse Shape, double BaseX, double SwayAmplitude, double SwayFrequency, double Phase, double Speed, double CycleLength);

    private void BuildEmbers(SolidColorBrush glow, SolidColorBrush primary)
    {
        for (var i = 0; i < 70; i++)
        {
            var size = 2 + _random.NextDouble() * 4;
            var shape = new Ellipse
            {
                Width = size,
                Height = size,
                Fill = _random.NextDouble() < 0.35 ? glow : primary,
            };
            _host.Children.Add(shape);

            var ember = new Ember(
                Shape: shape,
                BaseX: _random.NextDouble() * _width,
                SwayAmplitude: 8 + _random.NextDouble() * 18,
                SwayFrequency: 0.4 + _random.NextDouble() * 0.8,
                Phase: _random.NextDouble() * Math.PI * 2,
                Speed: 18 + _random.NextDouble() * 30,
                CycleLength: _height + 60);

            // Stagger initial position along the whole cycle, not all at the bottom.
            Canvas.SetTop(shape, _height - _random.NextDouble() * ember.CycleLength);
            _embers.Add(ember);
        }
    }

    private void AnimateEmbers(double t)
    {
        foreach (var ember in _embers)
        {
            var travelled = (t * ember.Speed) % ember.CycleLength;
            var y = _height - travelled;
            var x = ember.BaseX + ember.SwayAmplitude * Math.Sin(t * ember.SwayFrequency + ember.Phase);

            // Fade in near the bottom, fade out near the top.
            var progress = travelled / ember.CycleLength;
            var opacity = progress < 0.12
                ? progress / 0.12
                : progress > 0.85 ? (1 - progress) / 0.15 : 1.0;

            Canvas.SetLeft(ember.Shape, x);
            Canvas.SetTop(ember.Shape, y);
            ember.Shape.Opacity = Math.Clamp(opacity, 0, 1) * 0.55;
        }
    }

    // MARK: - Lava cracks: static jagged fissures with pulsing glow

    private readonly record struct Crack(Line Dim, Line Hot, double Phase, double Speed);

    private void BuildCracks(SolidColorBrush primary, SolidColorBrush glow)
    {
        for (var i = 0; i < 16; i++)
        {
            var x1 = _random.NextDouble() * _width;
            var y1 = _random.NextDouble() * _height;
            var length = 40 + _random.NextDouble() * 90;
            var angle = _random.NextDouble() * Math.PI * 2;
            var x2 = x1 + Math.Cos(angle) * length;
            var y2 = y1 + Math.Sin(angle) * length;

            var dim = new Line { X1 = x1, Y1 = y1, X2 = x2, Y2 = y2, Stroke = primary, StrokeThickness = 3, Opacity = 0.12 };
            var hot = new Line { X1 = x1, Y1 = y1, X2 = x2, Y2 = y2, Stroke = glow, StrokeThickness = 1.2, Opacity = 0.25 };
            _host.Children.Add(dim);
            _host.Children.Add(hot);

            _cracks.Add(new Crack(dim, hot, _random.NextDouble() * Math.PI * 2, 0.3 + _random.NextDouble() * 0.5));
        }
    }

    private void AnimateCracks(double t)
    {
        foreach (var crack in _cracks)
        {
            var pulse = (Math.Sin(t * crack.Speed + crack.Phase) + 1) / 2; // 0..1
            crack.Dim.Opacity = 0.08 + pulse * 0.12;
            crack.Hot.Opacity = 0.10 + pulse * 0.35;
        }
    }

    // MARK: - Carbon: fine, mostly-static speckle with very slow drift

    private readonly record struct Speckle(Ellipse Shape, double BaseX, double BaseY, double DriftAmplitude, double Phase);

    private void BuildSpeckles(SolidColorBrush primary)
    {
        for (var i = 0; i < 90; i++)
        {
            var size = 1 + _random.NextDouble() * 2.5;
            var shape = new Ellipse { Width = size, Height = size, Fill = primary, Opacity = 0.04 + _random.NextDouble() * 0.1 };
            _host.Children.Add(shape);

            _speckles.Add(new Speckle(
                shape,
                _random.NextDouble() * _width,
                _random.NextDouble() * _height,
                2 + _random.NextDouble() * 4,
                _random.NextDouble() * Math.PI * 2));
        }
    }

    private void AnimateSpeckles(double t)
    {
        foreach (var speckle in _speckles)
        {
            var x = speckle.BaseX + speckle.DriftAmplitude * Math.Sin(t * 0.08 + speckle.Phase);
            var y = speckle.BaseY + speckle.DriftAmplitude * Math.Cos(t * 0.06 + speckle.Phase);
            Canvas.SetLeft(speckle.Shape, x);
            Canvas.SetTop(speckle.Shape, y);
        }
    }

    // MARK: - Retro grid: horizon lines scrolling toward the viewer

    private void BuildGrid(SolidColorBrush primary)
    {
        for (var i = 0; i < 24; i++)
        {
            var line = new Line { X1 = 0, X2 = _width > 0 ? _width : 2000, Stroke = primary, StrokeThickness = 1, Opacity = 0.10 };
            _host.Children.Add(line);
            _gridLines.Add(line);
        }
    }

    private void AnimateGrid(double t)
    {
        const double spacing = 26;
        const double speed = 34;
        var span = spacing * _gridLines.Count;

        for (var i = 0; i < _gridLines.Count; i++)
        {
            // Lines scroll downward and wrap, giving a moving-horizon feel.
            var y = (220 + i * spacing + t * speed) % span + 200;
            _gridLines[i].Y1 = y;
            _gridLines[i].Y2 = y;

            // Lines further "away" (smaller index after wrap) read fainter.
            var fade = 1 - Math.Clamp((y - 200) / span, 0, 1) * 0.6;
            _gridLines[i].Opacity = 0.10 * fade;
        }
    }

    // MARK: - Scanlines: static rows with a slow flicker sweep

    private void BuildScanlines(SolidColorBrush primary)
    {
        for (var i = 0; i < 90; i++)
        {
            var line = new Line
            {
                X1 = 0, Y1 = i * 10, X2 = _width > 0 ? _width : 2000, Y2 = i * 10,
                Stroke = primary, StrokeThickness = 1, Opacity = 0.06,
            };
            _host.Children.Add(line);
            _scanLines.Add(line);
        }
    }

    private void AnimateScanlines(double t)
    {
        // A faint band of brighter lines drifts down the field on a slow loop.
        var bandCenter = (t * 14) % (_scanLines.Count + 20);
        for (var i = 0; i < _scanLines.Count; i++)
        {
            var distance = Math.Abs(i - bandCenter);
            var boost = distance < 5 ? (5 - distance) / 5 * 0.14 : 0;
            _scanLines[i].Opacity = 0.06 + boost;
        }
    }
}
