#!/usr/bin/env swift
import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
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

func drawIcon(pixels: Int) throws -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    rect.fill()

    let radius = CGFloat(pixels) * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(pixels) * 0.06, dy: CGFloat(pixels) * 0.06), xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.24, alpha: 1).setFill()
    background.fill()

    let noteRect = rect.insetBy(dx: CGFloat(pixels) * 0.21, dy: CGFloat(pixels) * 0.18)
    let note = NSBezierPath(roundedRect: noteRect, xRadius: CGFloat(pixels) * 0.055, yRadius: CGFloat(pixels) * 0.055)
    NSColor(calibratedRed: 1.0, green: 0.91, blue: 0.55, alpha: 1).setFill()
    note.fill()

    NSColor(calibratedRed: 0.26, green: 0.24, blue: 0.20, alpha: 0.42).setStroke()
    for index in 0..<4 {
        let y = noteRect.maxY - CGFloat(index + 1) * noteRect.height / 5.5
        let line = NSBezierPath()
        line.move(to: NSPoint(x: noteRect.minX + noteRect.width * 0.16, y: y))
        line.line(to: NSPoint(x: noteRect.maxX - noteRect.width * 0.16, y: y))
        line.lineWidth = max(1, CGFloat(pixels) * 0.013)
        line.stroke()
    }

    let pocketRect = NSRect(
        x: rect.midX - CGFloat(pixels) * 0.25,
        y: rect.minY + CGFloat(pixels) * 0.16,
        width: CGFloat(pixels) * 0.50,
        height: CGFloat(pixels) * 0.24
    )
    let pocket = NSBezierPath(roundedRect: pocketRect, xRadius: CGFloat(pixels) * 0.06, yRadius: CGFloat(pixels) * 0.06)
    NSColor(calibratedRed: 0.26, green: 0.57, blue: 1.0, alpha: 1).setFill()
    pocket.fill()

    let p = "P" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: CGFloat(pixels) * 0.20, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let pSize = p.size(withAttributes: attributes)
    p.draw(at: NSPoint(x: rect.midX - pSize.width / 2, y: pocketRect.midY - pSize.height / 2), withAttributes: attributes)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PromptPocketIcon", code: 1)
    }
    return data
}

for variant in variants {
    let data = try drawIcon(pixels: variant.pixels)
    try data.write(to: outputURL.appendingPathComponent(variant.name))
}
