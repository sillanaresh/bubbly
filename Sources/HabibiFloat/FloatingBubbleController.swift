import AppKit
import HabibiFloatCore
import SwiftUI

@MainActor
final class FloatingBubbleController {
    var contextMenuProvider: (() -> NSMenu?)?
    var onStateChanged: (() -> Void)?

    private let preferencesStore: UserDefaultsPreferencesStore
    private let visualState = BubbleVisualState()
    private let soundPlayer = BubbleSoundPlayer()
    private let windowSize = NSSize(width: 144, height: 144)
    private let movementSpeed: CGFloat = 26

    private var window: NSPanel?
    private var preferences: BubblePreferences
    private var movementTimer: Timer?
    private var movementTarget: NSPoint?
    private var lastMovementTick = Date()
    private var lastPositionSave = Date.distantPast

    init(preferences: UserDefaultsPreferencesStore) {
        self.preferencesStore = preferences
        self.preferences = preferences.load()
        self.visualState.isPaused = self.preferences.isPaused
        applyAppearanceState()
        observeScreenChanges()
    }

    var isVisible: Bool {
        preferences.isVisible
    }

    var isPaused: Bool {
        preferences.isPaused
    }

    var clickSoundID: String {
        preferences.clickSoundID
    }

    var soundVolumeID: String {
        preferences.soundVolumeID
    }

    var themeID: String {
        preferences.themeID
    }

    var moodID: String {
        preferences.moodID
    }

    var characterID: String {
        preferences.characterID
    }

    var smartPositioningEnabled: Bool {
        preferences.smartPositioningEnabled
    }

    func setClickSound(_ preset: BubbleSoundPreset) {
        preferences.clickSoundID = preset.rawValue
        persistCurrentState()
        onStateChanged?()

        if preset != .muted {
            soundPlayer.play(presetID: preset.rawValue, volumeID: preferences.soundVolumeID)
        }
    }

    func setSoundVolume(_ volume: BubbleSoundVolume) {
        preferences.soundVolumeID = volume.rawValue
        persistCurrentState()
        onStateChanged?()
        soundPlayer.play(presetID: preferences.clickSoundID, volumeID: volume.rawValue)
    }

    func setTheme(_ theme: BubbleTheme) {
        preferences.themeID = theme.rawValue
        applyAppearanceState()
        persistCurrentState()
        onStateChanged?()
    }

    func setMood(_ mood: BubbleMood) {
        preferences.moodID = mood.rawValue
        applyAppearanceState()
        persistCurrentState()
        onStateChanged?()
    }

    func setCharacter(_ character: BubbleCharacter) {
        preferences.characterID = character.rawValue
        applyAppearanceState()
        persistCurrentState()
        onStateChanged?()
    }

    func setSmartPositioningEnabled(_ enabled: Bool) {
        preferences.smartPositioningEnabled = enabled
        persistCurrentState()
        onStateChanged?()
    }

    func restoreInitialState() {
        createWindowIfNeeded()
        applySavedOrDefaultPosition()

        if preferences.isVisible {
            showBubble()
        } else {
            hideBubble()
        }

        setPaused(preferences.isPaused)
    }

    func showBubble() {
        createWindowIfNeeded()
        preferences.isVisible = true
        window?.orderFrontRegardless()
        ensureWindowIsVisible()
        persistCurrentState()
        onStateChanged?()
        if !preferences.isPaused {
            startMovement()
        }
    }

    func hideBubble() {
        preferences.isVisible = false
        window?.orderOut(nil)
        stopMovement()
        persistCurrentState()
        onStateChanged?()
    }

    func togglePause() {
        setPaused(!preferences.isPaused)
    }

    func setPaused(_ paused: Bool) {
        preferences.isPaused = paused
        visualState.isPaused = paused
        persistCurrentState()
        onStateChanged?()

        if paused {
            stopMovement()
        } else {
            startMovement()
            react()
        }
    }

    func resetPosition() {
        createWindowIfNeeded()
        guard let visibleFrame = currentVisibleFrame() else {
            return
        }

        let origin = ScreenClamp.defaultOrigin(
            windowSize: Size2D(width: windowSize.width, height: windowSize.height),
            visibleFrame: visibleFrame.rect2D
        )

        setWindowOrigin(origin.nsPoint, persist: true)
        showBubble()
    }

    func react() {
        guard !preferences.isPaused else {
            return
        }

        soundPlayer.play(presetID: preferences.clickSoundID, volumeID: preferences.soundVolumeID)
        visualState.react()
    }

    func persistCurrentState() {
        if let origin = window?.frame.origin {
            preferences.lastPosition = origin.point2D
        }
        preferencesStore.save(preferences)
    }

    private func applyAppearanceState() {
        visualState.theme = BubbleTheme.from(id: preferences.themeID)
        visualState.mood = BubbleMood.from(id: preferences.moodID)
        visualState.character = BubbleCharacter.from(id: preferences.characterID)
    }

    private func createWindowIfNeeded() {
        guard window == nil else {
            return
        }

        let initialFrame = NSRect(origin: .zero, size: windowSize)
        let panel = NSPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.alphaValue = 1
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false

        let bubbleView = BubbleView(visualState: visualState)
        let hostingView = BubbleHostingView(rootView: bubbleView)
        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        hostingView.onSingleClick = { [weak self] in
            self?.react()
        }
        hostingView.onDoubleClick = { [weak self] in
            self?.togglePause()
        }
        hostingView.onDrag = { [weak self] origin in
            self?.stopMovement()
            self?.setWindowOrigin(origin, persist: false)
        }
        hostingView.onDragEnded = { [weak self] in
            self?.ensureWindowIsVisible()
            self?.persistCurrentState()
            if self?.preferences.isVisible == true, self?.preferences.isPaused == false {
                self?.startMovement()
            }
        }
        hostingView.onRightClick = { [weak self] event, view in
            guard let menu = self?.contextMenuProvider?() else {
                return
            }
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }

        panel.contentView = hostingView
        window = panel
    }

    private func applySavedOrDefaultPosition() {
        guard let visibleFrame = currentVisibleFrame() else {
            return
        }

        let origin = preferences.lastPosition ?? ScreenClamp.defaultOrigin(
            windowSize: Size2D(width: windowSize.width, height: windowSize.height),
            visibleFrame: visibleFrame.rect2D
        )

        let clamped = ScreenClamp.clampedOrigin(
            origin,
            windowSize: Size2D(width: windowSize.width, height: windowSize.height),
            visibleFrame: visibleFrame.rect2D
        )

        setWindowOrigin(clamped.nsPoint, persist: false)
    }

    private func startMovement() {
        guard preferences.isVisible, !preferences.isPaused else {
            return
        }

        guard movementTimer == nil else {
            return
        }

        lastMovementTick = Date()
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickMovement()
            }
        }
    }

    private func stopMovement() {
        movementTimer?.invalidate()
        movementTimer = nil
        movementTarget = nil
    }

    private func tickMovement() {
        guard preferences.isVisible, !preferences.isPaused, let window else {
            lastMovementTick = Date()
            return
        }

        guard let visibleFrame = currentVisibleFrame() else {
            return
        }

        let now = Date()
        let delta = min(now.timeIntervalSince(lastMovementTick), 0.12)
        lastMovementTick = now

        let current = window.frame.origin
        let target = movementTarget ?? nextWanderTarget(from: current, visibleFrame: visibleFrame)
        movementTarget = target

        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = max(sqrt(dx * dx + dy * dy), 0.001)
        let step = movementSpeed * delta

        if distance <= step {
            setWindowOrigin(target, persist: false)
            movementTarget = nil
        } else {
            let next = NSPoint(
                x: current.x + dx / distance * step,
                y: current.y + dy / distance * step
            )
            setWindowOrigin(next, persist: false)
        }

        if now.timeIntervalSince(lastPositionSave) > 3 {
            persistCurrentState()
            lastPositionSave = now
        }
    }

    private func nextWanderTarget(from current: NSPoint, visibleFrame: NSRect) -> NSPoint {
        let margin: CGFloat = 22
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - windowSize.width - margin
        let minY = visibleFrame.minY + margin
        let maxY = visibleFrame.maxY - windowSize.height - margin

        guard maxX > minX, maxY > minY else {
            return current
        }

        let range: CGFloat = 260
        let minimumDistance: CGFloat = 120
        let proposed: NSPoint
        if preferences.smartPositioningEnabled, Bool.random() {
            proposed = smartWanderTarget(from: current, visibleFrame: visibleFrame)
        } else {
            proposed = NSPoint(
                x: current.x + CGFloat.random(in: -range...range),
                y: current.y + CGFloat.random(in: -range...range)
            )
        }

        let clamped = NSPoint(
            x: min(max(proposed.x, minX), maxX),
            y: min(max(proposed.y, minY), maxY)
        )

        let dx = clamped.x - current.x
        let dy = clamped.y - current.y
        guard sqrt(dx * dx + dy * dy) >= minimumDistance else {
            let fallbackX = current.x < visibleFrame.midX ? maxX : minX
            let fallbackY = min(max(current.y + CGFloat.random(in: -range...range), minY), maxY)
            return NSPoint(x: fallbackX, y: fallbackY)
        }

        return clamped
    }

    private func smartWanderTarget(from current: NSPoint, visibleFrame: NSRect) -> NSPoint {
        let margin: CGFloat = 28
        let topControlAvoidance: CGFloat = min(170, visibleFrame.height * 0.22)
        let safeMinX = visibleFrame.minX + margin
        let safeMaxX = visibleFrame.maxX - windowSize.width - margin
        let safeMinY = visibleFrame.minY + margin
        let safeMaxY = visibleFrame.maxY - windowSize.height - topControlAvoidance

        guard safeMaxX > safeMinX, safeMaxY > safeMinY else {
            return current
        }

        let sideBandWidth = min(220, max(120, visibleFrame.width * 0.16))
        let sideTargets = [
            NSPoint(
                x: CGFloat.random(in: safeMinX...min(safeMinX + sideBandWidth, safeMaxX)),
                y: CGFloat.random(in: safeMinY...safeMaxY)
            ),
            NSPoint(
                x: CGFloat.random(in: max(safeMaxX - sideBandWidth, safeMinX)...safeMaxX),
                y: CGFloat.random(in: safeMinY...safeMaxY)
            ),
            NSPoint(
                x: CGFloat.random(in: safeMinX...safeMaxX),
                y: CGFloat.random(in: safeMinY...min(safeMinY + 180, safeMaxY))
            )
        ]

        return sideTargets.randomElement() ?? current
    }

    private func setWindowOrigin(_ origin: NSPoint, persist: Bool) {
        guard let window else {
            return
        }

        window.setFrameOrigin(origin)
        if persist {
            persistCurrentState()
        }
    }

    private func ensureWindowIsVisible() {
        guard let window, let visibleFrame = currentVisibleFrame() else {
            return
        }

        let origin = ScreenClamp.clampedOrigin(
            window.frame.origin.point2D,
            windowSize: Size2D(width: windowSize.width, height: windowSize.height),
            visibleFrame: visibleFrame.rect2D
        )

        setWindowOrigin(origin.nsPoint, persist: true)
    }

    private func currentVisibleFrame() -> NSRect? {
        let origin = window?.frame.origin
        let screen = origin.flatMap { point in
            NSScreen.screens.first { $0.visibleFrame.contains(point) }
        } ?? NSScreen.main ?? NSScreen.screens.first

        return screen?.visibleFrame
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.ensureWindowIsVisible()
            }
        }
    }
}

private extension NSPoint {
    var point2D: Point2D {
        Point2D(x: x, y: y)
    }
}

private extension Point2D {
    var nsPoint: NSPoint {
        NSPoint(x: x, y: y)
    }
}

private extension NSRect {
    var rect2D: Rect2D {
        Rect2D(x: minX, y: minY, width: width, height: height)
    }
}
