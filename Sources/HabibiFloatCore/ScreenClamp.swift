import Foundation

public enum ScreenClamp {
    public static func clampedOrigin(
        _ origin: Point2D,
        windowSize: Size2D,
        visibleFrame: Rect2D,
        margin: Double = 16
    ) -> Point2D {
        let minX = visibleFrame.x + margin
        let minY = visibleFrame.y + margin
        let maxX = visibleFrame.maxX - windowSize.width - margin
        let maxY = visibleFrame.maxY - windowSize.height - margin

        if maxX < minX || maxY < minY {
            return Point2D(
                x: visibleFrame.midX - windowSize.width / 2,
                y: visibleFrame.midY - windowSize.height / 2
            )
        }

        return Point2D(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    public static func defaultOrigin(windowSize: Size2D, visibleFrame: Rect2D, margin: Double = 48) -> Point2D {
        clampedOrigin(
            Point2D(
                x: visibleFrame.maxX - windowSize.width - margin,
                y: visibleFrame.maxY - windowSize.height - margin
            ),
            windowSize: windowSize,
            visibleFrame: visibleFrame,
            margin: 16
        )
    }
}
