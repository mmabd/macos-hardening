#!/bin/bash
#
# macOS Tracking Data Nuke Script
# Purges all Apple surveillance/tracking data and locks directories
# Run once, then install the watchdog for ongoing protection
#
# Usage: sudo bash nuke.sh
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run with sudo: sudo bash nuke.sh${NC}"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(dscl . -read /Users/"$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
if [ -z "$REAL_HOME" ]; then
    REAL_HOME="/Users/$REAL_USER"
fi
USER_ID=$(id -u "$REAL_USER")

echo -e "${RED}"
echo "======================================"
echo "  macOS Tracking Data Nuke"
echo "======================================"
echo -e "${NC}"
echo "User: $REAL_USER (UID $USER_ID)"
echo "Home: $REAL_HOME"
echo ""

TOTAL_FREED=0

purge_and_lock() {
    local dir="$1"
    local label="$2"

    if [ -d "$dir" ]; then
        local size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
        find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
        chmod 000 "$dir" 2>/dev/null
        chown "$REAL_USER" "$dir" 2>/dev/null
        TOTAL_FREED=$((TOTAL_FREED + size))
        echo -e "  ${GREEN}NUKED${NC} $label (${size} KB)"
    else
        echo -e "  ${YELLOW}SKIP${NC} $label (not found)"
    fi
}

delete_file() {
    local file="$1"
    local label="$2"

    if [ -f "$file" ]; then
        rm -f "$file" 2>/dev/null
        echo -e "  ${GREEN}DELETED${NC} $label"
    fi
}

# ============================================================
echo -e "${YELLOW}[1/9] Killing tracking processes...${NC}"
# ============================================================

for proc in mediaanalysisd aned triald triald_system parsecd mdworker mdbulkimport; do
    if pkill -9 "$proc" 2>/dev/null; then
        echo -e "  ${GREEN}KILLED${NC} $proc"
    fi
done

# ============================================================
echo -e "\n${YELLOW}[2/9] Disabling tracking services...${NC}"
# ============================================================

for svc in com.apple.mediaanalysisd com.apple.aned com.apple.triald com.apple.parsecd; do
    launchctl disable "system/$svc" 2>/dev/null || true
    launchctl disable "user/$USER_ID/$svc" 2>/dev/null || true
    echo -e "  ${GREEN}DISABLED${NC} $svc"
done

# ============================================================
echo -e "\n${YELLOW}[3/9] Nuking Apple tracking streams...${NC}"
# ============================================================

purge_and_lock "$REAL_HOME/Library/Biome/compute" "Biome/compute"
purge_and_lock "$REAL_HOME/Library/Biome/databases" "Biome/databases"
purge_and_lock "$REAL_HOME/Library/Biome/sync" "Biome/sync"
purge_and_lock "$REAL_HOME/Library/Biome/sets" "Biome/sets"
purge_and_lock "$REAL_HOME/Library/Biome/streams/restricted" "Biome/streams/restricted"
purge_and_lock "$REAL_HOME/Library/IntelligencePlatform" "IntelligencePlatform"
purge_and_lock "$REAL_HOME/Library/Suggestions" "Suggestions"
purge_and_lock "$REAL_HOME/Library/DuetExpertCenter" "DuetExpertCenter"

# ============================================================
echo -e "\n${YELLOW}[4/9] Nuking Apple experiments (Trial)...${NC}"
# ============================================================

purge_and_lock "$REAL_HOME/Library/Trial/Treatments" "Trial/Treatments"
purge_and_lock "$REAL_HOME/Library/Trial/v7" "Trial/v7"
purge_and_lock "$REAL_HOME/Library/Trial/NamespaceDescriptors" "Trial/NamespaceDescriptors"

# ============================================================
echo -e "\n${YELLOW}[5/9] Nuking PegasusConfiguration (Spotlight/Siri telemetry)...${NC}"
# ============================================================

PEGASUS="$REAL_HOME/Library/Group Containers/group.com.apple.PegasusConfiguration"
purge_and_lock "$PEGASUS/rawSessions" "Pegasus/rawSessions"
purge_and_lock "$PEGASUS/session" "Pegasus/session"
purge_and_lock "$PEGASUS/feedback" "Pegasus/feedback"
purge_and_lock "$PEGASUS/EngagedCompletions" "Pegasus/EngagedCompletions"
purge_and_lock "$PEGASUS/local" "Pegasus/local"
delete_file "$REAL_HOME/Library/Preferences/com.apple.parsecd.plist" "parsecd preferences"
delete_file "$REAL_HOME/Library/Preferences/replayd.plist" "replayd preferences"
delete_file "$REAL_HOME/Library/Preferences/com.apple.replayd.plist" "replayd preferences (alt)"

# ============================================================
echo -e "\n${YELLOW}[6/9] Nuking PersonalizationPortrait + surveillance containers...${NC}"
# ============================================================

purge_and_lock "$REAL_HOME/Library/PersonalizationPortrait" "PersonalizationPortrait (user dossier)"
purge_and_lock "$REAL_HOME/Library/Containers/com.apple.mediaanalysisd" "mediaanalysisd container"
purge_and_lock "$REAL_HOME/Library/Containers/com.apple.photoanalysisd" "photoanalysisd container"
purge_and_lock "$REAL_HOME/Library/Containers/com.apple.geod" "geod (location data)"
purge_and_lock "$REAL_HOME/Library/Group Containers/group.com.apple.UserNotifications" "UserNotifications"
purge_and_lock "$REAL_HOME/Library/Group Containers/group.com.apple.chronod" "chronod (time tracking)"
purge_and_lock "$REAL_HOME/Library/Group Containers/group.com.apple.CoreSpeech" "CoreSpeech"
purge_and_lock "$REAL_HOME/Library/Group Containers/group.com.apple.siri.remembers" "siri.remembers"
purge_and_lock "$REAL_HOME/Library/Group Containers/group.com.apple.siri.userfeedbacklearning" "Siri feedback learning"
purge_and_lock "$REAL_HOME/Library/Group Containers/group.com.apple.replayd" "replayd (screen capture tracking)"
purge_and_lock "$REAL_HOME/Library/Group Containers/group.com.apple.screencapture/ScreenRecordings" "ScreenRecordings"
purge_and_lock "$REAL_HOME/Library/Application Support/com.apple.replayd" "replayd app support"
purge_and_lock "$REAL_HOME/Library/AppleMediaServices/Engagement" "AppleMediaServices engagement"

# ============================================================
echo -e "\n${YELLOW}[7/9] Nuking Spotlight ML pipelines...${NC}"
# ============================================================

SPOTLIGHT="$REAL_HOME/Library/Metadata/CoreSpotlight"
purge_and_lock "$SPOTLIGHT/SpotlightKnowledge/index.V2/DocumentProcessing" "Spotlight/DocumentProcessing"
purge_and_lock "$SPOTLIGHT/SpotlightKnowledge/index.V2/KG" "Spotlight/KnowledgeGraph"
purge_and_lock "$SPOTLIGHT/SpotlightKnowledge/index.V2/updates" "Spotlight/updates"
purge_and_lock "$SPOTLIGHT/SpotlightKnowledgeEvents/index.V2/embedding_cache" "Spotlight/embedding_cache"
purge_and_lock "$SPOTLIGHT/Priority" "Spotlight/Priority"
purge_and_lock "$SPOTLIGHT/PasteboardHistory" "Spotlight/PasteboardHistory"
purge_and_lock "$SPOTLIGHT/PipelineCompletenessReporting" "Spotlight/PipelineReporting"

delete_file "$SPOTLIGHT/com.apple.corespotlight.receiver.coreduet.plist" "Spotlight receiver: coreduet"
delete_file "$SPOTLIGHT/com.apple.corespotlight.receiver.suggestions.plist" "Spotlight receiver: suggestions"
delete_file "$SPOTLIGHT/com.apple.corespotlight.receiver.textunderstandingd.plist" "Spotlight receiver: textunderstandingd"
delete_file "$SPOTLIGHT/com.apple.corespotlight.receiver.photos.plist" "Spotlight receiver: photos"

# ============================================================
echo -e "\n${YELLOW}[8/9] Nuking Chrome AI models...${NC}"
# ============================================================

CHROME="$REAL_HOME/Library/Application Support/Google/Chrome"
purge_and_lock "$CHROME/OptGuideOnDeviceModel" "Chrome/Gemini Nano"
purge_and_lock "$CHROME/optimization_guide_model_store" "Chrome/ML model store"
purge_and_lock "$CHROME/screen_ai" "Chrome/screen_ai"
purge_and_lock "$CHROME/SODA" "Chrome/SODA (speech)"
purge_and_lock "$CHROME/SODALanguagePacks" "Chrome/SODA languages"
purge_and_lock "$CHROME/WasmTtsEngine" "Chrome/TTS engine"
purge_and_lock "$CHROME/OnDeviceHeadSuggestModel" "Chrome/autocomplete model"
purge_and_lock "$CHROME/OptimizationHints" "Chrome/optimization hints"

# ============================================================
echo -e "\n${YELLOW}[9/9] Hardening system settings...${NC}"
# ============================================================

sudo -u "$REAL_USER" defaults write com.apple.Spotlight orderedItems -array \
    '{"enabled" = 1; "name" = "APPLICATIONS";}' \
    '{"enabled" = 1; "name" = "MENU_EXPRESSION";}' \
    '{"enabled" = 1; "name" = "SYSTEM_PREFS";}' \
    '{"enabled" = 1; "name" = "DIRECTORIES";}' \
    '{"enabled" = 1; "name" = "PDF";}' \
    '{"enabled" = 1; "name" = "DOCUMENTS";}' \
    '{"enabled" = 0; "name" = "MESSAGES";}' \
    '{"enabled" = 0; "name" = "CONTACT";}' \
    '{"enabled" = 0; "name" = "EVENT_TODO";}' \
    '{"enabled" = 0; "name" = "IMAGES";}' \
    '{"enabled" = 0; "name" = "BOOKMARKS";}' \
    '{"enabled" = 0; "name" = "MUSIC";}' \
    '{"enabled" = 0; "name" = "MOVIES";}' \
    '{"enabled" = 0; "name" = "FONTS";}' \
    '{"enabled" = 0; "name" = "MENU_OTHER";}' \
    '{"enabled" = 0; "name" = "PRESENTATIONS";}' \
    '{"enabled" = 0; "name" = "SPREADSHEETS";}' \
    '{"enabled" = 0; "name" = "MENU_CONVERSION";}' \
    '{"enabled" = 0; "name" = "MENU_DEFINITION";}' \
    '{"enabled" = 0; "name" = "TIPS";}' \
    '{"enabled" = 0; "name" = "MENU_SPOTLIGHT_SUGGESTIONS";}'
echo -e "  ${GREEN}SET${NC} Spotlight restricted to apps/files/folders only"

sudo -u "$REAL_USER" defaults write com.apple.lookup.shared LookupSuggestionsDisabled -bool true
echo -e "  ${GREEN}SET${NC} Siri Suggestions in Spotlight disabled"

sudo -u "$REAL_USER" defaults write com.apple.assistant.support "Assistant Enabled" -bool false
echo -e "  ${GREEN}SET${NC} Siri disabled"

sudo -u "$REAL_USER" defaults write com.apple.CrashReporter DialogType -string "none"
echo -e "  ${GREEN}SET${NC} Crash reporter dialogs disabled"

# ============================================================
echo -e "\n${YELLOW}Blocking telemetry domains in /etc/hosts...${NC}"
# ============================================================

HOSTS_MARKER="# macOS-hardening telemetry blocks"
if ! grep -q "$HOSTS_MARKER" /etc/hosts 2>/dev/null; then
    cat >> /etc/hosts << 'EOF'

# macOS-hardening telemetry blocks
0.0.0.0 api.smoot.apple.com
0.0.0.0 api-glb-aeun1a.smoot.apple.com
0.0.0.0 api-glb-aeun1b.smoot.apple.com
0.0.0.0 cdn.smoot.apple.com
EOF
    echo -e "  ${GREEN}BLOCKED${NC} 4 Apple telemetry domains in /etc/hosts"
else
    echo -e "  ${YELLOW}SKIP${NC} hosts file already has telemetry blocks"
fi

# ============================================================
echo ""
echo -e "${RED}======================================"
echo "  NUKE COMPLETE"
echo "======================================${NC}"
echo ""
TOTAL_MB=$((TOTAL_FREED / 1024))
echo -e "Total data purged: ${GREEN}${TOTAL_MB} MB${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: bash install-watchdog.sh"
echo "  2. Reboot to fully kill SIP-protected daemons"
echo "  3. Check watchdog.log periodically to see what Apple tries to undo"
echo ""
echo -e "${YELLOW}NOTE: Cmd+Space file search still works.${NC}"
echo -e "${YELLOW}NOTE: Some daemons (aned, triald) run as root and SIP will${NC}"
echo -e "${YELLOW}resurrect them on reboot. The watchdog + hosts file blocks${NC}"
echo -e "${YELLOW}ensure they have nowhere to write and nowhere to send data.${NC}"
