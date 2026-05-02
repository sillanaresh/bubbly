import AppKit
import SwiftUI

@MainActor
final class AboutWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: AboutView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Habibi Float"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.96, green: 0.99, blue: 1.00),
                                Color(red: 0.46, green: 0.80, blue: 0.96),
                                Color(red: 0.28, green: 0.55, blue: 0.88)
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 72
                        )
                    )
                HStack(spacing: 20) {
                    Capsule()
                        .fill(Color(red: 0.06, green: 0.13, blue: 0.22))
                        .frame(width: 10, height: 16)
                    Capsule()
                        .fill(Color(red: 0.06, green: 0.13, blue: 0.22))
                        .frame(width: 10, height: 16)
                }
                .offset(y: -8)

                AboutSmile()
                    .stroke(
                        Color(red: 0.08, green: 0.17, blue: 0.28).opacity(0.88),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 28, height: 18)
                    .offset(y: 20)
            }
            .frame(width: 104, height: 104)

            VStack(spacing: 6) {
                Text("Habibi Float")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Version 0.1.0")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("A tiny floating companion for your Mac.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("No internet. No tracking. Just a cute bubble.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct AboutSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + 3))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.minY + 3),
            control: CGPoint(x: rect.midX, y: rect.maxY - 1)
        )
        return path
    }
}
