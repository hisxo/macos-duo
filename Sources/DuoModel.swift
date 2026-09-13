import AppKit
import SwiftUI
import ScreenCaptureKit
import ServiceManagement

func foldProgress(angle: Double, start: Double, end: Double = 5) -> Double {
    min(1, max(0, (start - angle) / max(1, start - end)))
}

func smoothFollow(current: Double, target: Double, dt: Double) -> Double {
    current + (target - current) * (1 - exp(-max(0, min(dt, 0.05)) / 0.14))
}

func lidProgress(angle: Double, closingStart: Double, backwardStart: Double, backwardEnd: Double, backwardStrength: Double) -> Double {
    if angle > backwardStart {
        return min(1, max(0, (angle - backwardStart) / max(1, backwardEnd - backwardStart))) * min(1, max(0, backwardStrength))
    }
    return foldProgress(angle: angle, start: closingStart)
}

@MainActor
final class DuoModel: ObservableObject {
    @Published var language = Localization.savedLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    @Published var backwardStart = UserDefaults.standard.object(forKey: "backwardStart") as? Double ?? 120 {
        didSet {
            UserDefaults.standard.set(backwardStart, forKey: "backwardStart")
            if backwardEnd < backwardStart + 10 { backwardEnd = backwardStart + 10 }
        }
    }
    @Published var backwardEnd = UserDefaults.standard.object(forKey: "backwardEnd") as? Double ?? 165 {
        didSet { UserDefaults.standard.set(backwardEnd, forKey: "backwardEnd") }
    }
    @Published var backwardStrength = UserDefaults.standard.object(forKey: "backwardStrength") as? Double ?? 0.65 {
        didSet { UserDefaults.standard.set(backwardStrength, forKey: "backwardStrength") }
    }
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); if !enabled { stopDemo(); dismissOverlay() } }
    }
    @Published var threshold = UserDefaults.standard.object(forKey: "threshold") as? Double ?? 75 {
        didSet { UserDefaults.standard.set(threshold, forKey: "threshold") }
    }
    @Published var frost = UserDefaults.standard.object(forKey: "frost") as? Double ?? 1.0 {
        didSet { UserDefaults.standard.set(frost, forKey: "frost") }
    }
    @Published var angle: Double?
    @Published var previewAngle = 110.0
    @Published var followLid = false
    @Published var permission = CGPreflightScreenCaptureAccess()
    @Published var message = "ready"
    @Published var messageDetail = ""
    @Published var playing = false
    @Published var fullScreenDemo = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var captureStatus = "capture.choose"
    @Published var captureDetail = ""
    @Published var checkingCapture = false
    @Published var awaitingCaptureRestart = false
    @Published var restarting = false
    @Published var captureVerified = false
    @Published var previewRevision = 0
    private var motionTimer: Timer?
    private var lastMotionTime = CACurrentMediaTime()
    private var overlayStarted = CACurrentMediaTime()
    let previewRenderer: FoldRenderer
    let overlayRenderer: FoldRenderer
    private let sensor = LidSensor()
    private var panel: NSPanel?
    private var overlayView: MTKView?
    private var demoTimer: Timer?
    private var verificationGeneration = 0
    private var accessProbe: () -> Bool = { CGPreflightScreenCaptureAccess() }
    private var captureOverride: (@MainActor (NSScreen) async throws -> CGImage)?
    private var observers: [NSObjectProtocol] = []
    private var keyMonitor: Any?
    private let escapeKey = EscapeKey()
    private var captureGeneration = 0
    private var capturePending = false
    private var suspended = false
    private var progress = 0.0
    private var target = 0.0
    private var suppressedUntilOpen = false
    private var lastReadingTime = CACurrentMediaTime()
    private var watchdog: Timer?

    init() throws {
        previewRenderer = try FoldRenderer()
        overlayRenderer = try FoldRenderer()
        sensor.onReading = { [weak self] reading in
            guard let self else { return }
            self.lastReadingTime = CACurrentMediaTime()
            if self.angle != reading { self.angle = reading }
            guard let reading else {
                self.target = 0
                if !self.fullScreenDemo { self.dismissOverlay() }
                return
            }
            if reading >= self.threshold && reading <= self.backwardStart { self.suppressedUntilOpen = false }
            guard self.enabled, !self.suspended, !self.fullScreenDemo, !self.suppressedUntilOpen else { return }
            self.target = self.effectProgress(reading)
        }
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = CACurrentMediaTime()
                let dt = now - self.lastMotionTime
                self.lastMotionTime = now
                guard self.enabled, !self.suspended, !self.fullScreenDemo, !self.suppressedUntilOpen else { return }
                self.progress = smoothFollow(current: self.progress, target: self.target, dt: dt)
                if self.target == 0 && self.progress < 0.0005 { self.dismissOverlay(); return }
                if self.target > 0.002 || self.panel != nil { self.showOverlay(progress: self.progress) }
            }
        }
        if !CommandLine.arguments.contains("--integration-test") { sensor.start() }
        escapeKey.action = { [weak self] in self?.escape() }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if !CommandLine.arguments.contains("--integration-test") { self?.refreshCaptureAccess() }
            }
        })
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if CACurrentMediaTime() - self.lastReadingTime > 2 && !self.fullScreenDemo { self.dismissOverlay() }
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.suspended = true; self?.stopDemo(); self?.dismissOverlay() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.suspended = false }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismissOverlay() }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.suspended = true; self?.stopDemo(); self?.dismissOverlay() }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.suspended = false }
        })
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                MainActor.assumeIsolated { self?.escape() }
            }
            return event
        }
    }

    func t(_ key: String) -> String { Localization.text(key, language: language) }
    var locale: Locale { Locale(identifier: language.resolved()) }
    var localizedMessage: String { t(message) + (messageDetail.isEmpty ? "" : " " + messageDetail) }
    var localizedCaptureStatus: String { t(checkingCapture ? "capture.checking" : captureStatus) }
    var captureActionLabel: String {
        if restarting { return t("capture.restarting") }
        if checkingCapture { return t("Checking…") }
        if awaitingCaptureRestart { return t("capture.restart") }
        return t(captureVerified ? "Test effect" : "capture.authorize")
    }
    func captureAction() {
        guard !checkingCapture && !restarting else { return }
        if awaitingCaptureRestart { restartApplication() }
        else if captureVerified { play(fullScreen: true) }
        else { requestPermission() }
    }
    func effectProgress(_ angle: Double) -> Double {
        lidProgress(angle: angle, closingStart: threshold, backwardStart: backwardStart, backwardEnd: backwardEnd, backwardStrength: backwardStrength)
    }
    private func span(for angle: Double) -> Double {
        angle > backwardStart ? -(backwardEnd - backwardStart) : threshold - 5
    }
    var previewProgress: Double { effectProgress(followLid ? (angle ?? 110) : previewAngle) }
    var previewSpan: Double { span(for: followLid ? (angle ?? 110) : previewAngle) }
    var sensorLabel: String { angle.map { "\(t("sensor.connected")) · \(Int($0))°" } ?? t("sensor.unavailable") }

    func requestPermission() {
        invalidateCapture()
        awaitingCaptureRestart = true
        captureStatus = "capture.settings"
        // This is the only permission request, and it requires an explicit click.
        CGRequestScreenCaptureAccess()
        openCaptureSettings()
    }

    func openCaptureSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        captureStatus = "capture.settings"; captureDetail = ""
    }

    func restartApplication() {
        guard !restarting else { return }
        restarting = true
        stopDemo(); dismissOverlay()
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        // The path is a positional argument, never interpolated into shell code.
        // Wait for this process to exit before opening the exact same app copy.
        helper.arguments = ["-c", "n=0; while kill -0 \"$2\" 2>/dev/null; do n=$((n+1)); [ \"$n\" -lt 100 ] || exit 1; sleep 0.1; done; exec /usr/bin/open \"$1\"", "duo-relaunch", Bundle.main.bundleURL.path, String(ProcessInfo.processInfo.processIdentifier)]
        do { try helper.run(); NSApp.terminate(nil) }
        catch {
            restarting = false
            captureStatus = "capture.restartFailed"; captureDetail = error.localizedDescription
        }
    }

    func refreshCaptureAccess() {
        guard !awaitingCaptureRestart else { return }
        let wasGranted = permission
        permission = accessProbe()
        if !permission && wasGranted {
            invalidateCapture()
        }
        if permission && !captureVerified && !checkingCapture && (!wasGranted || captureStatus == "capture.choose") {
            verifyCapture()
        }
    }

    private func invalidateCapture() {
        verificationGeneration += 1
        checkingCapture = false
        captureVerified = false
        stopDemo(); dismissOverlay()
        captureStatus = "capture.required"; captureDetail = ""
    }

    func verifyCapture() {
        guard !checkingCapture && !awaitingCaptureRestart else { return }
        permission = accessProbe()
        guard permission else {
            captureVerified = false
            captureStatus = "capture.required"; captureDetail = ""
            return
        }
        stopDemo(); dismissOverlay()
        verificationGeneration += 1
        let generation = verificationGeneration
        checkingCapture = true
        Task {
            defer { if generation == verificationGeneration { checkingCapture = false } }
            do {
                guard let screen = builtInScreen ?? NSScreen.main else {
                    throw NSError(domain: "Duo", code: 3, userInfo: [NSLocalizedDescriptionKey: t("display.missing")])
                }
                let image = try await captureDesktop(screen: screen)
                guard generation == verificationGeneration else { return }
                try previewRenderer.setImage(image)
                previewRevision += 1
                captureVerified = true
                captureStatus = "capture.verified"; captureDetail = ""
            } catch {
                guard generation == verificationGeneration else { return }
                invalidateCapture()
                captureStatus = "capture.failed"; captureDetail = error.localizedDescription
            }
        }
    }

    private func captureDesktop(screen: NSScreen) async throws -> CGImage {
        if let captureOverride { return try await captureOverride(screen) }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw NSError(domain: "Duo", code: 3, userInfo: [NSLocalizedDescriptionKey: t("display.missing")])
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * screen.backingScaleFactor)
        config.height = Int(screen.frame.height * screen.backingScaleFactor)
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    func resetSettings() {
        stopDemo(); dismissOverlay()
        threshold = 75
        frost = 1
        backwardStart = 120; backwardEnd = 165; backwardStrength = 0.65
        enabled = true
        previewAngle = 110
        followLid = false
        target = 0
        suppressedUntilOpen = true
        message = "reset.done"; messageDetail = ""
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                message = "login.approval"; messageDetail = ""
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            message = "login.failed"; messageDetail = error.localizedDescription
        }
    }

    func play(fullScreen: Bool = false) {
        if fullScreen && !captureVerified && !CommandLine.arguments.contains("--integration-test") {
            captureStatus = "capture.required"; captureDetail = ""
            message = captureStatus
            return
        }
        stopDemo()
        followLid = false
        fullScreenDemo = fullScreen
        playing = true
        let start = CACurrentMediaTime()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let elapsed = CACurrentMediaTime() - start
                if elapsed >= 5.5 { self.stopDemo(); return }
                let phase = min(1, max(0, (elapsed - 0.4) / 4.6))
                let p = pow(sin(phase * .pi), 2)
                self.previewAngle = self.threshold - p * (self.threshold - 5)
                if fullScreen { self.showOverlay(progress: p) }
            }
        }
        message = fullScreen ? "preview.desktop" : "preview.playing"; messageDetail = ""
    }

    func stopDemo() {
        demoTimer?.invalidate(); demoTimer = nil
        playing = false
        previewAngle = 110
        if fullScreenDemo { dismissOverlay() }
        fullScreenDemo = false
    }

    func escape() {
        stopDemo()
        dismissOverlay()
        suppressedUntilOpen = true
    }

    func dismissOverlay() {
        escapeKey.unregister()
        captureGeneration += 1
        capturePending = false
        // Detach scheduled MetalKit callbacks before releasing the captured image.
        overlayView?.isPaused = true
        overlayView?.enableSetNeedsDisplay = false
        overlayView?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
        progress = 0
        // Release the desktop snapshot as soon as the transition ends.
        if overlayRenderer.texture != nil { overlayRenderer.texture = nil }
    }

    private var builtInScreen: NSScreen? {
        NSScreen.screens.first { screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            return CGDisplayIsBuiltin(id) != 0
        }
    }

    private func showOverlay(progress: Double) {
        guard !checkingCapture && !awaitingCaptureRestart else { return }
        // Fade the optical transformation in after capture becomes available.
        // The panel itself starts transparent to avoid a black first drawable.
        let entry = min(1, max(0, (CACurrentMediaTime() - overlayStarted) / 0.32))
        let easedEntry = entry * entry * (3 - 2 * entry)
        overlayRenderer.settings.progress = Float(progress * (panel == nil ? 0 : easedEntry))
        overlayRenderer.settings.frost = Float(frost)
        overlayRenderer.settings.foldSpan = Float(span(for: fullScreenDemo ? previewAngle : (angle ?? 110))) * .pi / 180
        overlayRenderer.settings.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
        if let overlayView {
            let exit = min(1, max(0, progress / 0.015))
            panel?.alphaValue = easedEntry * exit * exit * (3 - 2 * exit)
            overlayView.setNeedsDisplay(overlayView.bounds); return
        }
        let artworkTest = CommandLine.arguments.contains("--integration-test")
        guard artworkTest || captureVerified else { return }
        guard !capturePending, let screen = builtInScreen ?? (fullScreenDemo ? NSScreen.main : nil) else { return }
        capturePending = true
        captureGeneration += 1
        let generation = captureGeneration
        Task {
            var captured: CGImage?
            if !artworkTest {
                do {
                    captured = try await captureDesktop(screen: screen)
                } catch {
                    guard generation == captureGeneration else { return }
                    invalidateCapture()
                    captureStatus = "capture.failed"; captureDetail = error.localizedDescription
                    return
                }
            }
            guard generation == captureGeneration, !suspended else { return }
            capturePending = false
            do { try overlayRenderer.setImage(captured ?? FoldRenderer.artwork()) }
            catch { message = "effect.failed"; messageDetail = error.localizedDescription; return }
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.isReleasedWhenClosed = false
            let view = MTKView(frame: NSRect(origin: .zero, size: screen.frame.size), device: overlayRenderer.device)
            view.colorPixelFormat = .bgra8Unorm
            view.isPaused = true
            view.enableSetNeedsDisplay = true
            view.delegate = overlayRenderer
            panel.contentView = view
            panel.setFrame(screen.frame, display: false)
            self.panel = panel
            overlayStarted = CACurrentMediaTime()
            panel.alphaValue = 0
            overlayView = view
            escapeKey.register()
            panel.orderFrontRegardless()
            view.setNeedsDisplay(view.bounds)
            // A stuck capture or sensor must never leave a permanent desktop overlay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self, self.captureGeneration == generation else { return }
                self.escape()
            }
        }
    }

    func integrationTest() async throws {
        let savedProbe = accessProbe
        defer { accessProbe = savedProbe; captureOverride = nil }
        accessProbe = { false }
        var attempts = 0
        captureOverride = { _ in attempts += 1; return FoldRenderer.artwork() }
        awaitingCaptureRestart = true
        try SelfTest.require(captureActionLabel == t("capture.restart"), "Setup must offer exactly one restart action")
        refreshCaptureAccess()
        verifyCapture()
        try SelfTest.require(attempts == 0 && !checkingCapture, "Setup must not capture before restart")
        awaitingCaptureRestart = false
        try SelfTest.require(captureActionLabel == t("capture.authorize"), "Fresh process must offer authorization until verified")
        verifyCapture()
        try await Task.sleep(nanoseconds: 50_000_000)
        try SelfTest.require(attempts == 0 && !captureVerified, "Denied access must not trigger a capture or permission dialog")
        accessProbe = { true }
        refreshCaptureAccess()
        try await Task.sleep(nanoseconds: 300_000_000)
        try SelfTest.require(attempts == 1 && captureVerified && !checkingCapture, "Returning after permission grant must verify a real image")
        try SelfTest.require(captureActionLabel == t("Test effect"), "Only a verified capture may enable the desktop test")
        accessProbe = { false }
        refreshCaptureAccess()
        try SelfTest.require(!captureVerified, "Revoking persistent access must disable capture")
        accessProbe = { true }
        captureOverride = { _ in attempts += 1; throw NSError(domain: "CaptureTest", code: 1) }
        verifyCapture()
        try await Task.sleep(nanoseconds: 50_000_000)
        let attemptsAfterFailure = attempts
        refreshCaptureAccess()
        try await Task.sleep(nanoseconds: 50_000_000)
        try SelfTest.require(!captureVerified && attempts == attemptsAfterFailure, "Failed capture must not automatically retry on activation")
        captureOverride = { _ in
            try await Task.sleep(nanoseconds: 100_000_000)
            return FoldRenderer.artwork()
        }
        verifyCapture()
        invalidateCapture()
        try await Task.sleep(nanoseconds: 200_000_000)
        try SelfTest.require(!captureVerified && !checkingCapture, "Stale verification must not restore revoked access")
        captureOverride = nil
        print("PASS: capture workflow denied, granted, revoked, failed without retry, and stale success (injected capture transport)")
        captureVerified = true
        checkingCapture = true
        let oldVerification = verificationGeneration
        invalidateCapture()
        try SelfTest.require(!captureVerified && !checkingCapture && verificationGeneration > oldVerification,
                             "Capture invalidation must stop retries and cancel stale verification")
        print("PASS: revoked/failed capture disables automatic retries and invalidates pending verification")
        let oldPermission = permission
        permission = false
        fullScreenDemo = true
        defer { permission = oldPermission; fullScreenDemo = false; dismissOverlay() }
        showOverlay(progress: 0.4)
        try await Task.sleep(nanoseconds: 600_000_000)
        try SelfTest.require(panel?.isVisible == true, "Full-screen overlay did not open")
        try SelfTest.require(panel?.ignoresMouseEvents == true, "Overlay must pass through clicks")
        try SelfTest.require(overlayRenderer.framesDrawn > 0, "Overlay did not present a Metal frame")
        try SelfTest.require(escapeKey.isRegistered, "Global Escape shortcut was not registered")
        sensor.onReading?(nil)
        try SelfTest.require(panel?.isVisible == true, "Manual preview must survive an unavailable lid sensor")
        let retiredView = overlayView
        let framesBeforeDismissal = overlayRenderer.framesDrawn
        escape()
        try SelfTest.require(panel == nil && overlayRenderer.texture == nil, "Escape must dismiss and release the desktop")
        try SelfTest.require(retiredView?.delegate == nil && retiredView?.isPaused == true,
                             "Dismissal must detach MetalKit callbacks")
        if let retiredView {
            for _ in 0..<100 { overlayRenderer.draw(in: retiredView) }
        }
        try SelfTest.require(overlayRenderer.framesDrawn == framesBeforeDismissal,
                             "Late draws must not submit frames after texture release")
        print("PASS: detached MetalKit delegate and 100 late draw callbacks after dismissal")
        fullScreenDemo = true
        showOverlay(progress: 0.6)
        dismissOverlay()
        try await Task.sleep(nanoseconds: 300_000_000)
        try SelfTest.require(panel == nil, "Cancelled capture must not recreate overlay")
        play(fullScreen: true)
        try await Task.sleep(nanoseconds: 6_000_000_000)
        try SelfTest.require(!playing && panel == nil, "Full close/open demo must clean up")
        let savedThreshold = threshold, savedFrost = frost, savedEnabled = enabled
        let savedBackwardStart = backwardStart, savedBackwardEnd = backwardEnd, savedBackwardStrength = backwardStrength
        let savedLanguage = language
        let savedLogin = launchAtLogin
        defer {
            threshold = savedThreshold; frost = savedFrost; enabled = savedEnabled
            backwardStart = savedBackwardStart; backwardEnd = savedBackwardEnd; backwardStrength = savedBackwardStrength
            language = savedLanguage
        }
        language = .fr
        message = "ready"
        try SelfTest.require(localizedMessage == Localization.strings["ready"]!.fr, "French live status")
        language = .en
        try SelfTest.require(localizedMessage == Localization.strings["ready"]!.en, "Status switches language without restarting")
        threshold = 40; frost = 0.2; enabled = false; followLid = true
        resetSettings()
        try SelfTest.require(threshold == 75 && frost == 1 && enabled && !followLid && previewAngle == 110,
                             "Reset must restore animation defaults")
        try SelfTest.require(launchAtLogin == savedLogin && permission == false,
                             "Animation reset must preserve system preferences")
        try SelfTest.require(backwardStart == 120 && backwardEnd == 165 && backwardStrength == 0.65 && language == .en,
                             "Reset restores backward defaults and preserves selected language")
        print("PASS: reset restores animation defaults and preserves system preferences")
        print("PASS: overlay presentation, Metal drawable, click-through, global Escape registration and cleanup, unsupported sensor preview, stale capture cancellation, complete demo cleanup")
    }
}

import MetalKit
