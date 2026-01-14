#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-CaptionLayer}"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
ICON_PATH="$ROOT_DIR/Packaging/AppIcon.icns"
BG_PATH="$ROOT_DIR/Packaging/dmg-background.png"

echo "Building app..."
"$ROOT_DIR/scripts/build_app.sh"

STAGING_DIR="$ROOT_DIR/.tmp/dmg"
TMP_DMG="$DIST_DIR/$APP_NAME-tmp.dmg"
FINAL_DMG="$DIST_DIR/$APP_NAME.dmg"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TMP_DMG" >/dev/null

ATTACH_PLIST="$ROOT_DIR/.tmp/attach.plist"
hdiutil attach -readwrite -noverify -noautoopen -plist "$TMP_DMG" > "$ATTACH_PLIST"

MOUNT_DIR="$(ATTACH_PLIST="$ATTACH_PLIST" python3 - <<'PY'
import os
import plistlib

plist_path = os.environ["ATTACH_PLIST"]
with open(plist_path, "rb") as handle:
    plist = plistlib.load(handle)
for entity in plist.get("system-entities", []):
    mount_point = entity.get("mount-point")
    if mount_point:
        print(mount_point)
        break
PY
)"

if [[ -n "$MOUNT_DIR" && -f "$ICON_PATH" ]]; then
    mkdir -p "$(dirname "$BG_PATH")"
    swift "$ROOT_DIR/scripts/render_dmg_background.swift" "$BG_PATH" "$APP_NAME"

    mkdir -p "$MOUNT_DIR/.background"
    cp "$BG_PATH" "$MOUNT_DIR/.background/background.png"

    cp "$ICON_PATH" "$MOUNT_DIR/.VolumeIcon.icns"
    if command -v SetFile >/dev/null 2>&1; then
        SetFile -a C "$MOUNT_DIR"
        SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
    else
        echo "Warning: SetFile not found; DMG volume icon not applied."
    fi

    osascript <<EOF
set dmgPath to "$MOUNT_DIR"
set dmgName to do shell script "basename " & quoted form of dmgPath
tell application "Finder"
    tell disk dmgName
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 920, 660}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {200, 280}
        set position of item "Applications" of container window to {520, 280}
        delay 1
        update without registering applications
        close
    end tell
end tell
EOF
fi

hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -ov -o "$FINAL_DMG" >/dev/null
rm -f "$TMP_DMG"

echo "Installer DMG ready: $FINAL_DMG"
