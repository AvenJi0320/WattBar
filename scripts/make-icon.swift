import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws the WattBar app icon with plain CoreGraphics so it can be regenerated at any time.
// Usage: make-icon <output.iconset> <preview.png>

let canvas: CGFloat = 1024
let srgb = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient? {
    CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: locations)
}

func radians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180
}

func boltPath(in box: CGRect) -> CGPath {
    let points: [(CGFloat, CGFloat)] = [
        (0.62, 0.00), (0.16, 0.58), (0.47, 0.58), (0.38, 1.00), (0.86, 0.40), (0.55, 0.40),
    ]
    let path = CGMutablePath()
    for (index, point) in points.enumerated() {
        let location = CGPoint(x: box.minX + point.0 * box.width, y: box.minY + point.1 * box.height)
        if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
    }
    path.closeSubpath()
    return path
}

func drawIcon(_ context: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / canvas
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: canvas)
    context.scaleBy(x: 1, y: -1)

    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 28 * scale, color: rgb(0x000000, 0.35))
    context.addPath(squircle)
    context.setFillColor(rgb(0x14152A))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(squircle)
    context.clip()
    if let background = gradient([rgb(0x2E3260), rgb(0x0E0F1D)], [0, 1]) {
        context.drawLinearGradient(background, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    }
    if let highlight = gradient([rgb(0xFFFFFF, 0.14), rgb(0xFFFFFF, 0)], [0, 1]) {
        context.drawRadialGradient(
            highlight, startCenter: CGPoint(x: 512, y: 110), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 110), endRadius: 680, options: []
        )
    }
    context.restoreGState()

    context.addPath(CGPath(roundedRect: body.insetBy(dx: 2, dy: 2), cornerWidth: 184, cornerHeight: 184, transform: nil))
    context.setStrokeColor(rgb(0xFFFFFF, 0.10))
    context.setLineWidth(3)
    context.strokePath()

    let center = CGPoint(x: 512, y: 548)
    let radius: CGFloat = 268
    context.setLineWidth(46)
    context.setLineCap(.round)
    func arc(from start: CGFloat, to end: CGFloat, color: CGColor) {
        context.addArc(center: center, radius: radius, startAngle: radians(start), endAngle: radians(end), clockwise: false)
        context.setStrokeColor(color)
        context.strokePath()
    }
    arc(from: 135, to: 405, color: rgb(0xFFFFFF, 0.09))
    arc(from: 135, to: 188, color: rgb(0x32D2FF))
    arc(from: 202, to: 318, color: rgb(0x6E5BFF))
    arc(from: 332, to: 372, color: rgb(0xFF9F0A))

    let boltBox = CGRect(x: 308, y: 348, width: 400, height: 400)
    let bolt = boltPath(in: boltBox)
    let outline = bolt.copy(strokingWithWidth: 22, lineCap: .round, lineJoin: .round, miterLimit: 10)

    context.saveGState()
    context.setShadow(offset: .zero, blur: 80 * scale, color: rgb(0xFFB800, 0.55))
    context.setFillColor(rgb(0xFFC21A))
    context.addPath(bolt)
    context.fillPath()
    context.addPath(outline)
    context.fillPath()
    context.restoreGState()

    if let fill = gradient([rgb(0xFFF7B8), rgb(0xFFD60A), rgb(0xFF9500)], [0, 0.45, 1]) {
        for shape in [bolt, outline] {
            context.saveGState()
            context.addPath(shape)
            context.clip()
            context.drawLinearGradient(
                fill, start: CGPoint(x: 512, y: boltBox.minY - 12), end: CGPoint(x: 512, y: boltBox.maxY + 12), options: []
            )
            context.restoreGState()
        }
    }
}

func renderPNG(pixels: Int, to url: URL) throws {
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw IconError.context
    }
    context.interpolationQuality = .high
    drawIcon(context, pixels: pixels)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw IconError.encode
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw IconError.encode }
}

enum IconError: Error {
    case context, encode
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: make-icon <output.iconset> <preview.png>\n".utf8))
    exit(2)
}

let iconset = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try renderPNG(pixels: 1024, to: URL(fileURLWithPath: arguments[2]))
