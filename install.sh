#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="TakeBreak"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="is.pjh.take-break.plist"

# Build release version
echo "Building release..."
"$SCRIPT_DIR/build.sh"

# Install app
echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    # Stop running instance first
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

# Install LaunchAgent
echo "Installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENT_DIR"
cat > "$LAUNCH_AGENT_DIR/$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>is.pjh.take-break</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/break-reminder.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/break-reminder.err</string>
</dict>
</plist>
EOF

# Load the agent
echo "Loading LaunchAgent..."
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_DIR/$PLIST_NAME"

echo ""
echo "Done! Take Break is now running and will start automatically on login."
echo "  App: $INSTALL_DIR/$APP_NAME.app"
echo "  Agent: $LAUNCH_AGENT_DIR/$PLIST_NAME"
echo "  Logs: /tmp/break-reminder.log"
echo ""
echo "To uninstall:"
echo "  launchctl bootout gui/$(id -u) $LAUNCH_AGENT_DIR/$PLIST_NAME"
echo "  rm -rf $INSTALL_DIR/$APP_NAME.app"
echo "  rm $LAUNCH_AGENT_DIR/$PLIST_NAME"
