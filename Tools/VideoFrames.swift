import AppKit
import AVFoundation

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { fatalError("Usage: swift Tools/VideoFrames.swift movie output-directory [start] [step]") }
let asset = AVURLAsset(url: URL(fileURLWithPath: arguments[1]))
let duration = CMTimeGetSeconds(asset.duration)
let start = arguments.count > 3 ? Double(arguments[3])! : 0
let step = arguments.count > 4 ? Double(arguments[4])! : max(0.1, duration / 20)
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: 800, height: 800)
let count = min(24, Int(ceil((duration - start) / step)))
let sheet = NSImage(size: CGSize(width: 1600, height: CGFloat((count + 3) / 4) * 280))
sheet.lockFocus()
NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
NSRect(origin: .zero, size: sheet.size).fill()
for i in 0..<count {
    let time = start + Double(i) * step
    guard let frame = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) else { continue }
    let bitmap = NSBitmapImageRep(cgImage: frame)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(String(format: "frame-%02d.png", i)))
    let ratio = min(390 / CGFloat(frame.width), 248 / CGFloat(frame.height))
    let x = CGFloat(i % 4) * 400
    let y = sheet.size.height - CGFloat(i / 4 + 1) * 280
    NSImage(cgImage: frame, size: .zero).draw(in: NSRect(x: x + (400 - CGFloat(frame.width) * ratio) / 2, y: y + 25, width: CGFloat(frame.width) * ratio, height: CGFloat(frame.height) * ratio))
    (String(format: "%.2fs", time) as NSString).draw(at: CGPoint(x: x + 12, y: y + 5), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white])
}
sheet.unlockFocus()
let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("contact-sheet.png"))
print("Duration: \(duration)s; extracted \(count) frames to \(output.path)")
