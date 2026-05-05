#!/usr/bin/env swift
// Regenerates `SplashMark.png` to match `SwingPalLaunchLogoView` / tab bar Round button (SF Symbol on pine gradient circle).
// Run: `swift Tools/RenderSwingPalSplashLogo.swift`

import AppKit
import Foundation

let length = 1024
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let outputURL = scriptDir
    .appendingPathComponent("../SwingPal/Assets.xcassets/SplashMark.imageset/SplashMark.png")
    .standardizedFileURL

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: length,
    pixelsHigh: length,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Could not create bitmap.\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let H = CGFloat(length)
let W = H
let inset: CGFloat = 12
let circleRect = CGRect(x: inset, y: inset, width: W - 2 * inset, height: H - 2 * inset)

// Matches `ShellTokens.ColorRole` pine500 / pine700 (dark tab bar round gradient).
let pine500 = NSColor(red: 0.184, green: 0.427, blue: 0.322, alpha: 1)
let pine700 = NSColor(red: 0.122, green: 0.302, blue: 0.227, alpha: 1)
let roundStroke = NSColor.white.withAlphaComponent(0.18)

let oval = NSBezierPath(ovalIn: circleRect)

NSGraphicsContext.saveGraphicsState()
oval.addClip()
let gradient = NSGradient(colors: [pine500, pine700], atLocations: [0, 1], colorSpace: .sRGB)!
gradient.draw(
    from: NSPoint(x: circleRect.minX, y: circleRect.maxY),
    to: NSPoint(x: circleRect.maxX, y: circleRect.minY),
    options: []
)
NSGraphicsContext.restoreGraphicsState()

roundStroke.setStroke()
oval.lineWidth = 1
oval.stroke()

let symbolPoint = W * (20.0 / 68.0)
guard
    let rawSymbol = NSImage(
        systemSymbolName: "flag.filled.and.flag.crossed",
        accessibilityDescription: nil
    )
else {
    fputs("SF Symbol not available.\n", stderr)
    exit(1)
}

let config = NSImage.SymbolConfiguration(pointSize: symbolPoint, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
guard let symbol = rawSymbol.withSymbolConfiguration(config) else {
    fputs("Could not apply symbol configuration.\n", stderr)
    exit(1)
}

let symSize = symbol.size
let origin = CGPoint(
    x: floor((W - symSize.width) / 2),
    y: floor((H - symSize.height) / 2)
)
symbol.draw(
    at: origin,
    from: NSRect(origin: .zero, size: symSize),
    operation: .sourceOver,
    fraction: 1.0
)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG.\n", stderr)
    exit(1)
}

do {
    try png.write(to: outputURL)
    print("Wrote \(outputURL.path)")
} catch {
    fputs("Write failed: \(error)\n", stderr)
    exit(1)
}
