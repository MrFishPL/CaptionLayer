import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data("Usage: render_symbol.swift <output_path> <size>\n".utf8))
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let size = CGFloat(Double(CommandLine.arguments[2]) ?? 1024)

guard let symbol = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil) else {
    FileHandle.standardError.write(Data("Failed to load SF Symbol.\n".utf8))
    exit(1)
}

let config = NSImage.SymbolConfiguration(pointSize: size * 0.55, weight: .regular)
let configured = symbol.withSymbolConfiguration(config) ?? symbol
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: image.size).fill()

let inset = size * 0.12
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = rect.width * 0.22
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

NSColor(white: 0.92, alpha: 1.0).setFill()
path.fill()

NSColor.black.setFill()
let symbolSize = size * 0.55
let symbolRect = NSRect(
    x: (size - symbolSize) / 2,
    y: (size - symbolSize) / 2,
    width: symbolSize,
    height: symbolSize
)
configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
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
