# MacOS Duo

A native macOS menu-bar app that adapts the iPhone Duo's frosted-glass transition to the MacBook's physical lid movement. Built with SwiftUI, AppKit, Metal, and ScreenCaptureKit; no third-party runtime dependencies.

## Features

- Progressive blur and perspective driven by the physical hinge sensor.
- Two adjustable ranges: closing below 75°, and backward tilt beyond 120°. The backward range reaches its maximum at 165° with 65% intensity by default; set intensity to 0% to disable it.
- Gentle, refresh-rate-independent smoothing, gradual entry, and soft exit.
- Your actual desktop, selected using the native macOS display-sharing picker.
- English and French: automatic system-language detection and an immediate, persistent in-app override.
- Menu-bar controls, optional launch at login, Reduce Motion support, and Escape to dismiss.
- Reset restores animation defaults while preserving language, capture authorization, and launch-at-login preferences.

## Build and run

Requires macOS 14+, a Metal-capable Mac, and Xcode with its Metal compiler. Automatic animation requires a compatible Apple HID lid-angle sensor; the in-app preview works without one. Builds target the current architecture.

```sh
bash build.sh
open "build/MacOS Duo.app"
```

Drag the completed app to Applications to install it. Develop and test in `build/`; avoid rebuilding the installed/running copy while it holds capture authorization.

1. Click **Choose my screen / Choisir mon écran**, select the built-in display, and confirm sharing.
2. A successful capture replaces the preview artwork with your screen. **Verify / Vérifier** retries capture; **macOS Settings / Réglages macOS** opens persistent screen-recording permissions.
3. Leave animation enabled and move the lid, or use the 5–180° preview slider.
4. Configure the backward range in the section below the main settings.
5. Select **System default**, **English**, or **Français** in the sidebar.

The menu bar provides desktop preview, dismissal, login-item settings, and Quit. Closing the window leaves the app running. Escape suppresses automatic animation until the lid returns to its neutral range.

## Privacy and permissions

The production app does not upload or save screen captures. A desktop snapshot is held in memory during the fold and released when its overlay closes. A separate screenshot explicitly captured for preview stays in memory until replaced or the app exits.

Without capture access, artwork remains available only in the in-app preview. Automatic desktop effects are skipped; capture errors never replace the desktop with artwork.

The native picker authorizes selected content for the session. Persistent permissions belong to macOS. Builds are ad-hoc signed by default, so recompiling can invalidate an earlier grant. Quit the app, install the final build, and select the screen again. If needed, remove/re-add it in macOS Settings or reset only its grant:

```sh
tccutil reset ScreenCapture io.macosduo.app
```

This does not grant permission automatically. Stable certificate signing is needed to preserve identity across builds. Public binary distribution should use Developer ID signing and notarization. `DUO_BUNDLE_ID` optionally overrides the bundle identifier for an existing local installation; never commit local identity configuration.

## Platform limits

- Sleep and secure lock screens are controlled by macOS. The app clears its overlay on sleep/lock and supports opening transitions in an unlocked session.
- Automatic effects target the built-in screen; select that display in the picker. External screens are unaffected by lid motion.
- This is a single-display adaptation, not Apple's private implementation. Viewing position, hardware geometry, capture latency, and refresh rate affect appearance. See [the animation study](ANIMATION_STUDY.md).
- Do not force a hinge beyond its physical range. The 180° preview is a simulation, not a statement of hardware capability.
- Native permission dialogs follow macOS language settings; the language override controls the app's interface and status messages.

## Validation

```sh
MTL_DEBUG_LAYER=1 "build/MacOS Duo.app/Contents/MacOS/MacOSDuo" --self-test
MTL_DEBUG_LAYER=1 "build/MacOS Duo.app/Contents/MacOS/MacOSDuo" --integration-test
"build/MacOS Duo.app/Contents/MacOS/MacOSDuo" --ui-test --test-language=fr
"build/MacOS Duo.app/Contents/MacOS/MacOSDuo" --ui-test --test-language=en
```

Tests cover regional language detection, manual override, translation completeness, both motion ranges, smoothing, reversible GPU output, 54 angle/frost edge cases, and resource release. Native tests exercise the artwork overlay, drawables, global Escape registration, late callbacks, capture cancellation, reset, and demo cleanup. They do not grant screen recording or physically move the lid.

Test output stays in ignored `build/validation/`. AppKit view snapshots omit the separate Metal surface. `Tools/VideoFrames.swift` extracts time-stamped frames from a supplied local video; keep those outputs outside the repository. No research videos, screenshots, logs, credentials, or compiled binaries are included in the source repository.

## Source layout

| File | Responsibility |
| --- | --- |
| `Sources/App.swift` | Settings window and menu bar |
| `Sources/Localization.swift` | Language detection and English/French strings |
| `Sources/DuoModel.swift` | Motion ranges, capture, settings, and lifecycle |
| `Sources/ScreenPicker.swift` | Native display selection |
| `Sources/Renderer.swift` | GPU resources and Gaussian mip pyramid |
| `Sources/Fold.metal` | Projection, blur, haze, and extinction |
| `Sources/LidSensor.swift` | Nonexclusive HID feature-report reads |
| `Sources/EscapeKey.swift` | Temporary global Escape hotkey |

## Acknowledgements

HID identifiers and report layout are documented by [Sam Henri Gold's LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor). Visual references are linked in the animation study. No Apple wallpapers, videos, phone models, or third-party application source are bundled. This independent project is unaffiliated with Apple.
