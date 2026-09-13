import Foundation
import IOKit.hid

// HID identifiers and feature-report layout documented by Sam Henri Gold:
// https://github.com/samhenrigold/LidAngleSensor
final class LidSensor {
    private let queue = DispatchQueue(label: "io.macosduo.lid", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    var onReading: ((Double?) -> Void)?

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
            self.manager = manager
            IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x05ac, kIOHIDProductIDKey: 0x8104,
                kIOHIDDeviceUsagePageKey: 0x20, kIOHIDDeviceUsageKey: 0x8a] as CFDictionary)
            IOHIDManagerOpen(manager, 0)
            self.device = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first
            if let device = self.device, IOHIDDeviceOpen(device, 0) != kIOReturnSuccess { self.device = nil }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 1.0 / 60, leeway: .milliseconds(2))
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer = timer
            timer.resume()
        }
    }
    private func poll() {
        var angle: Double?
        if let device {
            var bytes = [UInt8](repeating: 0, count: 8)
            var count = bytes.count
            if IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &count) == kIOReturnSuccess, count >= 3 {
                let value = Double(UInt16(bytes[1]) | UInt16(bytes[2]) << 8)
                if value <= 180 { angle = value }
            }
        }
        let reading = angle
        DispatchQueue.main.async { [weak self] in self?.onReading?(reading) }
    }
    deinit {
        timer?.cancel()
        if let device { IOHIDDeviceClose(device, 0) }
        if let manager { IOHIDManagerClose(manager, 0) }
    }
}
