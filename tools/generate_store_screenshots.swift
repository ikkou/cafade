#!/usr/bin/env swift

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let canvasWidth = 1320
private let canvasHeight = 2868

private struct StoreFrame {
    let sourceName: String
    let outputName: String
    let eyebrow: String
    let headline: String
    let detail: String
    let glow: NSColor
}

private let frames: [StoreFrame] = [
    .init(
        sourceName: "01-today-final.png",
        outputName: "01-current-estimate.png",
        eyebrow: "CURRENT ESTIMATE",
        headline: "See your\ncaffeine fade.",
        detail: "A live estimate shaped by what you drink.",
        glow: NSColor(calibratedRed: 0.97, green: 0.50, blue: 0.14, alpha: 0.27)
    ),
    .init(
        sourceName: "02-log.png",
        outputName: "02-quick-log.png",
        eyebrow: "QUICK LOG",
        headline: "Log a drink\nin seconds.",
        detail: "Suggestions and recent drinks are one tap away.",
        glow: NSColor(calibratedRed: 0.92, green: 0.42, blue: 0.13, alpha: 0.23)
    ),
    .init(
        sourceName: "03-curve.png",
        outputName: "03-fade-curve.png",
        eyebrow: "YOUR DAY",
        headline: "Every drink\nshapes the curve.",
        detail: "See each intake appear, then fade over time.",
        glow: NSColor(calibratedRed: 0.40, green: 0.35, blue: 0.72, alpha: 0.20)
    ),
    .init(
        sourceName: "04-history.png",
        outputName: "04-patterns.png",
        eyebrow: "HISTORY",
        headline: "Find patterns\nworth changing.",
        detail: "Turn your log into context, not judgment.",
        glow: NSColor(calibratedRed: 0.33, green: 0.46, blue: 0.72, alpha: 0.18)
    ),
    .init(
        sourceName: "05-widget.png",
        outputName: "05-widget.png",
        eyebrow: "HOME SCREEN WIDGET",
        headline: "Your estimate,\nright on Home Screen.",
        detail: "Check it and log again without opening Cafade.",
        glow: NSColor(calibratedRed: 0.47, green: 0.39, blue: 0.72, alpha: 0.22)
    ),
    .init(
        sourceName: "06-model.png",
        outputName: "06-model.png",
        eyebrow: "THE MODEL",
        headline: "Know what\nthe estimate means.",
        detail: "A transparent half-life model you can tune.",
        glow: NSColor(calibratedRed: 0.95, green: 0.48, blue: 0.14, alpha: 0.20)
    )
]

private let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
private let repositoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
private let sourceURL = repositoryURL.appendingPathComponent("store/screenshots/source", isDirectory: true)
private let outputURL = repositoryURL.appendingPathComponent("store/screenshots/iphone-6.9", isDirectory: true)

private func topRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(canvasHeight) - y - height, width: width, height: height)
}

private func serifFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    if let font = NSFont(name: "NewYork-Regular", size: size) {
        return font
    }
    if let font = NSFont(name: "Georgia", size: size) {
        return font
    }
    return NSFont.systemFont(ofSize: size, weight: weight)
}

private func sansFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

private func paragraphStyle(lineHeight: CGFloat, alignment: NSTextAlignment = .left) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    return style
}

private func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    lineHeight: CGFloat,
    kern: CGFloat = 0,
    alignment: NSTextAlignment = .left
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle(lineHeight: lineHeight, alignment: alignment),
        .kern: kern
    ]
    NSAttributedString(string: text, attributes: attributes).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

private func fillRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func drawBackground(glow: NSColor) {
    let backgroundRect = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
    let top = NSColor(calibratedRed: 0.985, green: 0.974, blue: 0.955, alpha: 1)
    let bottom = NSColor(calibratedRed: 0.935, green: 0.928, blue: 0.940, alpha: 1)
    NSGradient(starting: bottom, ending: top)?.draw(in: backgroundRect, angle: 90)

    let glowRect = topRect(x: 650, y: 360, width: 790, height: 880)
    let context = NSGraphicsContext.current?.cgContext
    let colors = [glow.cgColor, glow.withAlphaComponent(0).cgColor] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        context?.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: glowRect.midX, y: glowRect.midY),
            startRadius: 0,
            endCenter: CGPoint(x: glowRect.midX, y: glowRect.midY),
            endRadius: glowRect.width / 2,
            options: [.drawsAfterEndLocation]
        )
    }

    let lineColor = NSColor(calibratedWhite: 0.34, alpha: 0.13)
    lineColor.setStroke()
    let arc = NSBezierPath()
    arc.lineWidth = 1.4
    arc.move(to: CGPoint(x: 70, y: CGFloat(canvasHeight) - 505))
    arc.curve(
        to: CGPoint(x: 1225, y: CGFloat(canvasHeight) - 290),
        controlPoint1: CGPoint(x: 430, y: CGFloat(canvasHeight) - 660),
        controlPoint2: CGPoint(x: 930, y: CGFloat(canvasHeight) - 150)
    )
    arc.stroke()
}

private func drawHeader(_ frame: StoreFrame, index: Int) {
    let ink = NSColor(calibratedRed: 0.09, green: 0.085, blue: 0.078, alpha: 1)
    let muted = NSColor(calibratedRed: 0.30, green: 0.285, blue: 0.27, alpha: 1)
    let accent = NSColor(calibratedRed: 0.73, green: 0.25, blue: 0.045, alpha: 1)

    drawText(
        "CAFADE  /  \(String(format: "%02d", index + 1))",
        in: topRect(x: 92, y: 74, width: 520, height: 42),
        font: sansFont(size: 23, weight: .semibold),
        color: accent,
        lineHeight: 30,
        kern: 4.6
    )
    drawText(
        frame.eyebrow,
        in: topRect(x: 92, y: 132, width: 1120, height: 40),
        font: sansFont(size: 21, weight: .semibold),
        color: muted,
        lineHeight: 28,
        kern: 4.2
    )
    drawText(
        frame.headline,
        in: topRect(x: 88, y: 178, width: 1144, height: 220),
        font: serifFont(size: frame.outputName == "05-widget.png" ? 76 : 82),
        color: ink,
        lineHeight: frame.outputName == "05-widget.png" ? 82 : 88,
        kern: -1.2
    )
    drawText(
        frame.detail,
        in: topRect(x: 94, y: 405, width: 1120, height: 56),
        font: sansFont(size: 30, weight: .regular),
        color: muted,
        lineHeight: 38,
        kern: -0.2
    )
}

private func drawPhone(source: NSImage) {
    let screenWidth: CGFloat = 1040
    let screenHeight = screenWidth * CGFloat(canvasHeight) / CGFloat(canvasWidth)
    let screenRect = topRect(x: 140, y: 555, width: screenWidth, height: screenHeight)
    let border: CGFloat = 17
    let frameRect = screenRect.insetBy(dx: -border, dy: -border)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.05, alpha: 0.28)
    shadow.shadowBlurRadius = 38
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    fillRoundedRect(frameRect, radius: 102, color: NSColor(calibratedWhite: 0.055, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()

    let clipPath = NSBezierPath(roundedRect: screenRect, xRadius: 86, yRadius: 86)
    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()
    source.draw(
        in: screenRect,
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 1, alpha: 0.28).setStroke()
    let highlight = NSBezierPath(roundedRect: screenRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 84, yRadius: 84)
    highlight.lineWidth = 2
    highlight.stroke()
}

private func makeBitmap(width: Int, height: Int) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "CafadeStoreScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not allocate bitmap"])
    }
    return bitmap
}

private func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let sourceImage = bitmap.cgImage else {
        throw NSError(domain: "CafadeStoreScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create source image"])
    }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: sourceImage.width,
        height: sourceImage.height,
        bitsPerComponent: 8,
        bytesPerRow: sourceImage.width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "CafadeStoreScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create RGB image context"])
    }
    context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height))
    guard let rgbImage = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw NSError(domain: "CafadeStoreScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination"])
    }
    CGImageDestinationAddImage(destination, rgbImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "CafadeStoreScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
}

private func renderFrame(_ frame: StoreFrame, index: Int) throws -> URL {
    let sourcePath = sourceURL.appendingPathComponent(frame.sourceName)
    guard let source = NSImage(contentsOf: sourcePath) else {
        throw NSError(domain: "CafadeStoreScreenshots", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing source: \(sourcePath.path)"])
    }

    let bitmap = try makeBitmap(width: canvasWidth, height: canvasHeight)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "CafadeStoreScreenshots", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    drawBackground(glow: frame.glow)
    drawHeader(frame, index: index)
    drawPhone(source: source)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    let destination = outputURL.appendingPathComponent(frame.outputName)
    try writePNG(bitmap, to: destination)
    return destination
}

private func renderContactSheet(urls: [URL]) throws {
    let thumbWidth: CGFloat = 360
    let thumbHeight = thumbWidth * CGFloat(canvasHeight) / CGFloat(canvasWidth)
    let gap: CGFloat = 28
    let margin: CGFloat = 42
    let width = Int(margin * 2 + thumbWidth * 3 + gap * 2)
    let height = Int(margin * 2 + thumbHeight * 2 + gap)
    let bitmap = try makeBitmap(width: width, height: height)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    context.imageInterpolation = .high

    for (index, url) in urls.enumerated() {
        guard let image = NSImage(contentsOf: url) else { continue }
        let column = index % 3
        let row = index / 3
        let rect = NSRect(
            x: margin + CGFloat(column) * (thumbWidth + gap),
            y: CGFloat(height) - margin - CGFloat(row + 1) * thumbHeight - CGFloat(row) * gap,
            width: thumbWidth,
            height: thumbHeight
        )
        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
    }
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    try writePNG(bitmap, to: repositoryURL.appendingPathComponent("store/screenshots/contact-sheet.png"))
}

do {
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let urls = try frames.enumerated().map { try renderFrame($0.element, index: $0.offset) }
    try renderContactSheet(urls: urls)
    for url in urls {
        print(url.path)
    }
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
