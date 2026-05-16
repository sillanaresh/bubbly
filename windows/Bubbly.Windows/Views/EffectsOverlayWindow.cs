using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using Bubbly.Windows.Services;
using MediaBrush = System.Windows.Media.Brush;
using WpfPoint = System.Windows.Point;

namespace Bubbly.Windows.Views;

public sealed class EffectsOverlayWindow : Window
{
    private readonly string _action;
    private readonly WpfPoint _origin;
    private readonly RectD _frame;
    private readonly Canvas _canvas = new();
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(1.0 / 30.0) };
    private readonly List<Particle> _particles = [];
    private readonly Random _random = new();
    private DateTimeOffset _startedAt;

    public EffectsOverlayWindow(string action, WpfPoint origin, RectD frame)
    {
        _action = action;
        _origin = origin;
        _frame = frame;
        Left = frame.X;
        Top = frame.Y;
        Width = frame.Width;
        Height = frame.Height;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ShowActivated = false;
        Focusable = false;
        IsHitTestVisible = false;
        Content = _canvas;
        Loaded += (_, _) => Start();
        _timer.Tick += (_, _) => Tick();
    }

    private void Start()
    {
        _startedAt = DateTimeOffset.UtcNow;
        _particles.AddRange(CreateParticles());
        _timer.Start();
    }

    private void Tick()
    {
        var elapsed = (DateTimeOffset.UtcNow - _startedAt).TotalSeconds;
        var duration = _action == "rain" ? 2.0 : 1.7;
        var progress = Math.Clamp(elapsed / duration, 0, 1);
        _canvas.Children.Clear();

        foreach (var p in _particles)
        {
            var x = p.X + p.Dx * progress;
            var y = p.Y + p.Dy * progress;
            var opacity = Math.Max(0, p.Opacity * (1 - progress));
            UIElement element = p.Kind switch
            {
                "drop" => new Line { X1 = 0, Y1 = 0, X2 = 3, Y2 = p.Size * 1.7, StrokeThickness = 2, Stroke = new SolidColorBrush(Color.FromArgb(180, 75, 150, 230)), Opacity = opacity },
                "cloud" => new Ellipse { Width = p.Size * 1.6, Height = p.Size, Fill = new SolidColorBrush(Color.FromArgb(220, 210, 235, 255)), Opacity = opacity },
                "spark" => new TextBlock { Text = "*", FontSize = p.Size, FontWeight = FontWeights.Bold, Foreground = p.Brush, Opacity = opacity },
                _ => new Ellipse { Width = p.Size, Height = p.Size, Fill = p.Brush, Opacity = opacity }
            };
            Canvas.SetLeft(element, x - _frame.X);
            Canvas.SetTop(element, y - _frame.Y);
            _canvas.Children.Add(element);
        }

        if (progress >= 1)
        {
            _timer.Stop();
            Close();
        }
    }

    private IEnumerable<Particle> CreateParticles()
    {
        return _action switch
        {
            "rain" => Enumerable.Range(0, 130).Select(_ => new Particle(
                "drop",
                _frame.X + Next(0, _frame.Width),
                _frame.Y - 120 - Next(0, _frame.Height * 0.9),
                Next(-60, 90),
                _frame.Height + 260 + Next(0, 120),
                Next(8, 18),
                Brushes.DodgerBlue,
                Next(0.32, 0.74))),
            "cloud" => Enumerable.Range(0, 28).Select(i => new Particle(
                "cloud",
                _frame.X + Next(0, _frame.Width),
                _frame.Y + _frame.Height * Next(0.10, 0.52),
                Next(60, 170),
                -Next(10, 48),
                Next(42, 118),
                Brushes.LightSkyBlue,
                Next(0.55, 0.88))),
            "butterflies" => Enumerable.Range(0, 28).Select(i => new Particle(
                "spark",
                _frame.X + Next(0, _frame.Width),
                _frame.Y + _frame.Height * Next(0.32, 0.90),
                Next(-190, 190),
                -Next(120, 380),
                Next(16, 28),
                BrushFor(i),
                Next(0.6, 0.92))),
            "cannon" => Enumerable.Range(0, 34).Select(i =>
            {
                var angle = i * Math.PI / 17;
                var distance = Math.Min(Math.Min(_frame.Width, 760), Math.Min(_frame.Height, 520)) * 0.42;
                return new Particle("dot", _origin.X, _origin.Y, Math.Cos(angle) * distance, Math.Sin(angle) * distance, Next(7, 16), BrushFor(i), 0.92);
            }),
            _ => Enumerable.Range(0, 34).Select(i => new Particle(
                "spark",
                _frame.X + Next(0, _frame.Width),
                _frame.Y + _frame.Height * Next(0.10, 0.88),
                0,
                -Next(10, 54),
                Next(14, 30),
                BrushFor(i),
                0.9))
        };
    }

    private MediaBrush BrushFor(int index)
    {
        Brush[] brushes =
        [
            Brushes.DeepPink,
            Brushes.MediumPurple,
            Brushes.Orange,
            Brushes.Gold,
            Brushes.Cyan
        ];
        return brushes[index % brushes.Length];
    }

    private double Next(double min, double max) => min + _random.NextDouble() * (max - min);

    private sealed record Particle(string Kind, double X, double Y, double Dx, double Dy, double Size, MediaBrush Brush, double Opacity);
}
