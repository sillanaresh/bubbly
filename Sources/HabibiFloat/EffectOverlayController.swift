import AppKit
import SwiftUI

@MainActor
final class EffectOverlayController {
    private var panel: NSPanel?
    private var closeTask: Task<Void, Never>?

    func show(action: BubbleAction, from bubbleFrame: NSRect, visibleFrame: NSRect?) {
        closeTask?.cancel()
        panel?.close()

        let frame = visibleFrame ?? NSScreen.main?.visibleFrame ?? bubbleFrame.insetBy(dx: -280, dy: -220)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false

        let origin = CGPoint(x: bubbleFrame.midX - frame.minX, y: frame.maxY - bubbleFrame.midY)
        panel.contentView = NSHostingView(rootView: EffectOverlayView(action: action, origin: origin))
        panel.orderFrontRegardless()
        self.panel = panel

        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.1))
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                self?.panel?.close()
                self?.panel = nil
                self?.closeTask = nil
            }
        }
    }
}

