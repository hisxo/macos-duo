import SwiftUI
import AppKit

@main
struct DuoApp: App {
    @NSApplicationDelegateAdaptor(DuoDelegate.self) var delegate
    @StateObject private var model: DuoModel
    init() {
        if CommandLine.arguments.contains("--self-test") {
            do { try SelfTest.run(); exit(0) }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        }
        do {
            let model = try DuoModel()
            _model = StateObject(wrappedValue: model)
        }
        catch {
            let alert = NSAlert()
            alert.messageText = Localization.text("startup.failed", language: Localization.savedLanguage)
            alert.informativeText = error.localizedDescription
            alert.runModal()
            exit(1)
        }
    }
    var body: some Scene {
        Window("MacOS Duo", id: "main") {
            Dashboard(model: model)
                .preferredColorScheme(.dark)
                .environment(\.locale, model.locale)
                .task {
                    if CommandLine.arguments.contains("--integration-test") {
                        do { try await model.integrationTest(); NSApp.terminate(nil) }
                        catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
                    }
                }
        }
        .defaultSize(width: 1000, height: 720)
        .windowResizability(.contentSize)
        .commands { CommandGroup(replacing: .newItem) {} }
        MenuBarExtra("MacOS Duo", systemImage: "laptopcomputer") {
            MenuControls(model: model).environment(\.locale, model.locale)
        }
    }
}

final class DuoDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--ui-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let windows = NSApp.windows.filter { $0.title == "MacOS Duo" }
                print("UI windows: \(windows.map { "\($0.title) \($0.frame) visible=\($0.isVisible)" })")
                guard let window = windows.first, let view = window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/validation/dashboard.png")
                try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
                print("UI snapshot: \(url.path)")
                NSApp.terminate(nil)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct MenuControls: View {
    @ObservedObject var model: DuoModel
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Text(model.sensorLabel)
        Toggle(model.t("Lid animation"), isOn: $model.enabled)
        Toggle(model.t("Launch at login"), isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
        Divider()
        Button(model.t("Open MacOS Duo")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Button(model.t("Preview on desktop")) { model.play(fullScreen: true) }
        Button(model.t("Dismiss animation")) { model.escape() }.keyboardShortcut(.escape, modifiers: [])
        Divider()
        Button(model.t("Quit MacOS Duo")) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

private let peach = Color(red: 1, green: 0.72, blue: 0.55)
struct Dashboard: View {
    @ObservedObject var model: DuoModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle.angled").font(.system(size: 25)).foregroundStyle(peach)
                    Text("duo").font(.system(size: 30, weight: .semibold, design: .rounded))
                }.padding(.top, 16)
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.t("Overview"), systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 13, weight: .medium)).padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(peach.opacity(0.12), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(peach)
                    Text(model.t("MOTION, MADE PHYSICAL")).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary).padding(.top, 18)
                    Text(model.t("A little magic in\nevery open and close.")).font(.system(size: 15)).foregroundStyle(.secondary).lineSpacing(5)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t("Language")).font(.system(size: 12)).foregroundStyle(.secondary)
                    Picker(model.t("Language"), selection: $model.language) {
                        Text(model.t("System")).tag(AppLanguage.system)
                        Text("English").tag(AppLanguage.en)
                        Text("Français").tag(AppLanguage.fr)
                    }.labelsHidden().pickerStyle(.menu)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 9) {
                    Circle().fill(model.angle == nil ? .orange : .green).frame(width: 7, height: 7)
                    Text(model.angle.map { "\(Int($0))°" } ?? "—").font(.system(size: 38, weight: .light, design: .rounded)).monospacedDigit()
                    Text(model.t(model.angle == nil ? "Preview mode" : "Live hinge angle")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Divider().overlay(.white.opacity(0.07))
                Text("MACOS DUO  /  \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(.tertiary)
            }.padding(24).frame(width: 190).background(Color(red: 0.065, green: 0.07, blue: 0.085))
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.t("Make the everyday fluid.")).font(.system(size: 29, weight: .medium))
                        Text(model.t("The Duo fold effect, reimagined for your Mac.")).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(model.t("Enabled"), isOn: $model.enabled).toggleStyle(.switch).tint(peach).font(.system(size: 12))
                }
                VStack(spacing: 0) {
                    HStack {
                        Label(model.t("MOTION PREVIEW"), systemImage: "sparkles").font(.system(size: 10, weight: .semibold)).tracking(1.4)
                        Spacer()
                        Text(model.t(model.previewProgress < 0.01 ? "OPEN" : model.previewProgress > 0.99 ? "CLOSED" : "IN MOTION"))
                            .font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(peach)
                    }.foregroundStyle(.secondary).padding(18)
                    ZStack {
                        Ellipse().fill(peach.opacity(0.10)).frame(width: 360, height: 70).blur(radius: 35).offset(y: 92)
                        VStack(spacing: 0) {
                            MetalPreview(renderer: model.previewRenderer, progress: model.previewProgress, frost: model.frost, spanDegrees: model.previewSpan, revision: model.previewRevision)
                                .frame(width: 390, height: 238)
                                .overlay(alignment: .top) { Capsule().fill(.black).frame(width: 50, height: 8) }
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                .padding(7).background(Color(white: 0.025), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.19), lineWidth: 1))
                            UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14)
                                .fill(LinearGradient(colors: [Color(white: 0.4), Color(white: 0.15)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 454, height: 10)
                        }.padding(.bottom, 16)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "laptopcomputer").foregroundStyle(.secondary)
                        Slider(value: $model.previewAngle, in: 5...180, onEditingChanged: { editing in
                            if editing { model.stopDemo(); model.followLid = false }
                        }).tint(peach).accessibilityLabel(model.t("Preview lid angle"))
                        Text("\(Int(model.followLid ? (model.angle ?? 110) : model.previewAngle))°")
                            .font(.system(size: 12, design: .monospaced)).frame(width: 38)
                        Button { model.playing ? model.stopDemo() : model.play() } label: {
                            Image(systemName: model.playing ? "stop.fill" : "play.fill").frame(width: 24, height: 24)
                        }.buttonStyle(.bordered).help(model.t("Play close and open cycle"))
                    }.padding(.horizontal, 20).padding(.bottom, 16)
                }.background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.07)))
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(model.t("Tune the feeling")).font(.system(size: 14, weight: .medium))
                            Spacer()
                            Button(model.t("Reset")) { model.resetSettings() }.font(.system(size: 11))
                                .help(model.t("reset.help"))
                        }
                        HStack { Text(model.t("Begin folding")); Spacer(); Text("\(Int(model.threshold))°").foregroundStyle(peach).monospacedDigit() }.font(.system(size: 12))
                        Slider(value: $model.threshold, in: 35...100).tint(peach).accessibilityLabel(model.t("Animation start angle"))
                        HStack { Text(model.t("Frosted glass")); Spacer(); Text(String(format: "%.0f%%", model.frost * 100)).foregroundStyle(peach).monospacedDigit() }.font(.system(size: 12))
                        Slider(value: $model.frost, in: 0...2).tint(peach).accessibilityLabel(model.t("Frost intensity"))
                    }.padding(18).frame(maxWidth: .infinity).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text(model.t("Your screen in motion")).font(.system(size: 14, weight: .medium)); Spacer(); Image(systemName: model.captureVerified ? "checkmark.shield" : "lock.shield").foregroundStyle(peach) }
                        Text(model.localizedCaptureStatus)
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button(model.t("Choose my screen")) { model.requestPermission() }
                                .buttonStyle(.borderedProminent).tint(peach).foregroundStyle(.black)
                            Button(model.t(model.checkingCapture ? "Checking…" : "Verify")) { model.verifyCapture() }
                                .disabled(model.checkingCapture)
                        }
                        HStack {
                            Button(model.t("macOS Settings")) { model.openCaptureSettings() }
                            Button(model.t("Test effect")) { model.play(fullScreen: true) }.disabled(!model.captureVerified)
                        }.font(.system(size: 11))
                        Toggle(model.t("Preview follows physical lid"), isOn: $model.followLid).font(.system(size: 11)).disabled(model.angle == nil)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.t("backward.title")).font(.system(size: 14, weight: .medium))
                    Text(model.t("backward.description")).font(.system(size: 11)).foregroundStyle(.secondary)
                    HStack {
                        Text(model.t("backward.start"))
                        Slider(value: $model.backwardStart, in: 105...150).accessibilityLabel(model.t("backward.start"))
                        Text("\(Int(model.backwardStart))°").monospacedDigit().frame(width: 45)
                    }
                    HStack {
                        Text(model.t("backward.end"))
                        Slider(value: $model.backwardEnd, in: (model.backwardStart + 10)...180).accessibilityLabel(model.t("backward.end"))
                        Text("\(Int(model.backwardEnd))°").monospacedDigit().frame(width: 45)
                    }
                    HStack {
                        Text(model.t("backward.strength"))
                        Slider(value: $model.backwardStrength, in: 0...1).accessibilityLabel(model.t("backward.strength"))
                        Text(String(format: "%.0f%%", model.backwardStrength * 100)).monospacedDigit().frame(width: 45)
                    }
                }.font(.system(size: 12)).tint(peach).padding(18)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                HStack {
                    Text(model.localizedMessage).lineLimit(2)
                    Spacer()
                    Text(model.t("ESC TO DISMISS")).font(.system(size: 8, weight: .medium)).tracking(1)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
                Text(model.t("footer")).font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(28).frame(width: 780)
            }.frame(width: 780)
        }.frame(height: 800).background(Color(red: 0.085, green: 0.09, blue: 0.11))
    }
}
