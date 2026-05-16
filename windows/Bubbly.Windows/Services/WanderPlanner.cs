using System;

namespace Bubbly.Windows.Services;

public sealed class WanderPlanner
{
    private readonly Random _random;

    public WanderPlanner(int? seed = null)
    {
        _random = seed.HasValue ? new Random(seed.Value) : new Random();
    }

    public RectD WanderBounds(RectD visibleFrame, SizeD windowSize, bool smartPositioningEnabled)
    {
        const double margin = 28;
        var topAvoidance = smartPositioningEnabled ? Math.Min(150, visibleFrame.Height * 0.18) : margin;
        var minX = visibleFrame.MinX + margin;
        var maxX = visibleFrame.MaxX - windowSize.Width - margin;
        var minY = visibleFrame.MinY + margin;
        var maxY = visibleFrame.MaxY - windowSize.Height - topAvoidance;

        return maxX > minX && maxY > minY
            ? new RectD(minX, minY, maxX - minX, maxY - minY)
            : visibleFrame;
    }

    public WanderMotion CreateMotion(PointD current, RectD visibleFrame, SizeD windowSize, bool smartPositioningEnabled, DateTimeOffset startedAt)
    {
        var bounds = WanderBounds(visibleFrame, windowSize, smartPositioningEnabled);
        var target = NextTarget(current, bounds);
        var dx = target.X - current.X;
        var dy = target.Y - current.Y;
        var distance = Math.Max(Math.Sqrt(dx * dx + dy * dy), 1);
        var duration = TimeSpan.FromSeconds(Math.Clamp(distance / 48, 3.2, 7.2));
        var perpendicularX = -dy / distance;
        var perpendicularY = dx / distance;
        var bend = NextDouble(-0.42, 0.42) * Math.Clamp(distance * 0.45, 60, 180);

        var control1 = ClampToBounds(new PointD(
            current.X + dx * 0.34 + perpendicularX * bend,
            current.Y + dy * 0.34 + perpendicularY * bend), bounds);
        var control2 = ClampToBounds(new PointD(
            current.X + dx * 0.72 - perpendicularX * bend * 0.7,
            current.Y + dy * 0.72 - perpendicularY * bend * 0.7), bounds);

        return new WanderMotion(current, control1, control2, target, startedAt, duration);
    }

    public PointD NextTarget(PointD current, RectD bounds)
    {
        if (bounds.Width <= 0 || bounds.Height <= 0)
        {
            return current;
        }

        var maximumDistance = Math.Min(Math.Max(bounds.Width, bounds.Height) * 0.42, 420);
        var minimumDistance = Math.Min(Math.Max(Math.Min(bounds.Width, bounds.Height) * 0.20, 120), 220);

        for (var i = 0; i < 14; i++)
        {
            var angle = NextDouble(0, Math.PI * 2);
            var distance = NextDouble(minimumDistance, Math.Max(minimumDistance + 1, maximumDistance));
            var candidate = ClampToBounds(new PointD(
                current.X + Math.Cos(angle) * distance,
                current.Y + Math.Sin(angle) * distance), bounds);
            var dx = candidate.X - current.X;
            var dy = candidate.Y - current.Y;
            if (Math.Abs(dx) >= 64 && Math.Abs(dy) >= 48 && Math.Sqrt(dx * dx + dy * dy) >= minimumDistance * 0.75)
            {
                return candidate;
            }
        }

        var targetMinX = current.X < bounds.MidX ? bounds.MidX : bounds.MinX;
        var targetMaxX = current.X < bounds.MidX ? bounds.MaxX : bounds.MidX;
        var targetMinY = current.Y < bounds.MidY ? bounds.MidY : bounds.MinY;
        var targetMaxY = current.Y < bounds.MidY ? bounds.MaxY : bounds.MidY;
        return new PointD(NextDouble(targetMinX, targetMaxX), NextDouble(targetMinY, targetMaxY));
    }

    private PointD ClampToBounds(PointD point, RectD bounds)
    {
        return new PointD(
            Math.Clamp(point.X, bounds.MinX, bounds.MaxX),
            Math.Clamp(point.Y, bounds.MinY, bounds.MaxY));
    }

    private double NextDouble(double min, double max)
    {
        return min + _random.NextDouble() * (max - min);
    }
}

public sealed record WanderMotion(
    PointD Start,
    PointD Control1,
    PointD Control2,
    PointD End,
    DateTimeOffset StartedAt,
    TimeSpan Duration)
{
    public PointD PointAt(double progress)
    {
        var t = Math.Clamp(progress, 0, 1);
        var inverse = 1 - t;
        var x = inverse * inverse * inverse * Start.X
            + 3 * inverse * inverse * t * Control1.X
            + 3 * inverse * t * t * Control2.X
            + t * t * t * End.X;
        var y = inverse * inverse * inverse * Start.Y
            + 3 * inverse * inverse * t * Control1.Y
            + 3 * inverse * t * t * Control2.Y
            + t * t * t * End.Y;
        return new PointD(x, y);
    }
}
