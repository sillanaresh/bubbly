import Foundation

public struct BubblePreferences: Codable, Equatable, Sendable {
    public static let defaultClickSoundID = "waterDrop"
    public static let defaultSoundVolumeID = "normal"
    public static let defaultThemeID = "ocean"
    public static let defaultMoodID = "happy"
    public static let defaultCharacterID = "bubble"

    public var isVisible: Bool
    public var isPaused: Bool
    public var lastPosition: Point2D?
    public var clickSoundID: String
    public var soundVolumeID: String
    public var themeID: String
    public var moodID: String
    public var characterID: String
    public var smartPositioningEnabled: Bool

    public init(
        isVisible: Bool = true,
        isPaused: Bool = false,
        lastPosition: Point2D? = nil,
        clickSoundID: String = Self.defaultClickSoundID,
        soundVolumeID: String = Self.defaultSoundVolumeID,
        themeID: String = Self.defaultThemeID,
        moodID: String = Self.defaultMoodID,
        characterID: String = Self.defaultCharacterID,
        smartPositioningEnabled: Bool = true
    ) {
        self.isVisible = isVisible
        self.isPaused = isPaused
        self.lastPosition = lastPosition
        self.clickSoundID = clickSoundID
        self.soundVolumeID = soundVolumeID
        self.themeID = themeID
        self.moodID = moodID
        self.characterID = characterID
        self.smartPositioningEnabled = smartPositioningEnabled
    }
}
