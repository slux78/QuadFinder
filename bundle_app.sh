#!/bin/bash
set -e

APP_NAME="QuadFinder"
OUTPUT_DIR="."
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
ICON_Source="AppIcon.png"
ICON_SET="AppIcon.iconset"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating App Bundle..."
if [ -d "$APP_BUNDLE" ]; then
    rm -rf "$APP_BUNDLE"
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>0.11</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

if [ -f "$ICON_Source" ]; then
    echo "Generating Icons..."
    mkdir -p "$ICON_SET"
    
    # Ensure source is treated as valid, convert to temp png if needed or just enforcement format in loop
    # We will use -s format png for all outputs
    
    sips -s format png -z 16 16     "$ICON_Source" --out "${ICON_SET}/icon_16x16.png"
    sips -s format png -z 32 32     "$ICON_Source" --out "${ICON_SET}/icon_16x16@2x.png"
    sips -s format png -z 32 32     "$ICON_Source" --out "${ICON_SET}/icon_32x32.png"
    sips -s format png -z 64 64     "$ICON_Source" --out "${ICON_SET}/icon_32x32@2x.png"
    sips -s format png -z 128 128   "$ICON_Source" --out "${ICON_SET}/icon_128x128.png"
    sips -s format png -z 256 256   "$ICON_Source" --out "${ICON_SET}/icon_128x128@2x.png"
    sips -s format png -z 256 256   "$ICON_Source" --out "${ICON_SET}/icon_256x256.png"
    sips -s format png -z 512 512   "$ICON_Source" --out "${ICON_SET}/icon_256x256@2x.png"
    sips -s format png -z 512 512   "$ICON_Source" --out "${ICON_SET}/icon_512x512.png"
    sips -s format png -z 1024 1024 "$ICON_Source" --out "${ICON_SET}/icon_512x512@2x.png"
    
    echo "Converting iconset to icns..."
    iconutil -c icns "$ICON_SET"
    mv AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
    rm -rf "$ICON_SET"
else
    echo "Warning: No AppIcon.png found. skipping icon generation."
fi

echo "Copying Binary..."
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Ad-hoc Signing to prevent "Application is damaged" on local execution
echo "Ad-hoc Signing..."
xattr -cr "${APP_BUNDLE}"
codesign -s - --deep --force --options runtime "${APP_BUNDLE}"

echo "Done! App Bundle created at ${APP_BUNDLE}"
