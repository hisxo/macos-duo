import AppKit
import SwiftUI
import MetalKit
import MetalPerformanceShaders

struct FoldSettings {
    var progress: Float = 0
    var frost: Float = 1
    var foldSpan: Float = 70 * .pi / 180
    var reducedMotion: Float = 0
}

final class FoldRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    var texture: MTLTexture?
    var settings = FoldSettings()
    private(set) var framesDrawn = 0

    init(loadResources: Bool = true) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "Duo", code: 1, userInfo: [NSLocalizedDescriptionKey: Localization.text("metal.unavailable", language: Localization.savedLanguage)])
        }
        self.device = device
        self.queue = queue
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let library = try device.makeLibrary(URL: url)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "foldVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "foldFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init()
        try setImage(Self.artwork())
    }

    func setImage(_ image: CGImage) throws {
        let source = try MTKTextureLoader(device: device).newTexture(cgImage: image, options: [
            .SRGB: false, .generateMipmaps: true,
            .textureUsage: (MTLTextureUsage.shaderRead.union(.pixelFormatView)).rawValue
        ])
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: source.pixelFormat, width: source.width, height: source.height, mipmapped: true)
        descriptor.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
        guard let result = device.makeTexture(descriptor: descriptor), let command = queue.makeCommandBuffer(),
              let copy = command.makeBlitCommandEncoder() else {
            throw NSError(domain: "Duo", code: 2, userInfo: [NSLocalizedDescriptionKey: Localization.text("metal.allocation", language: Localization.savedLanguage)])
        }
        copy.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: source.width, height: source.height, depth: 1), to: result, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
        copy.endEncoding()
        // Each mip is a Gaussian-filtered scale. Fractional LOD sampling produces
        // a smooth spatial blur, without boxy mip artifacts or per-frame baking.
        let gaussian = MPSImageGaussianBlur(device: device, sigma: 0.85)
        // Extend source colors during filtering too; zero padding would bake
        // dark halos into the mip levels even with a clamped shader sampler.
        gaussian.edgeMode = .clamp
        for level in 1..<source.mipmapLevelCount {
            guard let input = source.makeTextureView(pixelFormat: source.pixelFormat, textureType: .type2D, levels: level..<(level + 1), slices: 0..<1),
                  let output = result.makeTextureView(pixelFormat: result.pixelFormat, textureType: .type2D, levels: level..<(level + 1), slices: 0..<1) else { continue }
            gaussian.encode(commandBuffer: command, sourceTexture: input, destinationTexture: output)
        }
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        texture = result
    }

    @discardableResult
    func encode(_ pass: MTLRenderPassDescriptor, command: MTLCommandBuffer) -> Bool {
        // A queued draw can outlive the overlay's image. Check resources before
        // opening an encoder; every encoder that is opened MUST be ended.
        guard let texture else { return false }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        defer { encoder.endEncoding() }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&settings, length: MemoryLayout<FoldSettings>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        return true
    }

    func draw(in view: MTKView) {
        guard texture != nil, let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer() else { return }
        guard encode(pass, command: command) else { return }
        command.present(drawable)
        command.commit()
        framesDrawn += 1
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    static func artwork() -> CGImage {
        let width = 1440, height = 900
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let colors = [NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.22, alpha: 1).cgColor,
                      NSColor(calibratedRed: 0.40, green: 0.24, blue: 0.55, alpha: 1).cgColor,
                      NSColor(calibratedRed: 0.99, green: 0.60, blue: 0.40, alpha: 1).cgColor]
        let gradient = CGGradient(colorsSpace: ctx.colorSpace, colors: colors as CFArray, locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 300, y: 0), end: CGPoint(x: 1150, y: 900), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        for i in 0..<7 {
            let path = CGMutablePath()
            let offset = CGFloat(i) * 115
            path.move(to: CGPoint(x: -300 + offset, y: 0))
            path.addCurve(to: CGPoint(x: 1450 + offset, y: 1000), control1: CGPoint(x: 1250 + offset, y: 120), control2: CGPoint(x: 50 + offset, y: 790))
            ctx.addPath(path)
            ctx.setLineWidth(42)
            ctx.setStrokeColor(NSColor(calibratedRed: 1, green: 0.77, blue: 0.67, alpha: 0.13).cgColor)
            ctx.strokePath()
        }
        return ctx.makeImage()!
    }
}

struct MetalPreview: NSViewRepresentable {
    let renderer: FoldRenderer
    var progress: Double
    var frost: Double
    var spanDegrees: Double
    var revision: Int = 0
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.delegate = renderer
        return view
    }
    func updateNSView(_ view: MTKView, context: Context) {
        renderer.settings.progress = Float(progress)
        renderer.settings.frost = Float(frost)
        renderer.settings.foldSpan = Float(spanDegrees) * .pi / 180
        renderer.settings.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
        view.setNeedsDisplay(view.bounds)
    }
}
