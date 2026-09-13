#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Public releases always use the repository's neutral application identity.
unset DUO_BUNDLE_ID
mkdir -p build/release
DUO_ARCH=arm64 bash build.sh
cp 'build/MacOS Duo.app/Contents/MacOS/MacOSDuo' build/release/MacOSDuo-arm64
DUO_ARCH=x86_64 bash build.sh
cp 'build/MacOS Duo.app/Contents/MacOS/MacOSDuo' build/release/MacOSDuo-x86_64
lipo -create build/release/MacOSDuo-arm64 build/release/MacOSDuo-x86_64 -output 'build/MacOS Duo.app/Contents/MacOS/MacOSDuo'
codesign --force --sign - 'build/MacOS Duo.app'
codesign --verify --deep --strict 'build/MacOS Duo.app'
ditto --norsrc --noextattr --noqtn -c -k --keepParent 'build/MacOS Duo.app' build/release/MacOS-Duo-universal.zip
echo 'Release archive: build/release/MacOS-Duo-universal.zip'
