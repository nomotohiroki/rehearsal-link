#!/bin/bash

# Configuration
APP_NAME="RehearsalLink"
BUNDLE_ID="com.example.rehearsallink"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
ICON_FILE="AppIcon.icns"

echo "🚀 Building $APP_NAME in release mode..."
swift build -c release --arch arm64 --arch x86_64

echo "📦 Creating App Bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "📑 Copying binary..."
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

echo "🖼 Copying icon..."
if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "⚠️ Warning: $ICON_FILE not found."
fi

echo "📝 Generating Info.plist..."
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>RehearsalLink uses speech recognition to transcribe your rehearsal recordings into text.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>RehearsalLink requires microphone access for audio analysis and speech recognition.</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ $APP_BUNDLE created successfully."
