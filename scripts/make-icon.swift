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
    let tile = NSBezierPath(roundedRect: NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit), xRadius: 186 * unit, yRadius: 186 * unit)
    let colors = [NSColor(srgbRed: 0.153, green: 0.388, blue: 0.843, alpha: 1), NSColor(srgbRed: 0.424, green: 0.773, blue: 1, alpha: 1),
                  NSColor(srgbRed: 0.561, green: 0.922, blue: 0.816, alpha: 1)]
    NSGradient(colors: colors)?.draw(in: tile, angle: -50)
    NSColor.white.setFill()
    for (index, height) in [CGFloat(200), 460, 310, 160].enumerated() {
        let rect = NSRect(x: (270 + CGFloat(index) * 134) * unit, y: (512 - height / 2) * unit, width: 82 * unit, height: height * unit)
        NSBezierPath(roundedRect: rect, xRadius: 41 * unit, yRadius: 41 * unit).fill()
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
