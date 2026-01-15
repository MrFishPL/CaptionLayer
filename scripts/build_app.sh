#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-CaptionLayer}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-transcribtion}"
BUNDLE_ID="${BUNDLE_ID:-com.CaptionLayer.app}"

DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

ICONSET_DIR="$ROOT_DIR/.tmp/AppIcon.iconset"
ICON_PATH="$ROOT_DIR/Packaging/AppIcon.icns"
PLIST_TEMPLATE="$ROOT_DIR/Packaging/Info.plist.template"
PLIST_PATH="$CONTENTS_DIR/Info.plist"

mkdir -p "$DIST_DIR"

echo "Building release binary..."
(cd "$ROOT_DIR" && swift build -c release)

echo "Generating app icon..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

swift "$ROOT_DIR/scripts/render_symbol.swift" "$ICONSET_DIR/icon_512x512@2x.png" 1024
sips -z 16 16 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null

mkdir -p "$ROOT_DIR/Packaging"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"

APP_NAME="$APP_NAME" EXECUTABLE_NAME="$EXECUTABLE_NAME" BUNDLE_ID="$BUNDLE_ID" \
PLIST_TEMPLATE="$PLIST_TEMPLATE" PLIST_PATH="$PLIST_PATH" \
python3 - <<'PY'
import os
from pathlib import Path

template = Path(os.environ["PLIST_TEMPLATE"]).read_text()
template = template.replace("__APP_NAME__", os.environ["APP_NAME"])
template = template.replace("__EXECUTABLE__", os.environ["EXECUTABLE_NAME"])
template = template.replace("__BUNDLE_ID__", os.environ["BUNDLE_ID"])
Path(os.environ["PLIST_PATH"]).write_text(template)
PY

echo "App bundle ready: $APP_DIR"
