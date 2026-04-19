#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SoBreak"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

# Parse flags
DEBUG_FLAG=""
for arg in "$@"; do
    case "$arg" in
        --debug) DEBUG_FLAG="-D DEBUG" ;;
    esac
done

echo "Building $APP_NAME..."
if [ -n "$DEBUG_FLAG" ]; then
    echo "  (debug mode — short timers)"
fi

# Clean and create bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

# Compile
swiftc \
    $DEBUG_FLAG \
    -O \
    -framework Cocoa \
    -framework SwiftUI \
    -framework IOKit \
    -o "$MACOS/$APP_NAME" \
    "$SCRIPT_DIR/Sources/SoBreak.swift"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS/Info.plist"

# Copy resources (doge images)
RESOURCES="$CONTENTS/Resources"
mkdir -p "$RESOURCES"
cp -R "$SCRIPT_DIR/Resources/images" "$RESOURCES/"

echo "Built: $APP_BUNDLE"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To install: ./install.sh"
