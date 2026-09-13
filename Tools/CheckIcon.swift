import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let url = root.appendingPathComponent("Duo.iconset/icon_\(size)x\(size)\(suffix).png")
        let bitmap = NSBitmapImageRep(data: try Data(contentsOf: url))!
        precondition(bitmap.pixelsWide == size * scale && bitmap.pixelsHigh == size * scale,
                     "Incorrect Retina dimensions in icon slot")
    }
}
let image = NSImage(contentsOf: root.appendingPathComponent("MacOS Duo.app/Contents/Resources/Duo.icns"))!
precondition(image.isValid)
let sizes = Set(image.representations.map { $0.pixelsWide })
precondition(sizes == Set([16, 32, 64, 128, 256, 512, 1024]))
print("PASS: 10 exact-size PNG slots and all ICNS resolutions decode correctly")
