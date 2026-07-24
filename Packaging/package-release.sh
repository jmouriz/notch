#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/Notch.app"
CONTENTS="$APP_DIR/Contents"
STAGING="$BUILD_DIR/dmg-root"
VOLUME_NAME="Notch Installer"
RW_DMG="$BUILD_DIR/Notch-rw.dmg"
FINAL_DMG="$BUILD_DIR/Notch-0.1.0.dmg"
ICON_SOURCE="$ROOT/Sources/Notch/Resources/notch-icon-concept.png"
BACKGROUND_SOURCE="$ROOT/Packaging/dmg-background.png"
ICONSET="$BUILD_DIR/Notch.iconset"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/notch-clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/private/tmp/notch-swiftpm-cache}"

mkdir -p "$BUILD_DIR"
swift build -c release --package-path "$ROOT"

rm -rf "$APP_DIR" "$STAGING" "$ICONSET"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$STAGING/.background" "$ICONSET"

cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/.build/release/Notch" "$CONTENTS/MacOS/Notch"

if [[ -d "$ROOT/.build/release/Notch_Notch.bundle" ]]; then
    cp -R "$ROOT/.build/release/Notch_Notch.bundle" "$CONTENTS/Resources/"
    chmod +x "$CONTENTS/Resources/Notch_Notch.bundle/yt-dlp" 2>/dev/null || true
    chmod +x "$CONTENTS/Resources/Notch_Notch.bundle/lame" 2>/dev/null || true
fi

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/Notch.icns"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

cp -R "$APP_DIR" "$STAGING/Notch.app"
ln -s /Applications "$STAGING/Applications"
cp "$BACKGROUND_SOURCE" "$STAGING/.background/dmg-background.png"

rm -f "$RW_DMG" "$FINAL_DMG"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$RW_DMG"

MOUNT_POINT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" |
    awk '/Apple_HFS/ {sub(/^.*Apple_HFS[[:space:]]*/, ""); print; exit}')"

if [[ -z "$MOUNT_POINT" ]]; then
    echo "No se pudo determinar el punto de montaje del DMG." >&2
    exit 1
fi

chflags hidden "$MOUNT_POINT/.background" >/dev/null 2>&1 || true
if [[ -e "$MOUNT_POINT/.fseventsd" ]]; then
    chflags hidden "$MOUNT_POINT/.fseventsd" >/dev/null 2>&1 || true
fi
if command -v SetFile >/dev/null 2>&1; then
    SetFile -a V "$MOUNT_POINT/.background" >/dev/null 2>&1 || true
    if [[ -e "$MOUNT_POINT/.fseventsd" ]]; then
        SetFile -a V "$MOUNT_POINT/.fseventsd" >/dev/null 2>&1 || true
    fi
fi

MOUNTED_VOLUME_NAME="${MOUNT_POINT:t}"
osascript "$ROOT/Packaging/configure-dmg.applescript" "$MOUNTED_VOLUME_NAME"

cp "$CONTENTS/Resources/Notch.icns" "$MOUNT_POINT/.VolumeIcon.icns"
chflags hidden "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -a V "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -a C "$MOUNT_POINT"

rm -rf "$MOUNT_POINT/.fseventsd"
sync
hdiutil detach "$MOUNT_POINT"

hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG"

codesign --force --sign - "$FINAL_DMG"
hdiutil verify "$FINAL_DMG"

rm -f "$RW_DMG"
rm -rf "$STAGING" "$ICONSET"
rm -f "$BUILD_DIR/.DS_Store"

echo "$APP_DIR"
echo "$FINAL_DMG"
