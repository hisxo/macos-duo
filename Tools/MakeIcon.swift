import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        // lockFocus() uses the current display's backing scale and doubles the
        // pixels on Retina. An explicit bitmap keeps every ICNS slot exact.
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let context = NSGraphicsContext.current!.cgContext
        context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 214, yRadius: 214)
        NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.30, alpha: 1), ending: NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.11, alpha: 1))!.draw(in: background, angle: -60)
        context.saveGState()
        context.translateBy(x: 450, y: 540)
        context.rotate(by: .pi / 12)
        let rear = NSBezierPath(roundedRect: NSRect(x: -236, y: -205, width: 472, height: 410), xRadius: 65, yRadius: 65)
        NSGradient(starting: NSColor(calibratedRed: 1, green: 0.73, blue: 0.54, alpha: 1), ending: NSColor(calibratedRed: 0.59, green: 0.34, blue: 0.53, alpha: 1))!.draw(in: rear, angle: -65)
        context.restoreGState()
        let front = NSBezierPath(roundedRect: NSRect(x: 348, y: 240, width: 478, height: 410), xRadius: 65, yRadius: 65)
        NSGradient(starting: NSColor(calibratedRed: 0.94, green: 0.74, blue: 0.69, alpha: 0.96), ending: NSColor(calibratedRed: 0.29, green: 0.30, blue: 0.46, alpha: 0.98))!.draw(in: front, angle: -70)
        NSColor(calibratedWhite: 1, alpha: 0.55).setStroke()
        front.lineWidth = 6
        front.stroke()
        NSGraphicsContext.restoreGraphicsState()
        precondition(rep.pixelsWide == pixels && rep.pixelsHigh == pixels)
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
