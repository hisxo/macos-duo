import AppKit
import MetalKit

enum SelfTest {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "DuoTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    @MainActor static func run() throws {
        try require(AppLanguage.system.resolved(preferredLanguages: ["fr-CA", "en-US"]) == "fr", "Regional French detection")
        try require(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "fr-FR"]) == "en", "System preference ordering")
        try require(AppLanguage.system.resolved(preferredLanguages: ["de-DE"]) == "en", "Unsupported language fallback")
        try require(AppLanguage.en.resolved(preferredLanguages: ["fr-FR"]) == "en", "Manual language override")
        for (key, pair) in Localization.strings {
            try require(!pair.en.isEmpty && !pair.fr.isEmpty, "Missing translation: \(key)")
            try require(Localization.text(key, language: .en) == pair.en && Localization.text(key, language: .fr) == pair.fr,
                        "Translation selection: \(key)")
        }
        print("PASS: French/English regional detection, fallback, manual override and complete translation table")
        let backward: (Double) -> Double = { lidProgress(angle: $0, closingStart: 75, backwardStart: 120, backwardEnd: 165, backwardStrength: 0.65) }
        try require(backward(90) == 0 && backward(120) == 0, "Neutral range must be unaffected")
        try require(backward(120.001) < 0.0001, "Backward effect must enter continuously")
        try require(abs(backward(165) - 0.65) < 0.00001 && backward(180) == 0.65, "Backward intensity cap")
        for a in 120..<180 { try require(backward(Double(a)) <= backward(Double(a + 1)), "Backward ramp must increase monotonically") }
        try require(lidProgress(angle: 150, closingStart: 75, backwardStart: 130, backwardEnd: 170, backwardStrength: 0) == 0,
                    "Zero backward intensity disables the effect")
        try require(lidProgress(angle: 150, closingStart: 75, backwardStart: 130, backwardEnd: 170, backwardStrength: 0.8) == 0.4,
                    "Custom backward thresholds")
        print("PASS: backward onset at 120°, continuity, increasing ramp, custom thresholds and intensity")
        try require(foldProgress(angle: 120, start: 75) == 0, "Open endpoint")
        try require(foldProgress(angle: 5, start: 75) == 1, "Closed endpoint")
        try require(foldProgress(angle: -20, start: 75) == 1, "Clamp closed")
        var at60 = 0.0, at120 = 0.0
        for _ in 0..<60 { at60 = smoothFollow(current: at60, target: 1, dt: 1.0 / 60) }
        for _ in 0..<120 { at120 = smoothFollow(current: at120, target: 1, dt: 1.0 / 120) }
        try require(abs(at60 - at120) < 0.000001, "Motion smoothing must be independent of refresh rate")
        let firstStep = smoothFollow(current: 0, target: 1, dt: 1.0 / 60)
        try require(firstStep > 0 && firstStep < 0.12, "Sudden sensor changes must ease in")
        let reversal = smoothFollow(current: 0.5, target: 0, dt: 1.0 / 60)
        try require(reversal > 0.4 && reversal < 0.5, "Reversing the lid must remain smooth without overshoot")
        print("PASS: frame-rate-independent smoothing, gentle onset, continuous reversal")
        var previous = 1.0
        for angle in 0...180 {
            let p = foldProgress(angle: Double(angle), start: 75)
            try require(p <= previous, "Progress must be monotonic")
            previous = p
        }
        let renderer = try FoldRenderer()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 640, height: 400, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let output = renderer.device.makeTexture(descriptor: descriptor)!
        // Exercise a draw arriving after dismissal has released its texture.
        // Then open another encoder on that buffer: no encoder may be left open.
        let savedTexture = renderer.texture
        for iteration in 0..<100 {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = output
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            renderer.texture = nil
            let command = renderer.queue.makeCommandBuffer()!
            try require(!renderer.encode(pass, command: command), "Missing image must skip encoding")
            renderer.texture = savedTexture
            try require(renderer.encode(pass, command: command), "Rendering must recover after image restoration")
            command.commit(); command.waitUntilCompleted()
            try require(command.status == .completed, "Dismiss/reopen GPU cycle failed: \(iteration)")
        }
        print("PASS: 100 texture-release/restore cycles without an unfinished Metal encoder")
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/validation")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var images: [[UInt8]] = []
        for p in [Float(0), 0.25, 0.5, 0.75, 1, 0.5, 0] {
            renderer.settings.progress = p
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = output
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            let command = renderer.queue.makeCommandBuffer()!
            renderer.encode(pass, command: command)
            command.commit(); command.waitUntilCompleted()
            try require(command.status == .completed, "Metal command failed")
            var bytes = [UInt8](repeating: 0, count: 640 * 400 * 4)
            output.getBytes(&bytes, bytesPerRow: 640 * 4, from: MTLRegionMake2D(0, 0, 640, 400), mipmapLevel: 0)
            images.append(bytes)
            let provider = CGDataProvider(data: Data(bytes) as CFData)!
            let image = CGImage(width: 640, height: 400, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 640 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("fold-\(images.count).png"))
        }
        try require(images[0] == images[6], "Open image must return exactly after closing")
        try require(images[2] == images[5], "Opening and closing must render identically at the same angle")
        try require(images[0] != images[2], "Midpoint must visibly change")
        try require(stride(from: 0, to: images[4].count, by: 4).allSatisfy { images[4][$0] == 0 && images[4][$0 + 1] == 0 && images[4][$0 + 2] == 0 }, "Closed image must be black")
        // A uniform image must remain uniform across each horizontal scanline.
        // This detects black wedges from projection AND dark Gaussian edge halos.
        let context = CGContext(data: nil, width: 640, height: 400, bitsPerComponent: 8, bytesPerRow: 640 * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 400))
        try renderer.setImage(context.makeImage()!)
        for span in [Float(30), 70, 95, -30, -45, -75] {
            renderer.settings.foldSpan = span * .pi / 180
            for frost in [Float(0), 1, 2] {
                renderer.settings.frost = frost
                for progress in [Float(0.1), 0.5, 0.85] {
                    renderer.settings.progress = progress
                    let pass = MTLRenderPassDescriptor()
                    pass.colorAttachments[0].texture = output
                    pass.colorAttachments[0].loadAction = .clear
                    pass.colorAttachments[0].storeAction = .store
                    let command = renderer.queue.makeCommandBuffer()!
                    renderer.encode(pass, command: command)
                    command.commit(); command.waitUntilCompleted()
                    try require(command.status == .completed, "Edge regression GPU rendering failed")
                    var bytes = [UInt8](repeating: 0, count: 640 * 400 * 4)
                    output.getBytes(&bytes, bytesPerRow: 640 * 4, from: MTLRegionMake2D(0, 0, 640, 400), mipmapLevel: 0)
                    for y in [0, 40, 200, 360, 399] {
                        for x in [0, 1, 20, 619, 638, 639] {
                            for channel in 0..<3 {
                                let edge = Int(bytes[(y * 640 + x) * 4 + channel])
                                let center = Int(bytes[(y * 640 + 320) * 4 + channel])
                                try require(abs(edge - center) <= 2,
                                    "Lateral band: span=\(span), frost=\(frost), progress=\(progress), x=\(x), y=\(y), edge=\(edge), center=\(center)")
                            }
                        }
                    }
                }
            }
        }
        print("PASS: no lateral bands or blur halos across 54 forward/backward angle/frost combinations")
        print("PASS: endpoint, clamping, monotonicity, GPU rendering, reversible motion, closed blackout. Frames: \(directory.path)")
        let sensor = LidSensor()
        var reading: Double?
        sensor.onReading = { reading = $0 }
        sensor.start()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        print("Hardware probe: \(reading.map { "\($0)°" } ?? "sensor unavailable")")
    }
}
