import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data("Usage: render_dmg_background.swift <output_path> <app_name>\n".utf8))
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let appName = CommandLine.arguments[2]
let size = NSSize(width: 720, height: 460)

let image = NSImage(size: size)
image.lockFocus()

NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()

let arrowColor = NSColor(white: 0.8, alpha: 1.0)
let startX: CGFloat = 300
let endX: CGFloat = 430
let midY: CGFloat = 260

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: startX, y: midY))
arrowPath.line(to: NSPoint(x: endX, y: midY))
arrowPath.lineWidth = 2
arrowColor.setStroke()
arrowPath.stroke()

let headPath = NSBezierPath()
headPath.move(to: NSPoint(x: endX - 8, y: midY + 6))
headPath.line(to: NSPoint(x: endX, y: midY))
headPath.line(to: NSPoint(x: endX - 8, y: midY - 6))
headPath.lineWidth = 2
arrowColor.setStroke()
headPath.stroke()

let label = "Drag \(appName) to Applications"
let font = NSFont.systemFont(ofSize: 18, weight: .regular)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(white: 0.6, alpha: 1.0),
]

let attributed = NSAttributedString(string: label, attributes: attributes)
let textSize = attributed.size()
let textPoint = NSPoint(x: (size.width - textSize.width) / 2, y: 360)
attributed.draw(at: textPoint)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render PNG.\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
} catch {
    FileHandle.standardError.write(Data("Failed to write PNG: \(error)\n".utf8))
    exit(1)
}
