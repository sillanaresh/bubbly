import Foundation

public struct BubblePreferences: Codable, Equatable, Sendable {
    public static let defaultClickSoundID = "waterDrop"
    public static let defaultSoundVolumeID = "normal"

    public var isVisible: Bool
    public var isPaused: Bool
    public var lastPosition: Point2D?
    public var clickSoundID: String
    public var soundVolumeID: String

    public init(
        isVisible: Bool = true,
        isPaused: Bool = false,
        lastPosition: Point2D? = nil,
        clickSoundID: String = Self.defaultClickSoundID,
        soundVolumeID: String = Self.defaultSoundVolumeID
    ) {
        self.isVisible = isVisible
        self.isPaused = isPaused
        self.lastPosition = lastPosition
        self.clickSoundID = clickSoundID
        self.soundVolumeID = soundVolumeID
    }
}
