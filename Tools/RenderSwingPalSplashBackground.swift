#!/usr/bin/env swift
// Renders `SplashBackgroundLight.png` and `SplashBackgroundDark.png` to match
// `SwingPalSplashView` background for light/dark appearances.
// Run: `swift Tools/RenderSwingPalSplashBackground.swift`

import AppKit
import CoreImage
import Foundation

private let W = 1242
private let H = 2688

private func blendSourceOver(_ src: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat), _ dst: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
    let outA = src.a + dst.a * (1 - src.a)
    guard outA > 0.0001 else { return (0, 0, 0, 0) }
    let r = (src.r * src.a + dst.r * dst.a * (1 - src.a)) / outA
    let g = (src.g * src.a + dst.g * dst.a * (1 - src.a)) / outA
    let b = (src.b * src.a + dst.b * dst.a * (1 - src.a)) / outA
    return (r, g, b, outA)
}

private func nsColor(_ tuple: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> NSColor {
    NSColor(srgbRed: tuple.r, green: tuple.g, blue: tuple.b, alpha: tuple.a)
}

let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let outDir = scriptDir
    .appendingPathComponent("../SwingPal/Assets.xcassets/SplashBackground.imageset")
    .standardizedFileURL

struct Spec {
    let name: String
    let base: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    let glowTopSrc: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    let glowBotSrc: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    let pineOrbAlpha: CGFloat
    let whiteOrbAlpha: CGFloat
}

let specs: [Spec] = [
    .init(
        name: "SplashBackgroundDark",
        base: (0.05, 0.08, 0.07, 1),
        glowTopSrc: (0.18, 0.30, 0.22, 0.52),
        glowBotSrc: (0.10, 0.15, 0.13, 0.72),
        pineOrbAlpha: 0.16,
        whiteOrbAlpha: 0.03
    ),
    .init(
        name: "SplashBackgroundLight",
        base: (0.95, 0.96, 0.92, 1),
        glowTopSrc: (0.84, 0.92, 0.80, 0.78),
        glowBotSrc: (0.97, 0.95, 0.89, 0.66),
        pineOrbAlpha: 0.12,
        whiteOrbAlpha: 0.22
    )
]

/// SwiftUI `offset` is from screen center; `centerUIKit` is the orb center in top-left coordinates.
func uiKitCenterFromOffset(dx: CGFloat, dy: CGFloat) -> CGPoint {
    CGPoint(x: CGFloat(W) / 2 + dx, y: CGFloat(H) / 2 + dy)
}

/// CIRadialGradient uses Core Image coordinates (origin bottom-left).
func ciCenter(fromUIKit p: CGPoint) -> CGPoint {
    CGPoint(x: p.x, y: CGFloat(H) - p.y)
}

// `addOrb` is defined inside the per-appearance render loop so it can mutate
// that loop's `composite` image safely.

for spec in specs {
    let outputURL = outDir.appendingPathComponent("\(spec.name).png")

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: W,
        pixelsHigh: H,
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
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fputs("No graphics context.\n", stderr)
        exit(1)
    }
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    cg.translateBy(x: 0, y: CGFloat(H))
    cg.scaleBy(x: 1, y: -1)

    let c0 = blendSourceOver(spec.glowTopSrc, spec.base)
    let c1 = spec.base
    let c2 = blendSourceOver(spec.glowBotSrc, spec.base)

    cg.setFillColor(nsColor(spec.base).cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: CGFloat(W), height: CGFloat(H)))

    let colors = [nsColor(c0).cgColor, nsColor(c1).cgColor, nsColor(c2).cgColor] as CFArray
    let locs: [CGFloat] = [0, 0.5, 1]
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) else {
        fputs("CGGradient failed.\n", stderr)
        exit(1)
    }

    cg.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: CGFloat(W), y: CGFloat(H)),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = rep.cgImage else {
        fputs("cgImage failed.\n", stderr)
        exit(1)
    }

    let bounds = CGRect(x: 0, y: 0, width: CGFloat(W), height: CGFloat(H))
    let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: true])
    var composite = CIImage(cgImage: cgImage).cropped(to: bounds)

    let pine = CIColor(red: 0.184, green: 0.427, blue: 0.322, alpha: spec.pineOrbAlpha)
    let whiteOrb = CIColor(red: 1, green: 1, blue: 1, alpha: spec.whiteOrbAlpha)

    func addOrb(centerUIKit: CGPoint, diameter: CGFloat, blurRadius: CGFloat, color: CIColor) {
        let r = diameter / 2
        guard let radial = CIFilter(name: "CIRadialGradient") else { return }
        let c = ciCenter(fromUIKit: centerUIKit)
        radial.setValue(CIVector(x: c.x, y: c.y), forKey: kCIInputCenterKey)
        radial.setValue(0, forKey: "inputRadius0")
        radial.setValue(r, forKey: "inputRadius1")
        radial.setValue(color, forKey: "inputColor0")
        radial.setValue(CIColor.clear, forKey: "inputColor1")
        guard let gradImg = radial.outputImage else { return }

        guard let blurF = CIFilter(name: "CIGaussianBlur") else { return }
        blurF.setValue(gradImg, forKey: kCIInputImageKey)
        blurF.setValue(blurRadius, forKey: kCIInputRadiusKey)
        guard let blurred = blurF.outputImage else { return }
        let croppedOrb = blurred.cropped(to: bounds)

        guard let over = CIFilter(name: "CISourceOverCompositing") else { return }
        over.setValue(croppedOrb, forKey: kCIInputImageKey)
        over.setValue(composite, forKey: kCIInputBackgroundImageKey)
        guard let out = over.outputImage else { return }
        composite = out.cropped(to: bounds)
    }

    addOrb(centerUIKit: uiKitCenterFromOffset(dx: 156, dy: -176), diameter: 280, blurRadius: 42, color: pine)
    addOrb(centerUIKit: uiKitCenterFromOffset(dx: -142, dy: 188), diameter: 240, blurRadius: 36, color: whiteOrb)

    let finalCI = composite.cropped(to: bounds)
    guard let outCG = ciContext.createCGImage(finalCI, from: bounds) else {
        fputs("CI render failed (extent \(composite.extent.integral)).\n", stderr)
        exit(1)
    }

    let outRep = NSBitmapImageRep(cgImage: outCG)
    guard let png = outRep.representation(using: .png, properties: [:]) else {
        fputs("PNG encode failed.\n", stderr)
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
