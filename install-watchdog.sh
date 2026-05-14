#!/bin/bash
#
# Install the macOS hardening watchdog as a LaunchAgent
# Runs every 30 minutes + on login
#

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Do not run with sudo. Run as: bash install-watchdog.sh${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHDOG_SRC="$SCRIPT_DIR/watchdog.sh"
WATCHDOG_DST="$HOME/.macos-hardening/watchdog.sh"
PLIST_DST="$HOME/Library/LaunchAgents/com.macos-hardening.watchdog.plist"

if [ ! -f "$WATCHDOG_SRC" ]; then
    echo -e "${RED}watchdog.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

mkdir -p "$HOME/.macos-hardening"
mkdir -p "$HOME/Library/LaunchAgents"
cp "$WATCHDOG_SRC" "$WATCHDOG_DST"
chmod +x "$WATCHDOG_DST"

cat > "$PLIST_DST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macos-hardening.watchdog</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WATCHDOG_DST}</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.macos-hardening/watchdog-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.macos-hardening/watchdog-stderr.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_DST" 2>/dev/null
launchctl load "$PLIST_DST"

echo -e "${GREEN}Watchdog installed and running.${NC}"
echo ""
echo "  Script:  $WATCHDOG_DST"
echo "  Agent:   $PLIST_DST"
echo "  Log:     $HOME/.macos-hardening/watchdog.log"
echo "  Schedule: every 30 minutes + on login"
echo ""
echo "Check the log anytime:"
echo "  cat ~/.macos-hardening/watchdog.log"
