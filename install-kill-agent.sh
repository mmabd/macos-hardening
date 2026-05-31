#!/bin/bash
#
# Install Persistent Kill Agent (macOS Sequoia+ fix)
# On Sequoia+, launchctl disable doesn't survive SIP re-enable.
# This installs a LaunchAgent + LaunchDaemon that kill tracking processes every 60 seconds.
#
# Usage: bash install-kill-agent.sh
# Requires: sudo (for the system-level daemon)
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Do not run with sudo. Run as: bash install-kill-agent.sh${NC}"
    echo "The script will ask for your password when needed."
    exit 1
fi

echo -e "${RED}"
echo "======================================"
echo "  Kill Agent Installer (Sequoia+ fix)"
echo "======================================"
echo -e "${NC}"
echo "On macOS Sequoia+, re-enabling SIP resets the launchd disabled"
echo "database, allowing tracking processes to respawn on every reboot."
echo ""
echo "This installs two persistent agents:"
echo "  1. LaunchAgent — kills user-level tracking processes every 60s"
echo "  2. LaunchDaemon (root) — kills system-level processes every 60s"
echo ""

USER_SCRIPT="$HOME/.macos-hardening/kill-telemetry.sh"
USER_PLIST="$HOME/Library/LaunchAgents/com.maisara.kill-telemetry.plist"
SYSTEM_PLIST="/Library/LaunchDaemons/com.maisara.kill-telemetry-system.plist"

mkdir -p "$HOME/.macos-hardening"
mkdir -p "$HOME/Library/LaunchAgents"

# Write user kill script
cat > "$USER_SCRIPT" << 'SCRIPT'
#!/bin/bash
killall -9 \
    BiomeAgent \
    BiomeSELFIngestor \
    biomed \
    assistantd \
    siriinferenced \
    sirittsd \
    siriactionsd \
    siriknowledged \
    SiriAUSP \
    assistant_cdmd \
    photoanalysisd \
    weatherd \
    remindd \
    tipsd \
    inputanalyticsd \
    2>/dev/null
SCRIPT
chmod +x "$USER_SCRIPT"
echo -e "  ${GREEN}WRITTEN${NC} $USER_SCRIPT"

# Write user LaunchAgent plist
cat > "$USER_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.maisara.kill-telemetry</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$USER_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
PLIST
echo -e "  ${GREEN}WRITTEN${NC} $USER_PLIST"

# Load user agent
launchctl unload "$USER_PLIST" 2>/dev/null
launchctl load "$USER_PLIST"
echo -e "  ${GREEN}LOADED${NC}  com.maisara.kill-telemetry (user agent)"

# Write system daemon plist
echo ""
echo "Installing system daemon (requires sudo)..."
sudo tee "$SYSTEM_PLIST" > /dev/null << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.maisara.kill-telemetry-system</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>killall -9 biomed triald_system symptomsd symptomsd-diag analyticsd audioanalyticsd wifianalyticsd ecosystemanalyticsd 2>/dev/null</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
PLIST

sudo launchctl unload "$SYSTEM_PLIST" 2>/dev/null
sudo launchctl load "$SYSTEM_PLIST"
echo -e "  ${GREEN}LOADED${NC}  com.maisara.kill-telemetry-system (system daemon)"

echo ""
echo -e "${GREEN}Kill agents installed.${NC}"
echo ""
echo "Both agents run at login and every 60 seconds."
echo "These persist across reboots regardless of SIP state."
echo ""
echo "To verify:"
echo "  launchctl list | grep kill-telemetry"
echo "  sudo launchctl list | grep kill-telemetry"
