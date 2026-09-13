import AppKit
import AVFoundation
import ImageIO

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: folder.appendingPathComponent("macos-duo.mp4"))
let video = try await asset.loadTracks(withMediaType: .video).first!
let videoDuration = try await asset.load(.duration)
let size = try await video.load(.naturalSize)
let frameRate = try await video.load(.nominalFrameRate)
let audioTracks = try await asset.loadTracks(withMediaType: .audio)
precondition(abs(videoDuration.seconds - 9) < 0.02)
precondition(size == CGSize(width: 1600, height: 1000))
precondition(frameRate == 60)
precondition(audioTracks.isEmpty)
let generator = AVAssetImageGenerator(asset: asset)
let first = try await generator.image(at: .zero).image
try NSBitmapImageRep(cgImage: first).representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("video-decoded.png"))
let source = CGImageSourceCreateWithURL(folder.appendingPathComponent("macos-duo.gif") as CFURL, nil)!
precondition(CGImageSourceGetCount(source) == 180)
var duration = 0.0
for frame in 0..<180 {
    let properties = CGImageSourceCopyPropertiesAtIndex(source, frame, nil)! as NSDictionary
    let gif = properties[kCGImagePropertyGIFDictionary] as! NSDictionary
    duration += (gif[kCGImagePropertyGIFUnclampedDelayTime] ?? gif[kCGImagePropertyGIFDelayTime]) as! Double
    precondition(CGImageSourceCreateImageAtIndex(source, frame, nil) != nil)
}
precondition(abs(duration - 9) < 0.02)
print("PASS: MP4 1600×1000, 60 fps, 9 seconds, no audio; GIF 180 decodable frames, 9 seconds")
let metadata = try await asset.load(.metadata)
print("Video metadata entries: \(metadata.count)")
