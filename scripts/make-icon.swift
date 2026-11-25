// Draws the app icon. Usage: swift scripts/make-icon.swift out.icns
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func draw(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let unit = CGFloat(pixels) / 1024
    NSColor(srgbRed: 0.05, green: 0.055, blue: 0.063, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit), xRadius: 186 * unit, yRadius: 186 * unit).fill()
    // Speech bars settling into a straight line: rough voice in, clean text out.
    let heights: [CGFloat] = [180, 400, 260, 120, 64]
    for (index, height) in heights.enumerated() {
        (index == heights.count - 1 ? NSColor.white : NSColor(srgbRed: 0.784, green: 0.941, blue: 0.294, alpha: 1)).setFill()
        let rect = NSRect(x: (236 + CGFloat(index) * 122) * unit, y: (512 - height / 2) * unit, width: 64 * unit, height: height * unit)
        NSBezierPath(roundedRect: rect, xRadius: 32 * unit, yRadius: 32 * unit).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try draw(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try draw(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let tool = Process()
tool.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
tool.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try tool.run()
tool.waitUntilExit()
try? FileManager.default.removeItem(at: iconset) 
exit(tool.terminationStatus)
