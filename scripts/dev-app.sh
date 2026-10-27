#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$APP_DIR/.swiftpm-modulecache" "$APP_DIR/.clang-cache"

export SWIFTPM_MODULECACHE_OVERRIDE="$APP_DIR/.swiftpm-modulecache"
export CLANG_MODULE_CACHE_PATH="$APP_DIR/.clang-cache"

RETYPO_BUILD_CONFIGURATION="${RETYPO_BUILD_CONFIGURATION:-debug}"
if [[ "$RETYPO_BUILD_CONFIGURATION" != "debug" && "$RETYPO_BUILD_CONFIGURATION" != "release" ]]; then
  echo "Invalid RETYPO_BUILD_CONFIGURATION '$RETYPO_BUILD_CONFIGURATION'; expected 'debug' or 'release'." >&2
  exit 2
fi
RETYPO_INSTALL_APP="${RETYPO_INSTALL_APP:-0}"
if [[ "$RETYPO_INSTALL_APP" != "0" && "$RETYPO_INSTALL_APP" != "1" ]]; then
  echo "Invalid RETYPO_INSTALL_APP '$RETYPO_INSTALL_APP'; expected '0' or '1'." >&2
  exit 2
fi

# Quit this build and the pre-rename Retypo Air build: both register the same
# global shortcut, and only one of them can hold it.
for app_id in app.retypo.dev app.retypoair.dev; do
  osascript -e "if application id \"$app_id\" is running then tell application id \"$app_id\" to quit" >/dev/null 2>&1 || true
done
pkill -f '/Retypo($| )' >/dev/null 2>&1 || true
pkill -f '/RetypoAir($| )' >/dev/null 2>&1 || true
pkill -f 'swift run.*Retypo' >/dev/null 2>&1 || true

cd "$APP_DIR"
swift build -c "$RETYPO_BUILD_CONFIGURATION"

BIN_DIR="$(swift build -c "$RETYPO_BUILD_CONFIGURATION" --show-bin-path)"
APP_BUNDLE="$APP_DIR/build-dev/Retypo-dev.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Retypo</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>app.retypo.dev</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Retypo</string>
  <key>CFBundleDisplayName</key>
  <string>Retypo Dev</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.0.1-dev</string>
  <key>CFBundleVersion</key>
  <string>0.0.1-dev</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Retypo can import selected text by briefly sending Copy to the focused app.</string>
</dict>
</plist>
PLIST

ICON_MASTER="$APP_DIR/assets/AppIcon.png"
if [[ -f "$ICON_MASTER" ]]; then
  ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"
  for spec in \
      "16 16 icon_16x16.png" \
      "32 32 icon_16x16@2x.png" \
      "32 32 icon_32x32.png" \
      "64 64 icon_32x32@2x.png" \
      "128 128 icon_128x128.png" \
      "256 256 icon_128x128@2x.png" \
      "256 256 icon_256x256.png" \
      "512 512 icon_256x256@2x.png" \
      "512 512 icon_512x512.png" \
      "1024 1024 icon_512x512@2x.png"; do
    read -r size _ name <<<"$spec"
    sips -z "$size" "$size" "$ICON_MASTER" --out "$ICONSET_DIR/$name" >/dev/null
  done
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
  rm -rf "$(dirname "$ICONSET_DIR")"
fi

cp "$BIN_DIR/Retypo" "$MACOS_DIR/Retypo"
chmod +x "$MACOS_DIR/Retypo"

for bundle_path in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle_path" ]] || continue
  cp -R "$bundle_path" "$RESOURCES_DIR/"
done

RETYPO_SIGNING_IDENTITY="${RETYPO_CODESIGN_IDENTITY:-}"
if [[ -z "$RETYPO_SIGNING_IDENTITY" ]]; then
  RETYPO_SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk -F '"' '/Apple Development:/{print $2; exit}')"
fi

if [[ -n "$RETYPO_SIGNING_IDENTITY" ]]; then
  codesign --force --deep --timestamp=none --sign "$RETYPO_SIGNING_IDENTITY" "$APP_BUNDLE"
  echo "Signed: $RETYPO_SIGNING_IDENTITY"
else
  codesign --force --deep --timestamp=none --sign - "$APP_BUNDLE"
  echo "Warning: no Apple Development identity found; Accessibility permission may reset after rebuilds." >&2
fi
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Built ($RETYPO_BUILD_CONFIGURATION): $APP_BUNDLE"
RETYPO_APP_TO_OPEN="$APP_BUNDLE"
if [[ "$RETYPO_INSTALL_APP" == "1" ]]; then
  RETYPO_INSTALLED_APP="/Applications/Retypo-dev.app"
  ditto "$APP_BUNDLE" "$RETYPO_INSTALLED_APP"
  codesign --verify --deep --strict "$RETYPO_INSTALLED_APP"
  RETYPO_APP_TO_OPEN="$RETYPO_INSTALLED_APP"
  echo "Installed: $RETYPO_INSTALLED_APP"
  if [[ -d "/Applications/RetypoAir-dev.app" ]]; then
    echo "Note: the pre-rename /Applications/RetypoAir-dev.app is still installed; delete it once Retypo works." >&2
  fi
fi
echo "Open $RETYPO_APP_TO_OPEN, then grant Accessibility permission to 'Retypo Dev' if prompted."

if [[ "${RETYPO_OPEN_APP:-1}" != "0" ]]; then
  open -n "$RETYPO_APP_TO_OPEN" --args "$@"
fi
