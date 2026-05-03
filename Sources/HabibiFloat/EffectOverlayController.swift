import AppKit
import SwiftUI

@MainActor
final class EffectOverlayController {
    private var panels: [UUID: NSPanel] = [:]
    private var closeTasks: [UUID: Task<Void, Never>] = [:]
    private var activeIDs: [UUID] = []

    func show(action: BubbleAction, from bubbleFrame: NSRect, visibleFrame: NSRect?) {
        if activeIDs.count >= 6, let oldestID = activeIDs.first {
            close(id: oldestID)
        }

        let id = UUID()
        let frame = desktopFrame(fallback: visibleFrame ?? bubbleFrame.insetBy(dx: -280, dy: -220))
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
        panel.contentView = NSHostingView(rootView: EffectOverlayView(action: action, origin: origin, seed: Double.random(in: 0...10_000)))
        panel.orderFrontRegardless()
        panels[id] = panel
        activeIDs.append(id)

        closeTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                self?.close(id: id)
            }
        }
    }

    private func close(id: UUID) {
        closeTasks[id]?.cancel()
        closeTasks[id] = nil
        panels[id]?.close()
        panels[id] = nil
        activeIDs.removeAll { $0 == id }
    }

    private func desktopFrame(fallback: NSRect) -> NSRect {
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard var frame = visibleFrames.first else {
            return fallback
        }

        for visibleFrame in visibleFrames.dropFirst() {
            frame = frame.union(visibleFrame)
        }

        return frame
    }
}
