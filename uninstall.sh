#!/bin/bash
#
# Uninstall macOS hardening watchdog and restore directory permissions
# Does NOT restore purged data (that's gone)
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Do not run with sudo. Run as: bash uninstall.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}Uninstalling macOS hardening watchdog...${NC}"

PLIST="$HOME/Library/LaunchAgents/com.macos-hardening.watchdog.plist"

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null
    rm -f "$PLIST"
    echo -e "  ${GREEN}REMOVED${NC} LaunchAgent"
fi

if [ -d "$HOME/.macos-hardening" ]; then
    rm -rf "$HOME/.macos-hardening"
    echo -e "  ${GREEN}REMOVED${NC} ~/.macos-hardening"
fi

echo ""
echo -e "${YELLOW}Restoring directory permissions...${NC}"

restore() {
    local dir="$1"
    if [ -d "$dir" ]; then
        chmod 755 "$dir" 2>/dev/null
        echo -e "  ${GREEN}RESTORED${NC} $dir"
    fi
}

restore "$HOME/Library/Biome/compute"
restore "$HOME/Library/Biome/databases"
restore "$HOME/Library/Biome/sync"
restore "$HOME/Library/Biome/sets"
restore "$HOME/Library/Biome/streams/restricted"
restore "$HOME/Library/IntelligencePlatform"
restore "$HOME/Library/Suggestions"
restore "$HOME/Library/DuetExpertCenter"
restore "$HOME/Library/Trial/Treatments"
restore "$HOME/Library/Trial/v7"
restore "$HOME/Library/Trial/NamespaceDescriptors"
restore "$HOME/Library/PersonalizationPortrait"
restore "$HOME/Library/Containers/com.apple.mediaanalysisd"
restore "$HOME/Library/Containers/com.apple.photoanalysisd"
restore "$HOME/Library/Containers/com.apple.geod"
restore "$HOME/Library/Group Containers/group.com.apple.UserNotifications"
restore "$HOME/Library/Group Containers/group.com.apple.chronod"
restore "$HOME/Library/Group Containers/group.com.apple.CoreSpeech"
restore "$HOME/Library/Group Containers/group.com.apple.siri.remembers"
restore "$HOME/Library/Group Containers/group.com.apple.siri.userfeedbacklearning"
restore "$HOME/Library/Group Containers/group.com.apple.replayd"
restore "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/rawSessions"
restore "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/session"
restore "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/feedback"
restore "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/EngagedCompletions"
restore "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/local"
restore "$HOME/Library/AppleMediaServices/Engagement"
restore "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledge/index.V2/DocumentProcessing"
restore "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledge/index.V2/KG"
restore "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledge/index.V2/updates"
restore "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledgeEvents/index.V2/embedding_cache"
restore "$HOME/Library/Metadata/CoreSpotlight/Priority"
restore "$HOME/Library/Metadata/CoreSpotlight/PasteboardHistory"
restore "$HOME/Library/Metadata/CoreSpotlight/PipelineCompletenessReporting"
restore "$HOME/Library/Group Containers/group.com.apple.screencapture/ScreenRecordings"
restore "$HOME/Library/Application Support/com.apple.replayd"
restore "$HOME/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel"
restore "$HOME/Library/Application Support/Google/Chrome/optimization_guide_model_store"
restore "$HOME/Library/Application Support/Google/Chrome/screen_ai"
restore "$HOME/Library/Application Support/Google/Chrome/SODA"
restore "$HOME/Library/Application Support/Google/Chrome/SODALanguagePacks"
restore "$HOME/Library/Application Support/Google/Chrome/WasmTtsEngine"
restore "$HOME/Library/Application Support/Google/Chrome/OnDeviceHeadSuggestModel"
restore "$HOME/Library/Application Support/Google/Chrome/OptimizationHints"

echo ""
echo -e "${YELLOW}Re-enabling services...${NC}"

USER_ID=$(id -u)
for svc in com.apple.mediaanalysisd com.apple.aned com.apple.triald com.apple.parsecd; do
    launchctl enable "user/$USER_ID/$svc" 2>/dev/null
    echo -e "  ${GREEN}ENABLED${NC} $svc"
done

echo ""
echo -e "${YELLOW}NOTE: System-level service overrides require sudo to restore:${NC}"
echo "  sudo launchctl enable system/com.apple.mediaanalysisd"
echo "  sudo launchctl enable system/com.apple.aned"
echo "  sudo launchctl enable system/com.apple.triald"
echo "  sudo launchctl enable system/com.apple.parsecd"
echo ""
echo -e "${YELLOW}NOTE: /etc/hosts blocks were NOT removed.${NC}"
echo "To remove them manually, edit /etc/hosts and delete the"
echo "lines under '# macOS-hardening telemetry blocks'"
echo ""
echo -e "${YELLOW}NOTE: The following settings were changed by nuke.sh and are NOT auto-restored:${NC}"
echo "  - Spotlight categories (restricted to apps/files/folders)"
echo "  - Siri Suggestions in Spotlight (disabled)"
echo "  - Siri (disabled)"
echo "  - Crash Reporter dialogs (disabled)"
echo ""
echo "To restore them manually:"
echo "  defaults delete com.apple.Spotlight orderedItems"
echo "  defaults delete com.apple.lookup.shared LookupSuggestionsDisabled"
echo "  defaults write com.apple.assistant.support 'Assistant Enabled' -bool true"
echo "  defaults delete com.apple.CrashReporter DialogType"
echo ""
echo -e "${YELLOW}NOTE: Purged data cannot be restored. Apple will rebuild${NC}"
echo -e "${YELLOW}it over time once directories are unlocked.${NC}"
