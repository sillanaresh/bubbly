using Bubbly.Windows.Services;
using Xunit;

namespace Bubbly.Windows.Tests;

public sealed class ScreenClampTests
{
    [Fact]
    public void ClampKeepsWindowInsideVisibleFrame()
    {
        var frame = new RectD(10, 20, 800, 600);
        var result = ScreenClamp.ClampedOrigin(new PointD(900, -100), new SizeD(144, 144), frame);

        Assert.Equal(666, result.X);
        Assert.Equal(20, result.Y);
    }

    [Fact]
    public void DefaultOriginStartsNearRightSide()
    {
        var frame = new RectD(0, 0, 1000, 800);
        var origin = ScreenClamp.DefaultOrigin(new SizeD(144, 144), frame);

        Assert.Equal(814, origin.X);
        Assert.Equal(496, origin.Y);
    }
}
