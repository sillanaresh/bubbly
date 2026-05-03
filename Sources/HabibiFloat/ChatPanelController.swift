import AppKit
import SwiftUI

@MainActor
final class ChatPanelController: NSObject, NSWindowDelegate {
    private let viewModel: AIChatViewModel
    private var panel: NSPanel?
    private var onClose: (() -> Void)?

    init(viewModel: AIChatViewModel) {
        self.viewModel = viewModel
    }

    var isOpen: Bool {
        panel?.isVisible == true
    }

    func show(attachedTo bubbleFrame: NSRect, visibleFrame: NSRect?, onClose: @escaping () -> Void) {
        self.onClose = onClose

        if let panel {
            panel.setFrameOrigin(origin(attachedTo: bubbleFrame, panelSize: panel.frame.size, visibleFrame: visibleFrame))
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let size = NSSize(width: 380, height: 460)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Habibi Chat"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 360)
        panel.maxSize = NSSize(width: 560, height: 720)
        panel.titlebarAppearsTransparent = true
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ChatView(viewModel: viewModel) { [weak self] in
            self?.close()
        })
        panel.setFrameOrigin(origin(attachedTo: bubbleFrame, panelSize: size, visibleFrame: visibleFrame))

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
        let closeHandler = onClose
        onClose = nil
        closeHandler?()
    }

    private func origin(attachedTo bubbleFrame: NSRect, panelSize: NSSize, visibleFrame: NSRect?) -> NSPoint {
        let visibleFrame = visibleFrame ?? NSScreen.main?.visibleFrame ?? bubbleFrame
        let gap: CGFloat = 12

        let rightX = bubbleFrame.maxX + gap
        let leftX = bubbleFrame.minX - panelSize.width - gap
        let x = rightX + panelSize.width <= visibleFrame.maxX ? rightX : max(visibleFrame.minX + gap, leftX)

        let desiredY = bubbleFrame.midY - panelSize.height * 0.58
        let y = min(max(desiredY, visibleFrame.minY + gap), visibleFrame.maxY - panelSize.height - gap)

        return NSPoint(x: x, y: y)
    }
}
