import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "app/Cafade/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else {
    fatalError("Could not create icon context")
}

let paper = CGColor(red: 0.972, green: 0.962, blue: 0.938, alpha: 1)
let warmPaper = CGColor(red: 0.995, green: 0.988, blue: 0.972, alpha: 1)
let saffron = CGColor(red: 0.91, green: 0.43, blue: 0.12, alpha: 1)
let coral = CGColor(red: 0.83, green: 0.26, blue: 0.12, alpha: 1)
let lavender = CGColor(red: 0.46, green: 0.39, blue: 0.67, alpha: 1)
let ink = CGColor(red: 0.095, green: 0.091, blue: 0.085, alpha: 1)

context.drawLinearGradient(
    CGGradient(colorsSpace: colorSpace, colors: [warmPaper, paper] as CFArray, locations: [0, 1])!,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: size, y: size),
    options: []
)

func drawGlow(center: CGPoint, radius: CGFloat, color: CGColor) {
    let colors = [color.copy(alpha: 0.24)!, color.copy(alpha: 0)!] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: []
    )
}

drawGlow(center: CGPoint(x: 820, y: 150), radius: 300, color: saffron)
drawGlow(center: CGPoint(x: 160, y: 860), radius: 300, color: lavender)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: 8), blur: 20, color: CGColor(gray: 0, alpha: 0.16))
context.setLineWidth(9)

var curve = CGMutablePath()
curve.move(to: CGPoint(x: 112, y: 750))
curve.addCurve(
    to: CGPoint(x: 910, y: 290),
    control1: CGPoint(x: 360, y: 740),
    control2: CGPoint(x: 690, y: 350)
)
context.addPath(curve)
context.replacePathWithStrokedPath()
context.clip()
context.drawLinearGradient(
    CGGradient(colorsSpace: colorSpace, colors: [saffron, coral] as CFArray, locations: [0, 1])!,
    start: CGPoint(x: 80, y: 760),
    end: CGPoint(x: 930, y: 280),
    options: []
)
context.restoreGState()

context.setFillColor(saffron)
context.fillEllipse(in: CGRect(x: 82, y: 720, width: 60, height: 60))
context.setFillColor(warmPaper)
context.fillEllipse(in: CGRect(x: 101, y: 739, width: 22, height: 22))

context.setStrokeColor(ink.copy(alpha: 0.12)!)
context.setLineWidth(2)
for x in stride(from: 150, through: 874, by: 181) {
    context.move(to: CGPoint(x: x, y: 120))
    context.addLine(to: CGPoint(x: x, y: 136))
}
context.strokePath()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      ) else {
    fatalError("Could not create icon image")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write icon image")
}
