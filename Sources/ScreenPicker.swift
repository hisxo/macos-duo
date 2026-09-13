import AppKit
import ScreenCaptureKit

final class ScreenPicker: NSObject, SCContentSharingPickerObserver {
    var selected: ((SCContentFilter) -> Void)?
    var failed: ((String, String) -> Void)?
    override init() {
        super.init()
        SCContentSharingPicker.shared.add(self)
    }
    func present() {
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleDisplay]
        SCContentSharingPicker.shared.defaultConfiguration = configuration
        SCContentSharingPicker.shared.isActive = true
        SCContentSharingPicker.shared.present(using: .display)
    }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        DispatchQueue.main.async { [weak self] in self?.selected?(filter) }
    }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        DispatchQueue.main.async { [weak self] in self?.failed?("capture.cancelled", "") }
    }
    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in self?.failed?("capture.pickerFailed", error.localizedDescription) }
    }
    deinit { SCContentSharingPicker.shared.remove(self) }
}
