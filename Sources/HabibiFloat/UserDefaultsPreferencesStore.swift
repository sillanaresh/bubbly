import Foundation
import HabibiFloatCore

final class UserDefaultsPreferencesStore {
    private enum Key {
        static let isVisible = "habibiFloat.isVisible"
        static let isPaused = "habibiFloat.isPaused"
        static let lastX = "habibiFloat.lastX"
        static let lastY = "habibiFloat.lastY"
        static let clickSoundID = "habibiFloat.clickSoundID"
        static let soundVolumeID = "habibiFloat.soundVolumeID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> BubblePreferences {
        let isVisible = defaults.object(forKey: Key.isVisible) as? Bool ?? true
        let isPaused = defaults.object(forKey: Key.isPaused) as? Bool ?? false
        let clickSoundID = defaults.string(forKey: Key.clickSoundID) ?? BubblePreferences.defaultClickSoundID
        let soundVolumeID = defaults.string(forKey: Key.soundVolumeID) ?? BubblePreferences.defaultSoundVolumeID

        let point: Point2D?
        if defaults.object(forKey: Key.lastX) != nil, defaults.object(forKey: Key.lastY) != nil {
            point = Point2D(x: defaults.double(forKey: Key.lastX), y: defaults.double(forKey: Key.lastY))
        } else {
            point = nil
        }

        return BubblePreferences(
            isVisible: isVisible,
            isPaused: isPaused,
            lastPosition: point,
            clickSoundID: clickSoundID,
            soundVolumeID: soundVolumeID
        )
    }

    func save(_ preferences: BubblePreferences) {
        defaults.set(preferences.isVisible, forKey: Key.isVisible)
        defaults.set(preferences.isPaused, forKey: Key.isPaused)
        defaults.set(preferences.clickSoundID, forKey: Key.clickSoundID)
        defaults.set(preferences.soundVolumeID, forKey: Key.soundVolumeID)

        if let lastPosition = preferences.lastPosition {
            defaults.set(lastPosition.x, forKey: Key.lastX)
            defaults.set(lastPosition.y, forKey: Key.lastY)
        } else {
            defaults.removeObject(forKey: Key.lastX)
            defaults.removeObject(forKey: Key.lastY)
        }
    }
}
