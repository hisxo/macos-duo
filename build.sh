#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/build/MacOS Duo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift Tools/MakeIcon.swift build/Duo.iconset
iconutil -c icns build/Duo.iconset -o "$APP/Contents/Resources/Duo.icns"
xcrun -sdk macosx metal -c Sources/Fold.metal -o build/Fold.air
xcrun -sdk macosx metallib build/Fold.air -o "$APP/Contents/Resources/default.metallib"
xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx14.0" Sources/*.swift -o "$APP/Contents/MacOS/MacOSDuo" -framework SwiftUI -framework AppKit -framework MetalKit -framework MetalPerformanceShaders -framework IOKit -framework ScreenCaptureKit -framework Carbon -framework ServiceManagement
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/en.lproj Resources/fr.lproj "$APP/Contents/Resources/"
# Optional local identity for existing installations; never store it in source.
if [ -n "${DUO_BUNDLE_ID:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $DUO_BUNDLE_ID" "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP"
echo "Built: $APP"
