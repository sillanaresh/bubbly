#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let fileManager = FileManager.default
let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("HabibiFloatIcon-\(UUID().uuidString)")
let iconsetURL = tempRoot.appendingPathComponent("AppIcon.iconset")

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for icon in iconSizes {
    let image = drawIcon(size: icon.pixels)
    let url = iconsetURL.appendingPathComponent(icon.name)
    try pngData(from: image)?.write(to: url)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "HabibiFloatIcon", code: Int(process.terminationStatus))
}

try? fileManager.removeItem(at: tempRoot)

func drawIcon(size: Int) -> NSImage {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let image = NSImage(size: rect.size)
    image.lockFocus()

    NSColor.clear.setFill()
    rect.fill()

    let scale = CGFloat(size) / 1024
    let bubbleRect = NSRect(x: 88 * scale, y: 88 * scale, width: 848 * scale, height: 848 * scale)
    let bubblePath = NSBezierPath(ovalIn: bubbleRect)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 0.99, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.44, green: 0.79, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.27, green: 0.54, blue: 0.88, alpha: 1)
    ])
    gradient?.draw(in: bubblePath, angle: -45)

    NSColor.white.withAlphaComponent(0.58).setStroke()
    bubblePath.lineWidth = max(3, 26 * scale)
    bubblePath.stroke()

    NSColor.white.withAlphaComponent(0.36).setFill()
    NSBezierPath(ovalIn: NSRect(x: 230 * scale, y: 640 * scale, width: 250 * scale, height: 170 * scale)).fill()

    NSColor(calibratedRed: 0.06, green: 0.13, blue: 0.22, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 360 * scale, y: 458 * scale, width: 74 * scale, height: 134 * scale), xRadius: 37 * scale, yRadius: 37 * scale).fill()
    NSBezierPath(roundedRect: NSRect(x: 590 * scale, y: 458 * scale, width: 74 * scale, height: 134 * scale), xRadius: 37 * scale, yRadius: 37 * scale).fill()

    NSColor(calibratedRed: 1.0, green: 0.46, blue: 0.67, alpha: 0.42).setFill()
    NSBezierPath(ovalIn: NSRect(x: 292 * scale, y: 366 * scale, width: 92 * scale, height: 62 * scale)).fill()
    NSBezierPath(ovalIn: NSRect(x: 640 * scale, y: 366 * scale, width: 92 * scale, height: 62 * scale)).fill()

    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 425 * scale, y: 360 * scale))
    smile.curve(
        to: NSPoint(x: 599 * scale, y: 360 * scale),
        controlPoint1: NSPoint(x: 470 * scale, y: 300 * scale),
        controlPoint2: NSPoint(x: 554 * scale, y: 300 * scale)
    )
    NSColor(calibratedRed: 0.06, green: 0.13, blue: 0.22, alpha: 0.88).setStroke()
    smile.lineWidth = max(3, 30 * scale)
    smile.lineCapStyle = .round
    smile.stroke()

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
    }

    return bitmap.representation(using: .png, properties: [:])
}
