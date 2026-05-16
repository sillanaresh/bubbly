using System;

namespace Bubbly.Windows.Services;

public sealed record PointD(double X, double Y);
public sealed record SizeD(double Width, double Height);
public sealed record RectD(double X, double Y, double Width, double Height)
{
    public double MinX => X;
    public double MaxX => X + Width;
    public double MinY => Y;
    public double MaxY => Y + Height;
    public double MidX => X + Width / 2;
    public double MidY => Y + Height / 2;
}

public static class ScreenClamp
{
    public static PointD DefaultOrigin(SizeD windowSize, RectD visibleFrame)
    {
        return new PointD(
            visibleFrame.MaxX - windowSize.Width - 42,
            visibleFrame.MinY + visibleFrame.Height * 0.62);
    }

    public static PointD ClampedOrigin(PointD origin, SizeD windowSize, RectD visibleFrame)
    {
        var minX = visibleFrame.MinX;
        var maxX = Math.Max(minX, visibleFrame.MaxX - windowSize.Width);
        var minY = visibleFrame.MinY;
        var maxY = Math.Max(minY, visibleFrame.MaxY - windowSize.Height);

        return new PointD(
            Math.Clamp(origin.X, minX, maxX),
            Math.Clamp(origin.Y, minY, maxY));
    }
}
