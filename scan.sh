#!/bin/bash
#
# macOS Tracking Scanner
# Shows what Apple is collecting on your machine WITHOUT modifying anything
# Run this first to see what you're dealing with
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "======================================"
echo "  macOS Tracking Scanner"
echo "======================================"
echo -e "${NC}"
echo "This script is READ-ONLY. Nothing will be modified."
echo ""

TOTAL_SIZE=0

check_dir() {
    local dir="$1"
    local label="$2"

    if [ -d "$dir" ]; then
        local perms=$(stat -f '%OLp' "$dir" 2>/dev/null)
        local size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
        size=${size:-0}
        local size_mb=$((size / 1024))
        TOTAL_SIZE=$((TOTAL_SIZE + size))

        if [ "$perms" = "000" ] || [ "$perms" = "0" ]; then
            echo -e "  ${GREEN}LOCKED${NC}  $label (${size_mb} MB)"
        elif [ "$size" -gt 100 ]; then
            echo -e "  ${RED}ACTIVE${NC}  $label (${size_mb} MB)"
        else
            echo -e "  ${YELLOW}EXISTS${NC}  $label (${size_mb} MB)"
        fi
    else
        echo -e "  ${GREEN}ABSENT${NC}  $label"
    fi
}

check_process() {
    local proc="$1"
    local label="$2"
    local pid=$(pgrep -x "$proc" 2>/dev/null | head -1)
    if [ -n "$pid" ]; then
        local cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ')
        local mem=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ')
        local mem_mb=$((mem / 1024))
        echo -e "  ${RED}RUNNING${NC} $label (PID $pid, CPU ${cpu}%, RAM ${mem_mb} MB)"
    else
        echo -e "  ${GREEN}DEAD${NC}    $label"
    fi
}

# ============================================================
echo -e "${YELLOW}[Processes]${NC}"
# ============================================================

check_process "mediaanalysisd" "mediaanalysisd (photo/media ML)"
check_process "aned" "aned (Apple Neural Engine)"
check_process "triald" "triald (A/B experiments)"
check_process "parsecd" "parsecd (Pegasus/Spotlight telemetry)"
check_process "analyticsd" "analyticsd (central analytics)"
check_process "analyticsagent" "analyticsagent (user analytics)"
check_process "osanalyticshelper" "osanalyticshelper (OS analytics)"
check_process "inputanalyticsd" "inputanalyticsd (keystroke analytics)"
check_process "geoanalyticsd" "geoanalyticsd (location analytics)"
check_process "diagnostics_agent" "diagnostics_agent (diagnostics)"
check_process "feedbackd" "feedbackd (feedback collection)"
check_process "BiomeAgent" "BiomeAgent (behavioral data)"
check_process "biomesyncd" "biomesyncd (behavioral sync)"
check_process "biomed" "biomed (behavioral daemon)"
check_process "symptomsd" "symptomsd (network telemetry)"
check_process "audioanalyticsd" "audioanalyticsd (mic usage analytics)"
check_process "wifianalyticsd" "wifianalyticsd (wifi analytics)"
check_process "ecosystemanalyticsd" "ecosystemanalyticsd (ecosystem analytics)"
check_process "assistantd" "assistantd (Siri assistant)"
check_process "siriinferenced" "siriinferenced (Siri inference)"
check_process "sirittsd" "sirittsd (Siri TTS)"
check_process "siriactionsd" "siriactionsd (Siri actions)"
check_process "siriknowledged" "siriknowledged (Siri knowledge)"
check_process "SiriAUSP" "SiriAUSP (Siri audio processing)"
check_process "assistant_cdmd" "assistant_cdmd (Siri dialog manager)"
check_process "photoanalysisd" "photoanalysisd (photo ML)"
check_process "weatherd" "weatherd (weather daemon)"
check_process "remindd" "remindd (reminders daemon)"
check_process "tipsd" "tipsd (tips daemon)"
check_process "corespotlightd" "corespotlightd (Spotlight ML)"
check_process "mds_stores" "mds_stores (Spotlight indexer)"

# ============================================================
echo -e "\n${YELLOW}[Apple Tracking Streams]${NC}"
# ============================================================

check_dir "$HOME/Library/Biome" "Biome (behavioral tracking)"
check_dir "$HOME/Library/IntelligencePlatform" "IntelligencePlatform (knowledge graph)"
check_dir "$HOME/Library/DuetExpertCenter" "DuetExpertCenter (behavioral prediction)"
check_dir "$HOME/Library/Suggestions" "Suggestions"

# ============================================================
echo -e "\n${YELLOW}[Apple Experiments]${NC}"
# ============================================================

check_dir "$HOME/Library/Trial" "Trial (A/B testing)"

if [ -f "$HOME/Library/Trial/v7/Database/triald.db" ]; then
    exp_count=$(sqlite3 "$HOME/Library/Trial/v7/Database/triald.db" "SELECT COUNT(*) FROM experiments;" 2>/dev/null)
    rollout_count=$(sqlite3 "$HOME/Library/Trial/v7/Database/triald.db" "SELECT COUNT(*) FROM rolloutsV2;" 2>/dev/null)
    if [ -n "$exp_count" ]; then
        echo -e "  ${RED}FOUND${NC}   $exp_count experiments + $rollout_count rollouts active"
    fi
fi

# ============================================================
echo -e "\n${YELLOW}[Pegasus / Spotlight Telemetry]${NC}"
# ============================================================

PEGASUS="$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration"
check_dir "$PEGASUS" "PegasusConfiguration"
check_dir "$PEGASUS/rawSessions" "Pegasus raw sessions"
check_dir "$PEGASUS/session" "Pegasus session data"
check_dir "$PEGASUS/feedback" "Pegasus feedback (upload queue)"
check_dir "$PEGASUS/EngagedCompletions" "Pegasus engaged completions"
check_dir "$PEGASUS/local" "Pegasus local data"
check_dir "$HOME/Library/Caches/com.apple.parsecd" "Parsecd Silhouette cache (user profiling)"

# ============================================================
echo -e "\n${YELLOW}[PersonalizationPortrait (User Dossier)]${NC}"
# ============================================================

check_dir "$HOME/Library/PersonalizationPortrait" "PersonalizationPortrait"

if [ -f "$HOME/Library/PersonalizationPortrait/PPSQLDatabase.db" ]; then
    entities=$(sqlite3 "$HOME/Library/PersonalizationPortrait/PPSQLDatabase.db" "SELECT COUNT(*) FROM ne_records;" 2>/dev/null)
    topics=$(sqlite3 "$HOME/Library/PersonalizationPortrait/PPSQLDatabase.db" "SELECT COUNT(*) FROM tp_records;" 2>/dev/null)
    contacts=$(sqlite3 "$HOME/Library/PersonalizationPortrait/PPSQLDatabase.db" "SELECT COUNT(DISTINCT handle) FROM significant_contacts;" 2>/dev/null)
    locations=$(sqlite3 "$HOME/Library/PersonalizationPortrait/PPSQLDatabase.db" "SELECT COUNT(*) FROM loc_records;" 2>/dev/null)
    if [ -n "$entities" ]; then
        echo -e "  ${RED}DOSSIER${NC} $entities entities, $topics topics, $contacts contacts, $locations locations"
    fi
fi

# ============================================================
echo -e "\n${YELLOW}[Spotlight ML Pipelines]${NC}"
# ============================================================

SPOTLIGHT="$HOME/Library/Metadata/CoreSpotlight"
check_dir "$SPOTLIGHT/SpotlightKnowledge/index.V2/DocumentProcessing" "ML document processing"
check_dir "$SPOTLIGHT/SpotlightKnowledge/index.V2/KG" "Knowledge graph"
check_dir "$SPOTLIGHT/SpotlightKnowledge/index.V2/updates" "Spotlight updates"
check_dir "$SPOTLIGHT/SpotlightKnowledgeEvents/index.V2/embedding_cache" "ML embedding cache"
check_dir "$SPOTLIGHT/Priority" "Spotlight priority data"
check_dir "$SPOTLIGHT/PasteboardHistory" "Clipboard history"
check_dir "$SPOTLIGHT/PipelineCompletenessReporting" "Pipeline reporting"

for plist in coreduet suggestions textunderstandingd photos; do
    if [ -f "$SPOTLIGHT/com.apple.corespotlight.receiver.$plist.plist" ]; then
        echo -e "  ${RED}ACTIVE${NC}  Spotlight receiver: $plist"
    fi
done

# ============================================================
echo -e "\n${YELLOW}[Surveillance Containers]${NC}"
# ============================================================

check_dir "$HOME/Library/Containers/com.apple.mediaanalysisd" "mediaanalysisd (media ML)"
check_dir "$HOME/Library/Containers/com.apple.photoanalysisd" "photoanalysisd (photo ML)"
check_dir "$HOME/Library/Containers/com.apple.geod" "geod (location cache)"
check_dir "$HOME/Library/Group Containers/group.com.apple.UserNotifications" "UserNotifications"
check_dir "$HOME/Library/Group Containers/group.com.apple.chronod" "chronod (time tracking)"
check_dir "$HOME/Library/Group Containers/group.com.apple.CoreSpeech" "CoreSpeech"
check_dir "$HOME/Library/Group Containers/group.com.apple.siri.remembers" "siri.remembers"
check_dir "$HOME/Library/Assistant" "Siri assistant data (LLM cache + vocabulary)"
check_dir "$HOME/Library/HTTPStorages/com.apple.siriknowledged" "siriknowledged HTTP cache"
check_dir "$HOME/Library/Group Containers/group.com.apple.siri.userfeedbacklearning" "Siri feedback learning"
check_dir "$HOME/Library/Group Containers/group.com.apple.feedbacklogger" "Siri telemetry upload queue"
check_dir "$HOME/Library/Group Containers/group.com.apple.siri.GMSSELFIngestor" "Siri GMS metrics"
check_dir "$HOME/Library/Group Containers/group.com.apple.siri.sirisuggestions" "Siri suggestions cache"
check_dir "$HOME/Library/Group Containers/group.com.apple.replayd" "replayd (screen capture)"
check_dir "$HOME/Library/Group Containers/group.com.apple.screencapture/ScreenRecordings" "ScreenRecordings"
check_dir "$HOME/Library/Application Support/com.apple.replayd" "replayd app support"
check_dir "$HOME/Library/AppleMediaServices/Engagement" "App Store engagement"
check_dir "$HOME/Library/Application Support/com.apple.ap.promotedcontentd" "Promoted content / ads"
check_dir "$HOME/Library/Group Containers/group.com.apple.contentdelivery" "Content delivery (tips/promos)"

# ============================================================
echo -e "\n${YELLOW}[Lighthouse Telemetry Pipeline]${NC}"
# ============================================================

check_dir "$HOME/Library/Containers/com.apple.lighthouse.BiomeLibraryEventUploader" "Lighthouse/BiomeEventUploader"
check_dir "$HOME/Library/Containers/com.apple.lighthouse.BiomeSELFIngestor" "Lighthouse/BiomeSELFIngestor"
check_dir "$HOME/Library/Containers/com.apple.lighthouse.IFTelemetrySELFIngestor" "Lighthouse/IFTelemetry"
check_dir "$HOME/Library/Containers/com.apple.lighthouse.IFTranscriptSELFIngestor" "Lighthouse/IFTranscript"
check_dir "$HOME/Library/Containers/com.apple.lighthouse.SiriCoreMetricsWorker" "Lighthouse/SiriMetrics"
check_dir "$HOME/Library/Containers/com.apple.lighthouse.PnROnDeviceWorker" "Lighthouse/PnROnDevice"
check_dir "$HOME/Library/Containers/com.apple.proactive.AppleIntelligenceReportingSELFIngestor" "Proactive/AIReporting"
check_dir "$HOME/Library/Containers/com.apple.proactive.PersonalUnderstanding.LighthousePlugin" "Proactive/PersonalUnderstanding"
check_dir "$HOME/Library/Logs/DiagnosticReports" "DiagnosticReports (crash dumps)"
check_dir "$HOME/Library/Application Support/CrashReporter" "CrashReporter (per-app crash history)"

# ============================================================
echo -e "\n${YELLOW}[Chrome AI Models]${NC}"
# ============================================================

CHROME="$HOME/Library/Application Support/Google/Chrome"
check_dir "$CHROME/OptGuideOnDeviceModel" "Gemini Nano LLM"
check_dir "$CHROME/optimization_guide_model_store" "ML model store"
check_dir "$CHROME/screen_ai" "Screen AI"
check_dir "$CHROME/SODA" "Speech recognition"
check_dir "$CHROME/SODALanguagePacks" "SODA language packs"
check_dir "$CHROME/WasmTtsEngine" "TTS engine"
check_dir "$CHROME/OnDeviceHeadSuggestModel" "Autocomplete model"
check_dir "$CHROME/OptimizationHints" "Optimization hints"

# ============================================================
echo -e "\n${YELLOW}[Network]${NC}"
# ============================================================

if grep -q "smoot.apple.com" /etc/hosts 2>/dev/null; then
    echo -e "  ${GREEN}BLOCKED${NC} Apple telemetry domains in /etc/hosts"
else
    echo -e "  ${RED}OPEN${NC}    Apple telemetry domains NOT blocked in /etc/hosts"
fi

if grep -q "analytics.apple.com" /etc/hosts 2>/dev/null; then
    echo -e "  ${GREEN}BLOCKED${NC} Analytics/crash/diagnostics domains in /etc/hosts"
else
    echo -e "  ${RED}OPEN${NC}    Analytics/crash/diagnostics domains NOT blocked in /etc/hosts"
fi

USER_AGENT_PLIST="$HOME/Library/LaunchAgents/com.maisara.kill-telemetry.plist"
SYSTEM_DAEMON_PLIST="/Library/LaunchDaemons/com.maisara.kill-telemetry-system.plist"

if [ -f "$USER_AGENT_PLIST" ]; then
    if launchctl list | grep -q "com.maisara.kill-telemetry" 2>/dev/null; then
        echo -e "  ${GREEN}ACTIVE${NC}  Persistent kill agent (LaunchAgent) — Sequoia+ fix loaded"
    else
        echo -e "  ${YELLOW}EXISTS${NC}  Persistent kill agent plist found but NOT loaded"
    fi
else
    echo -e "  ${YELLOW}ABSENT${NC}  Persistent kill agent NOT installed (needed on macOS Sequoia+)"
fi

if [ -f "$SYSTEM_DAEMON_PLIST" ]; then
    echo -e "  ${GREEN}EXISTS${NC}  System kill daemon (LaunchDaemon) — Sequoia+ fix installed"
else
    echo -e "  ${YELLOW}ABSENT${NC}  System kill daemon NOT installed (needed on macOS Sequoia+)"
fi

# ============================================================
echo ""
TOTAL_MB=$((TOTAL_SIZE / 1024))
echo -e "${CYAN}Total tracking data found: ${TOTAL_MB} MB${NC}"
echo ""
echo "To purge everything: sudo bash nuke.sh"
echo "To install watchdog: bash install-watchdog.sh"
