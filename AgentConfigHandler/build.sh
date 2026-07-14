#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

APP_NAME="AgentConfigHandler"
APP_BUNDLE="${HOME}/Applications/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Clean previous build
rm -rf "$APP_BUNDLE"

# Create app bundle structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy Info.plist
cp Info.plist "$CONTENTS/"

# Copy app icon
if [ -f "${APP_NAME}.icns" ]; then
  cp "${APP_NAME}.icns" "$RESOURCES/"
fi

# Compile Swift executable
swiftc -o "$MACOS/$APP_NAME" main.swift

# Make executable
chmod +x "$MACOS/$APP_NAME"

# Code sign with stable ad-hoc identity (prevents permission re-prompts)
codesign --force --deep --options runtime --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
echo "URL scheme agent-config:// is now registered"
echo "Test with: open 'agent-config://https://example.com/rule.md'"
