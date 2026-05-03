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
    private let chatPanelController: ChatPanelController
    private let windowSize = NSSize(width: 144, height: 144)
    private let movementSpeed: CGFloat = 48

    private var window: NSPanel?
    private var preferences: BubblePreferences
    private var movementTimer: Timer?
    private var wanderMotion: WanderMotion?
    private var nextWanderAt = Date.distantPast
    private var lastPositionSave = Date.distantPast
    private var isPinnedForChat = false
    private var pauseStateBeforeChat: Bool?

    init(preferences: UserDefaultsPreferencesStore) {
        self.preferencesStore = preferences
        self.preferences = preferences.load()
        let chatSettings = AIChatSettingsStore()
        let keyStore = KeychainOpenRouterKeyStore()
        self.chatPanelController = ChatPanelController(
            viewModel: AIChatViewModel(
                settings: chatSettings,
                keyStore: keyStore,
                service: AIChatService(settings: chatSettings, keyStore: keyStore)
            )
        )
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
        closeChat()
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
        hostingView.onChatBadgeClick = { [weak self] in
            self?.toggleChat()
        }
        hostingView.onDrag = { [weak self] origin in
            self?.stopMovement()
            self?.setWindowOrigin(origin, persist: false)
        }
        hostingView.onDragEnded = { [weak self] in
            self?.ensureWindowIsVisible()
            self?.persistCurrentState()
            if self?.preferences.isVisible == true, self?.preferences.isPaused == false, self?.isPinnedForChat == false {
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

    private func toggleChat() {
        if chatPanelController.isOpen {
            closeChat()
        } else {
            openChat()
        }
    }

    private func openChat() {
        createWindowIfNeeded()
        guard let window else {
            return
        }

        if pauseStateBeforeChat == nil {
            pauseStateBeforeChat = preferences.isPaused
        }
        isPinnedForChat = true
        visualState.isChatOpen = true
        stopMovement()

        chatPanelController.show(attachedTo: window.frame, visibleFrame: currentVisibleFrame()) { [weak self] in
            self?.handleChatClosed()
        }
    }

    private func closeChat() {
        if chatPanelController.isOpen {
            chatPanelController.close()
        } else if visualState.isChatOpen || isPinnedForChat {
            handleChatClosed()
        }
    }

    private func handleChatClosed() {
        isPinnedForChat = false
        visualState.isChatOpen = false

        if let pauseStateBeforeChat {
            self.pauseStateBeforeChat = nil
            setPaused(pauseStateBeforeChat)
        }
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
        guard preferences.isVisible, !preferences.isPaused, !isPinnedForChat else {
            return
        }

        guard movementTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tickMovement()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        movementTimer = timer
    }

    private func stopMovement() {
        movementTimer?.invalidate()
        movementTimer = nil
        wanderMotion = nil
    }

    private func tickMovement() {
        guard preferences.isVisible, !preferences.isPaused, !isPinnedForChat, let window else {
            return
        }

        guard let visibleFrame = currentVisibleFrame() else {
            return
        }

        let now = Date()
        let current = window.frame.origin

        if wanderMotion == nil {
            guard now >= nextWanderAt else {
                return
            }

            wanderMotion = makeWanderMotion(from: current, visibleFrame: visibleFrame, startedAt: now)
        }

        guard let motion = wanderMotion else {
            return
        }

        let rawProgress = min(max(now.timeIntervalSince(motion.startedAt) / motion.duration, 0), 1)
        let easedProgress = smoothstep(rawProgress)
        setWindowOrigin(motion.point(at: easedProgress), persist: false)

        if rawProgress >= 1 {
            wanderMotion = nil
            nextWanderAt = now.addingTimeInterval(Double.random(in: 7.0...12.0))
        }

        if now.timeIntervalSince(lastPositionSave) > 3 {
            persistCurrentState()
            lastPositionSave = now
        }
    }

    private func makeWanderMotion(from current: NSPoint, visibleFrame: NSRect, startedAt: Date) -> WanderMotion {
        let bounds = wanderBounds(in: visibleFrame)
        let target = nextWanderTarget(from: current, bounds: bounds)
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = max(sqrt(dx * dx + dy * dy), 1)
        let duration = min(max(TimeInterval(distance / movementSpeed), 3.2), 7.2)

        let perpendicular = NSPoint(x: -dy / distance, y: dx / distance)
        let bend = CGFloat.random(in: -0.42...0.42) * min(max(distance * 0.45, 60), 180)
        let control1 = clampedPoint(
            NSPoint(
                x: current.x + dx * 0.34 + perpendicular.x * bend,
                y: current.y + dy * 0.34 + perpendicular.y * bend
            ),
            bounds: bounds
        )
        let control2 = clampedPoint(
            NSPoint(
                x: current.x + dx * 0.72 - perpendicular.x * bend * 0.7,
                y: current.y + dy * 0.72 - perpendicular.y * bend * 0.7
            ),
            bounds: bounds
        )

        return WanderMotion(
            start: current,
            control1: control1,
            control2: control2,
            end: target,
            startedAt: startedAt,
            duration: duration
        )
    }

    private func nextWanderTarget(from current: NSPoint, bounds: NSRect) -> NSPoint {
        let minX = bounds.minX
        let maxX = bounds.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY

        guard maxX > minX, maxY > minY else {
            return current
        }

        let maximumDistance = min(max(bounds.width, bounds.height) * 0.42, 420)
        let minimumDistance = min(max(min(bounds.width, bounds.height) * 0.20, 120), 220)

        for _ in 0..<14 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: minimumDistance...max(minimumDistance + 1, maximumDistance))
            let candidate = clampedPoint(
                NSPoint(
                    x: current.x + cos(angle) * distance,
                    y: current.y + sin(angle) * distance
                ),
                bounds: bounds
            )
            let dx = candidate.x - current.x
            let dy = candidate.y - current.y

            if abs(dx) >= 64, abs(dy) >= 48, sqrt(dx * dx + dy * dy) >= minimumDistance * 0.75 {
                return candidate
            }
        }

        let targetXRange = current.x < bounds.midX ? bounds.midX...maxX : minX...bounds.midX
        let targetYRange = current.y < bounds.midY ? bounds.midY...maxY : minY...bounds.midY
        return NSPoint(
            x: CGFloat.random(in: targetXRange),
            y: CGFloat.random(in: targetYRange)
        )
    }

    private func wanderBounds(in visibleFrame: NSRect) -> NSRect {
        let margin: CGFloat = 28
        let topAvoidance = preferences.smartPositioningEnabled ? min(150, visibleFrame.height * 0.18) : margin
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - windowSize.width - margin
        let minY = visibleFrame.minY + margin
        let maxY = visibleFrame.maxY - windowSize.height - topAvoidance

        guard maxX > minX, maxY > minY else {
            return visibleFrame
        }

        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func clampedPoint(_ point: NSPoint, bounds: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func smoothstep(_ progress: Double) -> Double {
        progress * progress * (3 - 2 * progress)
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

private struct WanderMotion {
    let start: NSPoint
    let control1: NSPoint
    let control2: NSPoint
    let end: NSPoint
    let startedAt: Date
    let duration: TimeInterval

    func point(at progress: Double) -> NSPoint {
        let t = CGFloat(progress)
        let inverse = 1 - t
        let x = inverse * inverse * inverse * start.x +
            3 * inverse * inverse * t * control1.x +
            3 * inverse * t * t * control2.x +
            t * t * t * end.x
        let y = inverse * inverse * inverse * start.y +
            3 * inverse * inverse * t * control1.y +
            3 * inverse * t * t * control2.y +
            t * t * t * end.y

        return NSPoint(x: x, y: y)
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
