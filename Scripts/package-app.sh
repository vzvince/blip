#!/bin/sh
set -e
# AtollExtensionKit uses Git-LFS for media assets; the upstream LFS server is
# flaky, so skip the smudge filter (we don't link the media at build time).
export GIT_LFS_SKIP_SMUDGE=1
APP="Blip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swift build -c release --product BlipApp
BINPATH="$(swift build -c release --product BlipApp --show-bin-path 2>/dev/null)" || BINPATH="$(swift build --product BlipApp --show-bin-path 2>/dev/null)"
cp "$BINPATH/BlipApp" "$APP/Contents/MacOS/BlipApp"
cp Resources/Info.plist "$APP/Contents/Info.plist"
echo "built $APP"
