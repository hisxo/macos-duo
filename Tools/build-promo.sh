#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROMO_APP=build/Promo.app
mkdir -p "$PROMO_APP/Contents/MacOS" "$PROMO_APP/Contents/Resources"
xcrun -sdk macosx metal -c Sources/Fold.metal -o build/PromoFold.air
xcrun -sdk macosx metallib build/PromoFold.air -o "$PROMO_APP/Contents/Resources/default.metallib"
xcrun swiftc -O -parse-as-library -swift-version 5 -target "$(uname -m)-apple-macosx14.0" Tools/Promo.swift Sources/Renderer.swift Sources/Localization.swift -o "$PROMO_APP/Contents/MacOS/Promo" -framework AppKit -framework SwiftUI -framework MetalKit -framework MetalPerformanceShaders -framework AVFoundation
"$PROMO_APP/Contents/MacOS/Promo" "${1:-build/promo}"
