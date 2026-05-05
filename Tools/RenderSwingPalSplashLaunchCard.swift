#!/usr/bin/env swift
// Renders `SplashLaunchCard.png`: frosted 164pt squircle + shadow + inner round mark (matches `SwingPalSplashView`).
// Launch storyboards cannot use layer runtime attributes, so the plate is pre-rendered.
// Run: `swift Tools/RenderSwingPalSplashLaunchCard.swift`

import AppKit
import Foundation

private let s: CGFloat = 3
private let cardSide: CGFloat = 164
private let logoDiameter: CGFloat = 124
private let cornerRadius: CGFloat = 38
private let canvasSide: CGFloat = 220

private let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
private let outputURL = scriptDir
    .appendingPathComponent("../SwingPal/Assets.xcassets/SplashLaunchCard.imageset/SplashLaunchCard.png")
    .standardizedFileURL

private func drawRoundMark(into smallRep: NSBitmapImageRep, circleSide: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: smallRep)

    let H = circleSide
    let W = H
    let inset = circleSide * (12.0 / 1024.0)
    let circleRect = CGRect(x: inset, y: inset, width: W - 2 * inset, height: H - 2 * inset)

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

    let symbolPoint = circleSide * (20.0 / 68.0)
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
}

func main() {
    let px = Int(canvasSide * s)
    let W = CGFloat(px)
    let cardPx = cardSide * s
    let logoPx = logoDiameter * s

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
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

    guard let logoRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(logoPx),
        pixelsHigh: Int(logoPx),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("Logo bitmap failed.\n", stderr)
        exit(1)
    }

    drawRoundMark(into: logoRep, circleSide: logoPx)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let cg = NSGraphicsContext.current?.cgContext else {
        fputs("No CGContext.\n", stderr)
        exit(1)
    }

    cg.translateBy(x: 0, y: W)
    cg.scaleBy(x: 1, y: -1)
    cg.clear(CGRect(x: 0, y: 0, width: W, height: W))

    let origin = CGPoint(x: floor((W - cardPx) / 2), y: floor((W - cardPx) / 2))
    let cardRect = CGRect(origin: origin, size: CGSize(width: cardPx, height: cardPx))
    let radius = cornerRadius * s

    cg.setShadow(offset: CGSize(width: 0, height: 10), blur: 18, color: NSColor.black.withAlphaComponent(0.28).cgColor)

    let platePath = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)
    NSColor.white.withAlphaComponent(0.08).setFill()
    platePath.fill()

    cg.setShadow(offset: .zero, blur: 0, color: nil)

    NSColor.white.withAlphaComponent(0.18).setStroke()
    platePath.lineWidth = 1 * s
    platePath.stroke()

    let margin = (cardSide - logoDiameter) / 2 * s
    let logoOrigin = CGPoint(x: origin.x + margin, y: origin.y + margin)
    let logoRect = CGRect(origin: logoOrigin, size: CGSize(width: logoPx, height: logoPx))

    guard let cgLogo = logoRep.cgImage else {
        fputs("cgImage logo failed.\n", stderr)
        exit(1)
    }
    cg.interpolationQuality = .high
    cg.draw(cgLogo, in: logoRect)

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
}

main()
