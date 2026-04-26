import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconSpec {
    let type: String
    let pixels: CGFloat
}

let specs = [
    IconSpec(type: "icp4", pixels: 16),
    IconSpec(type: "icp5", pixels: 32),
    IconSpec(type: "icp6", pixels: 64),
    IconSpec(type: "ic07", pixels: 128),
    IconSpec(type: "ic08", pixels: 256),
    IconSpec(type: "ic09", pixels: 512),
    IconSpec(type: "ic10", pixels: 1024)
]

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift /path/to/AppIcon.icns\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

var chunks: [(type: String, data: Data)] = []
for spec in specs {
    let image = drawIcon(size: CGSize(width: spec.pixels, height: spec.pixels))
    chunks.append((type: spec.type, data: try pngData(image)))
}

try writeICNS(chunks, to: outputURL)

private func drawIcon(size: CGSize) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }

    let bounds = CGRect(origin: .zero, size: size)
    NSColor.clear.setFill()
    bounds.fill()

    let scale = size.width / 1024
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }

    let background = NSBezierPath(
        roundedRect: rect(96, 96, 832, 832),
        xRadius: 216 * scale,
        yRadius: 216 * scale
    )
    let backgroundGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.06, green: 0.13, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.11, alpha: 1)
        ]
    )
    backgroundGradient?.draw(in: background, angle: -45)

    let panel = NSBezierPath(
        roundedRect: rect(184, 192, 656, 640),
        xRadius: 96 * scale,
        yRadius: 96 * scale
    )
    NSColor.white.withAlphaComponent(0.06).setFill()
    panel.fill()

    let line = NSBezierPath()
    line.move(to: point(240, 664))
    line.line(to: point(360, 540))
    line.line(to: point(480, 592))
    line.line(to: point(620, 384))
    line.line(to: point(784, 304))
    line.lineWidth = max(1.5, 72 * scale)
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    NSColor(calibratedRed: 0.23, green: 0.74, blue: 0.98, alpha: 1).setStroke()
    line.stroke()

    let dots: [(CGPoint, NSColor)] = [
        (point(240, 664), NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 1)),
        (point(360, 540), NSColor(calibratedRed: 0.22, green: 0.74, blue: 0.98, alpha: 1)),
        (point(480, 592), NSColor(calibratedRed: 0.22, green: 0.74, blue: 0.98, alpha: 1)),
        (point(620, 384), NSColor(calibratedRed: 0.38, green: 0.65, blue: 0.98, alpha: 1)),
        (point(784, 304), NSColor(calibratedRed: 0.58, green: 0.77, blue: 0.99, alpha: 1))
    ]

    for (center, color) in dots {
        let radius = max(1.5, 38 * scale)
        let dot = NSBezierPath(
            ovalIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        color.setFill()
        dot.fill()
    }

    return image
}

private func pngData(_ image: NSImage) throws -> Data {
    guard
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
        let mutableData = CFDataCreateMutable(nil, 0),
        let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw CocoaError(.fileWriteUnknown)
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return mutableData as Data
}

private func writeICNS(_ chunks: [(type: String, data: Data)], to url: URL) throws {
    var body = Data()
    for chunk in chunks {
        body.appendFourCharacterCode(chunk.type)
        body.appendBigEndianUInt32(UInt32(chunk.data.count + 8))
        body.append(chunk.data)
    }

    var output = Data()
    output.appendFourCharacterCode("icns")
    output.appendBigEndianUInt32(UInt32(body.count + 8))
    output.append(body)
    try output.write(to: url)
}

private extension Data {
    mutating func appendFourCharacterCode(_ value: String) {
        precondition(value.utf8.count == 4)
        append(contentsOf: value.utf8)
    }

    mutating func appendBigEndianUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { buffer in
            append(contentsOf: buffer)
        }
    }
}
