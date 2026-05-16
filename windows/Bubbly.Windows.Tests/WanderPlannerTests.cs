using Bubbly.Windows.Services;
using Xunit;

namespace Bubbly.Windows.Tests;

public sealed class WanderPlannerTests
{
    [Fact]
    public void WanderBoundsAvoidsEdgesAndTopWhenSmartPositioningIsEnabled()
    {
        var planner = new WanderPlanner(123);
        var bounds = planner.WanderBounds(new RectD(0, 0, 1200, 800), new SizeD(144, 144), true);

        Assert.Equal(28, bounds.MinX);
        Assert.Equal(28, bounds.MinY);
        Assert.Equal(1028, bounds.MaxX);
        Assert.Equal(512, bounds.MaxY);
    }

    [Fact]
    public void NextTargetStaysInsideBounds()
    {
        var planner = new WanderPlanner(456);
        var bounds = new RectD(28, 28, 900, 500);

        for (var i = 0; i < 20; i++)
        {
            var target = planner.NextTarget(new PointD(320, 240), bounds);
            Assert.InRange(target.X, bounds.MinX, bounds.MaxX);
            Assert.InRange(target.Y, bounds.MinY, bounds.MaxY);
        }
    }

    [Fact]
    public void MotionEndsAtPlannedTarget()
    {
        var motion = new WanderMotion(
            new PointD(0, 0),
            new PointD(10, 0),
            new PointD(20, 10),
            new PointD(30, 30),
            DateTimeOffset.UnixEpoch,
            TimeSpan.FromSeconds(3));

        Assert.Equal(new PointD(0, 0), motion.PointAt(0));
        Assert.Equal(new PointD(30, 30), motion.PointAt(1));
    }
}
