import Testing
@testable import HabibiFloatCore

@Test func clampedOriginKeepsBubbleInsideVisibleFrame() {
    let clamped = ScreenClamp.clampedOrigin(
        Point2D(x: -200, y: 900),
        windowSize: Size2D(width: 168, height: 168),
        visibleFrame: Rect2D(x: 0, y: 0, width: 800, height: 600),
        margin: 16
    )

    #expect(clamped == Point2D(x: 16, y: 416))
}

@Test func clampedOriginCentersWhenWindowIsLargerThanVisibleFrame() {
    let clamped = ScreenClamp.clampedOrigin(
        Point2D(x: 0, y: 0),
        windowSize: Size2D(width: 500, height: 500),
        visibleFrame: Rect2D(x: 100, y: 200, width: 200, height: 200)
    )

    #expect(clamped == Point2D(x: -50, y: 50))
}

@Test func defaultOriginStartsNearTopRightButStillVisible() {
    let origin = ScreenClamp.defaultOrigin(
        windowSize: Size2D(width: 168, height: 168),
        visibleFrame: Rect2D(x: 0, y: 0, width: 1000, height: 700)
    )

    #expect(origin == Point2D(x: 784, y: 484))
}

@Test func preferencesDefaultToVisibleAndRunning() {
    let preferences = BubblePreferences()

    #expect(preferences.isVisible)
    #expect(!preferences.isPaused)
    #expect(preferences.lastPosition == nil)
    #expect(preferences.clickSoundID == BubblePreferences.defaultClickSoundID)
    #expect(preferences.soundVolumeID == BubblePreferences.defaultSoundVolumeID)
    #expect(preferences.themeID == BubblePreferences.defaultThemeID)
    #expect(preferences.moodID == BubblePreferences.defaultMoodID)
    #expect(preferences.characterID == BubblePreferences.defaultCharacterID)
    #expect(preferences.smartPositioningEnabled)
}
