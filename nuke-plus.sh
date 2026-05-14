#!/bin/bash
#
# macOS Tracking Data Nuke PLUS
# Extended hardening that goes beyond nuke.sh
# These options disable real features — read each section before running
#
# Usage: sudo bash nuke-plus.sh
# Prerequisite: Run nuke.sh first
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run with sudo: sudo bash nuke-plus.sh${NC}"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
    echo -e "${RED}ERROR: Cannot determine real user.${NC}"
    echo "Run with: sudo bash nuke-plus.sh"
    echo "Do NOT use 'su' or 'sudo su' before running this script."
    exit 1
fi

REAL_HOME=$(dscl . -read /Users/"$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
if [ -z "$REAL_HOME" ]; then
    REAL_HOME="/Users/$REAL_USER"
fi

USER_ID=$(id -u "$REAL_USER" 2>/dev/null)
if [ -z "$USER_ID" ]; then
    echo -e "${RED}ERROR: Cannot resolve UID for user '$REAL_USER'${NC}"
    exit 1
fi

echo -e "${RED}"
echo "======================================"
echo "  macOS Tracking Data Nuke PLUS"
echo "======================================"
echo -e "${NC}"
echo "User: $REAL_USER (UID $USER_ID)"
echo ""
echo -e "${YELLOW}This script disables real macOS features.${NC}"
echo -e "${YELLOW}Read each section and choose what to nuke.${NC}"
echo ""

TOTAL_FREED=0

purge_and_lock() {
    local dir="$1"
    local label="$2"

    if [ -d "$dir" ]; then
        local size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
        size=${size:-0}
        find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
        chmod 000 "$dir" 2>/dev/null
        chown "$REAL_USER" "$dir" 2>/dev/null
        TOTAL_FREED=$((TOTAL_FREED + size))
        echo -e "  ${GREEN}NUKED${NC} $label (${size} KB)"
    else
        echo -e "  ${YELLOW}SKIP${NC} $label (not found)"
    fi
}

# ============================================================
echo -e "${CYAN}[1] Knowledge Database (behavioral tracking)${NC}"
echo ""
echo "  Apple's central behavioral database. Logs every app open/close,"
echo "  every website, every media played, every notification interaction."
echo ""
echo -e "  ${YELLOW}BREAKS: Handoff between devices, Dock app suggestions,${NC}"
echo -e "  ${YELLOW}        proactive launch suggestions.${NC}"
echo ""
read -p "  Nuke Knowledge Database? [y/N] " CHOICE
if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    for proc in knowledge-agent ContextStoreAgent; do
        if pkill -9 -x "$proc" 2>/dev/null; then
            echo -e "  ${GREEN}KILLED${NC} $proc"
        fi
    done
    purge_and_lock "$REAL_HOME/Library/Application Support/Knowledge" "Knowledge (behavioral database)"
    for svc in com.apple.knowledge-agent com.apple.ContextStoreAgent; do
        launchctl disable "system/$svc" 2>/dev/null || true
        launchctl disable "user/$USER_ID/$svc" 2>/dev/null || true
    done
    echo -e "  ${GREEN}DISABLED${NC} knowledge-agent + ContextStoreAgent"
else
    echo -e "  ${YELLOW}SKIPPED${NC}"
fi

# ============================================================
echo ""
echo -e "${CYAN}[2] UsageTrackingAgent (Screen Time)${NC}"
echo ""
echo "  Tracks per-app and per-website usage time."
echo ""
echo -e "  ${YELLOW}BREAKS: Screen Time feature completely.${NC}"
echo ""
read -p "  Nuke UsageTrackingAgent? [y/N] " CHOICE
if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    if pkill -9 -x "UsageTrackingAgent" 2>/dev/null; then
        echo -e "  ${GREEN}KILLED${NC} UsageTrackingAgent"
    fi
    purge_and_lock "$REAL_HOME/Library/Containers/com.apple.UsageTrackingAgent" "UsageTrackingAgent (Screen Time)"
    launchctl disable "system/com.apple.UsageTrackingAgent" 2>/dev/null || true
    launchctl disable "user/$USER_ID/com.apple.UsageTrackingAgent" 2>/dev/null || true
    echo -e "  ${GREEN}DISABLED${NC} UsageTrackingAgent"
else
    echo -e "  ${YELLOW}SKIPPED${NC}"
fi

# ============================================================
echo ""
echo -e "${CYAN}[3] Siri daemons (still running despite Siri being disabled)${NC}"
echo ""
echo "  7 Siri processes still consuming RAM even though Siri is off:"
echo "  assistantd, assistant_cdmd, siriknowledged, siriinferenced,"
echo "  siriactionsd, sirittsd, siri.context.service"
echo ""
echo -e "  ${YELLOW}BREAKS: Siri stops working permanently until uninstalled.${NC}"
echo -e "  ${YELLOW}        If Siri is already disabled, this changes nothing.${NC}"
echo ""
read -p "  Nuke Siri daemons? [y/N] " CHOICE
if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    for proc in assistantd assistant_cdmd siriknowledged siriinferenced siriactionsd sirittsd; do
        if pkill -9 -x "$proc" 2>/dev/null; then
            echo -e "  ${GREEN}KILLED${NC} $proc"
        fi
    done
    for svc in com.apple.assistantd com.apple.assistant_cdmd com.apple.siriknowledged com.apple.siriinferenced com.apple.siriactionsd com.apple.sirittsd com.apple.siri.context.service; do
        launchctl disable "system/$svc" 2>/dev/null || true
        launchctl disable "user/$USER_ID/$svc" 2>/dev/null || true
    done
    echo -e "  ${GREEN}DISABLED${NC} all Siri services"
else
    echo -e "  ${YELLOW}SKIPPED${NC}"
fi

# ============================================================
echo ""
echo -e "${CYAN}[4] Spotlight knowledge daemons${NC}"
echo ""
echo "  spotlightknowledged, importer, and updater — build ML-powered"
echo "  'understanding' of your files beyond just filenames."
echo ""
echo -e "  ${YELLOW}BREAKS: Spotlight search loses contextual ranking (recently${NC}"
echo -e "  ${YELLOW}        used files, related documents). Name search still works.${NC}"
echo ""
read -p "  Nuke Spotlight knowledge daemons? [y/N] " CHOICE
if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    for proc in spotlightknowledged; do
        if pkill -9 -x "$proc" 2>/dev/null; then
            echo -e "  ${GREEN}KILLED${NC} $proc"
        fi
    done
    for svc in com.apple.spotlightknowledged com.apple.spotlightknowledged.importer com.apple.spotlightknowledged.updater; do
        launchctl disable "system/$svc" 2>/dev/null || true
        launchctl disable "user/$USER_ID/$svc" 2>/dev/null || true
    done
    echo -e "  ${GREEN}DISABLED${NC} all Spotlight knowledge services"
else
    echo -e "  ${YELLOW}SKIPPED${NC}"
fi

# ============================================================
echo ""
echo -e "${CYAN}[5] Proactive suggestions engine${NC}"
echo ""
echo "  proactived + proactiveeventtrackerd — predicts what apps you'll"
echo "  open and what files you'll need."
echo ""
echo -e "  ${YELLOW}BREAKS: Proactive app suggestions in Spotlight and Dock.${NC}"
echo -e "  ${YELLOW}        Already mostly dead if Siri + Knowledge are nuked.${NC}"
echo ""
read -p "  Nuke proactive engine? [y/N] " CHOICE
if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    for proc in proactived proactiveeventtrackerd; do
        if pkill -9 -x "$proc" 2>/dev/null; then
            echo -e "  ${GREEN}KILLED${NC} $proc"
        fi
    done
    for svc in com.apple.proactived com.apple.proactiveeventtrackerd; do
        launchctl disable "system/$svc" 2>/dev/null || true
        launchctl disable "user/$USER_ID/$svc" 2>/dev/null || true
    done
    echo -e "  ${GREEN}DISABLED${NC} proactive services"
else
    echo -e "  ${YELLOW}SKIPPED${NC}"
fi

# ============================================================
echo ""
echo -e "${CYAN}[6] routined (location routine learning)${NC}"
echo ""
echo "  Learns your daily location patterns — where you go, when, how often."
echo ""
echo -e "  ${YELLOW}BREAKS: 'Significant Locations' in Privacy settings empties out.${NC}"
echo -e "  ${YELLOW}        Calendar 'Leave Now' travel alerts stop working.${NC}"
echo ""
read -p "  Nuke routined? [y/N] " CHOICE
if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    if pkill -9 -x "routined" 2>/dev/null; then
        echo -e "  ${GREEN}KILLED${NC} routined"
    fi
    launchctl disable "system/com.apple.routined" 2>/dev/null || true
    launchctl disable "user/$USER_ID/com.apple.routined" 2>/dev/null || true
    echo -e "  ${GREEN}DISABLED${NC} routined"
else
    echo -e "  ${YELLOW}SKIPPED${NC}"
fi

# ============================================================
echo ""
echo -e "${CYAN}[7] CloudTelemetryService (iCloud telemetry)${NC}"
echo ""
echo "  5 separate processes reporting iCloud performance data to Apple."
echo "  Logs to ~/Library/Logs/com.apple.CloudTelemetry/"
echo ""
echo -e "  ${YELLOW}BREAKS: Nothing. iCloud keeps working. These only report${NC}"
echo -e "  ${YELLOW}        metrics about iCloud back to Apple.${NC}"
echo ""
read -p "  Nuke CloudTelemetryService? [y/N] " CHOICE
if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    pkill -9 -f "CloudTelemetryService" 2>/dev/null
    echo -e "  ${GREEN}KILLED${NC} CloudTelemetryService (all instances)"
    purge_and_lock "$REAL_HOME/Library/Logs/com.apple.CloudTelemetry" "CloudTelemetry logs"
else
    echo -e "  ${YELLOW}SKIPPED${NC}"
fi

# ============================================================
echo ""
echo -e "${RED}======================================"
echo "  NUKE PLUS COMPLETE"
echo "======================================${NC}"
echo ""
TOTAL_MB=$((TOTAL_FREED / 1024))
echo -e "Additional data purged: ${GREEN}${TOTAL_MB} MB${NC}"
echo ""
echo -e "${YELLOW}Reboot to fully apply changes.${NC}"
