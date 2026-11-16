#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
swift build -c release --package-path "$PROJECT_DIR"
BIN_DIR="$(swift build -c release --package-path "$PROJECT_DIR" --show-bin-path)"
APP_DIR="${NKURGU_APP_DIR:-$PROJECT_DIR/Dist/kurgucu.app}"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/NKurgu" "$APP_DIR/Contents/MacOS/NKurgu"
# Copy only declared application resources; never bundle projects accidentally saved here.
RESOURCE_BUNDLE="$APP_DIR/Contents/Resources/NKurgu_NKurguApp.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    rm -rf "$RESOURCE_BUNDLE"
fi
mkdir -p "$RESOURCE_BUNDLE"
for name in Logo-Light.png Logo-Dark.png Scene-Landscape.png Scene-Portrait.png Scene-Square.png Scene-Social.png Sticker-Arrow.png Sticker-Spark.png Sticker-Heart.png NOTICE.txt OpenCut-LICENSE.txt; do
    cp "$PROJECT_DIR/Sources/NKurguApp/Resources/$name" "$RESOURCE_BUNDLE/$name"
done
if [[ -f "$PROJECT_DIR/Brand/AppIcon.icns" ]]; then
    cp "$PROJECT_DIR/Brand/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NKurgu</string>
<key>CFBundleIdentifier</key><string>com.nkurgu.editor</string>
<key>CFBundleName</key><string>kurgucu</string>
<key>CFBundleDisplayName</key><string>kurgucu</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.12.0</string>
<key>CFBundleVersion</key><string>18</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHighResolutionCapable</key><true/>
<key>UTExportedTypeDeclarations</key><array><dict>
<key>UTTypeIdentifier</key><string>com.nkurgu.project</string>
<key>UTTypeDescription</key><string>kurgucu projesi</string>
<key>UTTypeConformsTo</key><array><string>com.apple.package</string></array>
<key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>nkurgu</string></array></dict>
</dict></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP_DIR"
printf '%s\n' "$APP_DIR"
