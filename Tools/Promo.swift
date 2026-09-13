// Offline promotional renderer. Uses synthetic content only; never captures a screen.
import AppKit
import AVFoundation
import ImageIO
import MetalKit
import UniformTypeIdentifiers

@main
enum Promo {
    static let width = 1600, height = 1000, fps = 60, frames = 540
    static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    static func rounded(_ c: CGContext, _ rect: CGRect, _ radius: CGFloat, _ fill: NSColor) {
        c.setFillColor(fill.cgColor)
        c.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); c.fillPath()
    }
    static func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ weight: NSFont.Weight, _ fill: NSColor) {
        (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: fill])
    }
    static func context(_ w: Int, _ h: Int) -> CGContext {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    static func desktop() -> CGImage {
        let c = context(1440, 900)
        c.draw(FoldRenderer.artwork(), in: CGRect(x: 0, y: 0, width: 1440, height: 900))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
        rounded(c, CGRect(x: 0, y: 864, width: 1440, height: 36), 0, color(0.06, 0.07, 0.13, 0.5))
        text("duo", 30, 871, 17, .bold, .white)
        text("File     Edit     View", 95, 871, 16, .regular, color(1, 1, 1, 0.8))
        text("09:41", 1350, 871, 16, .medium, .white)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -20), blur: 70, color: color(0, 0, 0, 0.3).cgColor)
        rounded(c, CGRect(x: 330, y: 245, width: 780, height: 420), 26, color(0.13, 0.12, 0.20, 0.86))
        c.restoreGState()
        for (i, col) in [color(1, 0.4, 0.38), color(1, 0.75, 0.3), color(0.3, 0.8, 0.52)].enumerated() {
            rounded(c, CGRect(x: 354 + i * 24, y: 630, width: 13, height: 13), 7, col)
        }
        text("A LITTLE LESS ORDINARY", 410, 534, 15, .medium, color(1, 0.75, 0.61))
        text("Hello, softer world.", 410, 445, 57, .medium, .white)
        text("A little motion. A different feeling.", 412, 397, 23, .regular, color(0.80, 0.78, 0.84))
        rounded(c, CGRect(x: 410, y: 307, width: 183, height: 45), 22, color(1, 0.75, 0.61))
        text("Made for your Mac", 431, 319, 16, .medium, color(0.17, 0.12, 0.15))
        rounded(c, CGRect(x: 506, y: 22, width: 428, height: 77), 23, color(1, 1, 1, 0.18))
        for i in 0..<6 {
            rounded(c, CGRect(x: 523 + i * 68, y: 34, width: 53, height: 53), 13,
                    [color(0.40, 0.69, 0.98), color(1, 0.65, 0.44), color(0.77, 0.62, 0.9), color(0.43, 0.8, 0.7), color(0.96, 0.88, 0.73), color(0.63, 0.68, 0.82)][i])
            rounded(c, CGRect(x: 540 + i * 68, y: 51, width: 19, height: 19), 6, color(1, 1, 1, 0.65))
        }
        NSGraphicsContext.restoreGraphicsState()
        return c.makeImage()!
    }
    static func smooth(_ x: Double) -> Double {
        let t = min(1, max(0, x)); return t * t * t * (t * (t * 6 - 15) + 10)
    }
    static func angle(_ time: Double) -> Double {
        if time < 0.8 { return 110 }
        if time < 4.2 { return 110 - 105 * smooth((time - 0.8) / 3.4) }
        if time < 4.6 { return 5 }
        if time < 8.2 { return 5 + 105 * smooth((time - 4.6) / 3.6) }
        return 110
    }
    static func compose(_ screen: CGImage, _ time: Double) -> CGImage {
        let c = context(width, height)
        c.setFillColor(color(0.035, 0.035, 0.05).cgColor); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let glow = CGGradient(colorsSpace: c.colorSpace, colors: [color(0.30, 0.17, 0.23, 0.55).cgColor, color(0.03, 0.03, 0.05, 0).cgColor] as CFArray, locations: [0, 1])!
        c.drawRadialGradient(glow, startCenter: CGPoint(x: 800, y: 510), startRadius: 0, endCenter: CGPoint(x: 800, y: 510), endRadius: 800, options: [])
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
        let peach = color(1, 0.75, 0.61)
        text("duo", 108, 889, 42, .semibold, peach)
        text("FOR macOS", 211, 900, 15, .medium, color(0.62, 0.59, 0.64))
        text("Even closing your Mac can feel beautiful.", 108, 802, 48, .medium, color(0.95, 0.93, 0.93))
        text("A frosted-glass transition, moved by your lid.", 110, 777, 23, .regular, color(0.63, 0.60, 0.66))
        rounded(c, CGRect(x: 1285, y: 891, width: 205, height: 42), 21, color(1, 0.77, 0.66, 0.08))
        text("NATIVE  /  METAL", 1310, 904, 14, .medium, peach)
        let device = CGRect(x: 341, y: 188, width: 918, height: 575)
        // Small breathing motion; the screen content itself uses the app's shader.
        let lift = 3 * sin(time / 9 * .pi * 2)
        c.saveGState(); c.translateBy(x: 0, y: lift)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -28), blur: 70, color: color(0, 0, 0, 0.7).cgColor)
        rounded(c, device, 26, color(0.29, 0.27, 0.29))
        c.restoreGState()
        rounded(c, device.insetBy(dx: 2, dy: 2), 24, color(0.04, 0.04, 0.045))
        c.saveGState()
        let display = device.insetBy(dx: 12, dy: 12)
        c.addPath(CGPath(roundedRect: display, cornerWidth: 15, cornerHeight: 15, transform: nil)); c.clip()
        c.draw(screen, in: display)
        c.restoreGState()
        rounded(c, CGRect(x: 756, y: 741, width: 88, height: 12), 5, color(0.025, 0.025, 0.03))
        let base = CGMutablePath()
        base.move(to: CGPoint(x: 341, y: 189)); base.addLine(to: CGPoint(x: 1259, y: 189))
        base.addLine(to: CGPoint(x: 1362, y: 164)); base.addQuadCurve(to: CGPoint(x: 1335, y: 152), control: CGPoint(x: 1358, y: 152))
        base.addLine(to: CGPoint(x: 265, y: 152)); base.addQuadCurve(to: CGPoint(x: 238, y: 164), control: CGPoint(x: 242, y: 152)); base.closeSubpath()
        c.saveGState(); c.addPath(base); c.clip()
        let metal = CGGradient(colorsSpace: c.colorSpace, colors: [color(0.15, 0.15, 0.17).cgColor, color(0.56, 0.54, 0.56).cgColor] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(metal, start: CGPoint(x: 0, y: 152), end: CGPoint(x: 0, y: 189), options: [])
        c.restoreGState()
        rounded(c, CGRect(x: 734, y: 177, width: 132, height: 12), 6, color(0.15, 0.14, 0.17))
        c.restoreGState()
        let a = angle(time)
        let state = time < 0.8 || time >= 8.2 ? "AT REST" : time < 4.2 ? "CLOSING" : time < 4.6 ? "CLOSED" : "OPENING"
        text(state, 108, 87, 14, .medium, peach)
        text(String(format: "%03.0f°", a), 108, 43, 32, .light, color(0.93, 0.90, 0.92))
        rounded(c, CGRect(x: 272, y: 68, width: 240, height: 3), 1.5, color(1, 1, 1, 0.10))
        rounded(c, CGRect(x: 272, y: 68, width: max(3, 240 * a / 110), height: 3), 1.5, peach)
        text("Smooth by nature.", 672, 70, 19, .regular, color(0.59, 0.56, 0.62))
        text("github.com/hisxo/macos-duo", 1190, 71, 17, .medium, color(0.72, 0.68, 0.73))
        NSGraphicsContext.restoreGraphicsState()
        return c.makeImage()!
    }
    static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/promo")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let movie = folder.appendingPathComponent("macos-duo.mp4")
        // Refuse to overwrite a previous export; use a new output directory.
        guard !FileManager.default.fileExists(atPath: movie.path) else { throw NSError(domain: "Promo", code: 1) }
        let writer = try AVAssetWriter(outputURL: movie, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        let gif = CGImageDestinationCreateWithURL(folder.appendingPathComponent("macos-duo.gif") as CFURL, UTType.gif.identifier as CFString, frames / 3, nil)!
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let renderer = try FoldRenderer(); try renderer.setImage(desktop())
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1080, height: 675, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]; desc.storageMode = .shared
        let output = renderer.device.makeTexture(descriptor: desc)!
        for frame in 0..<frames {
            try autoreleasepool {
                let time = Double(frame) / Double(fps)
                let a = angle(time)
                renderer.settings.progress = Float(min(1, max(0, (75 - a) / 70)))
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = output
                pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
                let command = renderer.queue.makeCommandBuffer()!
                guard renderer.encode(pass, command: command) else { throw NSError(domain: "Promo", code: 2) }
                command.commit(); command.waitUntilCompleted()
                if let error = command.error { throw error }
                var bytes = [UInt8](repeating: 0, count: 1080 * 675 * 4)
                output.getBytes(&bytes, bytesPerRow: 1080 * 4, from: MTLRegionMake2D(0, 0, 1080, 675), mipmapLevel: 0)
                let screen = CGImage(width: 1080, height: 675, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1080 * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                    provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
                let image = compose(screen, time)
                if [0, 165, 255, 390].contains(frame) {
                    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("still-\(frame).png"))
                }
                if frame % 3 == 0 {
                    let small = context(800, 500); small.interpolationQuality = .high
                    small.draw(image, in: CGRect(x: 0, y: 0, width: 800, height: 500))
                    CGImageDestinationAddImage(gif, small.makeImage()!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.05, kCGImagePropertyGIFUnclampedDelayTime: 0.05]] as CFDictionary)
                }
                while !input.isReadyForMoreMediaData {
                    if writer.status == .failed { throw writer.error! }
                    Thread.sleep(forTimeInterval: 0.002)
                }
                var buffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer) == kCVReturnSuccess, let buffer else { throw NSError(domain: "Promo", code: 3) }
                CVPixelBufferLockBaseAddress(buffer, [])
                let c = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
                c.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                CVPixelBufferUnlockBaseAddress(buffer, [])
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))) else { throw writer.error! }
            }
            if frame % 60 == 0 { print("Rendered \(frame)/\(frames)") }
        }
        guard CGImageDestinationFinalize(gif) else { throw NSError(domain: "Promo", code: 4) }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }; done.wait()
        guard writer.status == .completed else { throw writer.error! }
        print("Exported 9-second loop: H.264 1600×1000 @60fps + GIF 800×500 @20fps")
    }
}
