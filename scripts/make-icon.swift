#!/usr/bin/env swift

import AppKit
import Foundation

// Draws the SpaceSweep app icon into an .iconset directory.
// Usage: swift scripts/make-icon.swift <iconset-directory>

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make-icon.swift <iconset-directory>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

private func point(_ x: CGFloat, _ y: CGFloat, _ size: CGFloat) -> NSPoint {
    NSPoint(x: x * size, y: y * size)
}

private func sparklePath(center: NSPoint, radius: CGFloat, waist: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + radius))
    path.curve(
        to: NSPoint(x: center.x + radius, y: center.y),
        controlPoint1: NSPoint(x: center.x + waist, y: center.y + waist),
        controlPoint2: NSPoint(x: center.x + waist, y: center.y + waist)
    )
    path.curve(
        to: NSPoint(x: center.x, y: center.y - radius),
        controlPoint1: NSPoint(x: center.x + waist, y: center.y - waist),
        controlPoint2: NSPoint(x: center.x + waist, y: center.y - waist)
    )
    path.curve(
        to: NSPoint(x: center.x - radius, y: center.y),
        controlPoint1: NSPoint(x: center.x - waist, y: center.y - waist),
        controlPoint2: NSPoint(x: center.x - waist, y: center.y - waist)
    )
    path.curve(
        to: NSPoint(x: center.x, y: center.y + radius),
        controlPoint1: NSPoint(x: center.x - waist, y: center.y + waist),
        controlPoint2: NSPoint(x: center.x - waist, y: center.y + waist)
    )
    path.close()
    return path
}

private func drawIcon(size: CGFloat, into rep: NSBitmapImageRep) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = size * 0.075
    let backgroundRect = canvas.insetBy(dx: inset, dy: inset)
    let corner = backgroundRect.width * 0.225
    let background = NSBezierPath(roundedRect: backgroundRect, xRadius: corner, yRadius: corner)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.94, blue: 0.73, alpha: 1),
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.18, green: 0.45, blue: 0.96, alpha: 1)
    ])!
    gradient.draw(in: background, angle: -55)

    // Soft highlight at the top-left.
    NSGraphicsContext.saveGraphicsState()
    background.addClip()
    let highlight = NSBezierPath(ovalIn: NSRect(
        x: backgroundRect.minX - backgroundRect.width * 0.18,
        y: backgroundRect.midY,
        width: backgroundRect.width * 0.9,
        height: backgroundRect.height * 0.9
    ))
    NSColor.white.withAlphaComponent(0.13).setFill()
    highlight.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Sweeping ring with an opening at the top-right.
    let ringCenter = point(0.5, 0.5, size)
    let ringRadius = size * 0.275
    let ring = NSBezierPath()
    ring.appendArc(withCenter: ringCenter, radius: ringRadius, startAngle: 28, endAngle: 318, clockwise: false)
    ring.lineWidth = size * 0.056
    ring.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.92).setStroke()
    ring.stroke()

    // Main sparkle.
    let mainSparkle = sparklePath(
        center: point(0.485, 0.475, size),
        radius: size * 0.155,
        waist: size * 0.026
    )
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.shadowBlurRadius = size * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    shadow.set()
    NSColor.white.setFill()
    mainSparkle.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Small accent sparkle near the ring opening.
    let smallSparkle = sparklePath(
        center: point(0.725, 0.735, size),
        radius: size * 0.048,
        waist: size * 0.010
    )
    NSColor.white.withAlphaComponent(0.96).setFill()
    smallSparkle.fill()

    let dot = NSBezierPath(ovalIn: NSRect(
        x: size * 0.27,
        y: size * 0.735,
        width: size * 0.036,
        height: size * 0.036
    ))
    NSColor.white.withAlphaComponent(0.82).setFill()
    dot.fill()
}

let variants: [(String, Int)] = [
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

for (name, pixels) in variants {
    guard let rep = NSBitmapImageRep(
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
    ) else {
        fputs("could not create bitmap for \(name)\n", stderr)
        exit(1)
    }

    drawIcon(size: CGFloat(pixels), into: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("could not encode \(name)\n", stderr)
        exit(1)
    }
    try data.write(to: outputDirectory.appendingPathComponent(name))
}

print("Wrote icon set to \(outputDirectory.path)")
