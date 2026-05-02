import AppKit
import HabibiFloatCore
import QuartzCore
import SwiftUI

@MainActor
final class FloatingBubbleController {
    var contextMenuProvider: (() -> NSMenu?)?
    var onStateChanged: (() -> Void)?

    private let preferencesStore: UserDefaultsPreferencesStore
    private let visualState = BubbleVisualState()
    private let soundPlayer = BubbleSoundPlayer()
    private let windowSize = NSSize(width: 144, height: 144)
    private let movementSpeed: CGFloat = 16

    private var window: NSPanel?
    private var preferences: BubblePreferences
    private var movementWorkItem: DispatchWorkItem?
    private var isMovementRunning = false
    private var lastPositionSave = Date.distantPast

    init(preferences: UserDefaultsPreferencesStore) {
        self.preferencesStore = preferences
        self.preferences = preferences.load()
        self.visualState.isPaused = self.preferences.isPaused
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

        guard !isMovementRunning else {
            return
        }

        isMovementRunning = true
        scheduleNextWander(after: 0.35)
    }

    private func stopMovement() {
        isMovementRunning = false
        movementWorkItem?.cancel()
        movementWorkItem = nil
    }

    private func scheduleNextWander(after delay: TimeInterval) {
        movementWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.animateToNextWanderTarget()
            }
        }
        movementWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func animateToNextWanderTarget() {
        movementWorkItem = nil

        guard isMovementRunning, preferences.isVisible, !preferences.isPaused, let window else {
            return
        }

        guard let visibleFrame = currentVisibleFrame() else {
            return
        }

        let current = window.frame.origin
        let target = nextWanderTarget(from: current, visibleFrame: visibleFrame)
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 4 else {
            scheduleNextWander(after: 1.0)
            return
        }

        let duration = min(max(TimeInterval(distance / movementSpeed), 4.0), 12.0)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(target)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.isMovementRunning, self.preferences.isVisible, !self.preferences.isPaused else {
                    return
                }

                self.persistCurrentState()
                self.lastPositionSave = Date()
                self.scheduleNextWander(after: Double.random(in: 0.5...1.2))
            }
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

        let range: CGFloat = 180
        let proposed = NSPoint(
            x: current.x + CGFloat.random(in: -range...range),
            y: current.y + CGFloat.random(in: -range...range)
        )

        return NSPoint(
            x: min(max(proposed.x, minX), maxX),
            y: min(max(proposed.y, minY), maxY)
        )
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
