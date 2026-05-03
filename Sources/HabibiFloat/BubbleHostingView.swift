import AppKit
import SwiftUI

final class BubbleHostingView: NSHostingView<BubbleView> {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var onRightClick: ((NSEvent, NSView) -> Void)?
    var onChatBadgeClick: (() -> Void)?
    var onActionBadgeClick: ((BubbleAction) -> Void)?

    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    override var isOpaque: Bool {
        false
    }

    @MainActor @preconcurrency required init(rootView: BubbleView) {
        super.init(rootView: rootView)
        configureTransparency()
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTransparency()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let action = action(at: point) {
            if action == .chat {
                onChatBadgeClick?()
            } else {
                onActionBadgeClick?(action)
            }
            return
        }

        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin

        if event.clickCount >= 2 {
            onDoubleClick?()
        } else {
            onSingleClick?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartMouseLocation, let dragStartWindowOrigin else {
            return
        }

        let current = NSEvent.mouseLocation
        let origin = NSPoint(
            x: dragStartWindowOrigin.x + current.x - dragStartMouseLocation.x,
            y: dragStartWindowOrigin.y + current.y - dragStartMouseLocation.y
        )
        onDrag?(origin)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil
        onDragEnded?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event, self)
    }

    override func layout() {
        super.layout()
        applyCircularMask()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isPointInsideBubble(point) || action(at: point) != nil else {
            return nil
        }

        return super.hitTest(point)
    }

    private func configureTransparency() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        applyCircularMask()
    }

    private func isPointInsideBubble(_ point: NSPoint) -> Bool {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = min(bounds.width, bounds.height) / 2
        return dx * dx + dy * dy <= radius * radius
    }

    private func action(at point: NSPoint) -> BubbleAction? {
        rootView.visualState.featureMode.enabledActions.first { action in
            isPoint(point, inside: action)
        }
    }

    private func isPoint(_ point: NSPoint, inside action: BubbleAction) -> Bool {
        let center = NSPoint(x: bounds.midX + action.offset.width, y: bounds.midY + action.offset.height)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius: CGFloat = 19
        return dx * dx + dy * dy <= radius * radius
    }

    private func applyCircularMask() {
        guard let layer else {
            return
        }

        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        layer.masksToBounds = false
    }
}
