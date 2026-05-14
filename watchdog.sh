#!/bin/bash
#
# macOS Tracking Watchdog
# Runs every 30 minutes via LaunchAgent
# Kills tracking processes, re-locks directories, verifies hosts blocks
#

LOG_DIR="$HOME/.macos-hardening"
LOG="$LOG_DIR/watchdog.log"
mkdir -p "$LOG_DIR" 2>/dev/null

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# Keep log under 1 MB
if [ -f "$LOG" ] && [ $(stat -f%z "$LOG" 2>/dev/null || echo 0) -gt 1048576 ]; then
    tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

if [ ! -f "$HOME/.macos-hardening/.nuke-completed" ]; then
    log "SKIPPED: nuke.sh has not been run yet. Run 'sudo bash nuke.sh' first."
    exit 0
fi

FOUND_ISSUE=false

# ============================================================
# Kill tracking processes
# ============================================================

for proc in mediaanalysisd triald parsecd analyticsagent inputanalyticsd geoanalyticsd diagnostics_agent diagnosticextensionsd feedbackd BiomeAgent biomesyncd; do
    if pgrep -x "$proc" > /dev/null 2>&1; then
        pkill -9 "$proc" 2>/dev/null
        log "KILLED $proc"
        FOUND_ISSUE=true
    fi
done

for root_proc in aned triald_system analyticsd osanalyticshelper; do
    if pgrep -x "$root_proc" > /dev/null 2>&1; then
        if pkill -9 "$root_proc" 2>/dev/null; then
            log "KILLED $root_proc"
        else
            log "FOUND $root_proc (root-owned, cannot kill from user context)"
        fi
        FOUND_ISSUE=true
    fi
done

# ============================================================
# Re-lock all protected directories
# ============================================================

relock() {
    local dir="$1"
    if [ -d "$dir" ]; then
        local perms=$(stat -f '%OLp' "$dir" 2>/dev/null)
        if [ "$perms" != "000" ]; then
            find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
            if chmod 000 "$dir" 2>/dev/null; then
                log "RE-LOCKED $dir (was $perms)"
            else
                log "FAILED to re-lock $dir (permission denied — re-run: sudo bash nuke.sh)"
            fi
            FOUND_ISSUE=true
        fi
    fi
}

# Apple tracking streams
relock "$HOME/Library/Biome/compute"
relock "$HOME/Library/Biome/databases"
relock "$HOME/Library/Biome/sync"
relock "$HOME/Library/Biome/sets"
relock "$HOME/Library/Biome/streams/restricted"
relock "$HOME/Library/IntelligencePlatform"
relock "$HOME/Library/Suggestions"
relock "$HOME/Library/DuetExpertCenter"

# Trial experiments
relock "$HOME/Library/Trial/Treatments"
relock "$HOME/Library/Trial/v7"
relock "$HOME/Library/Trial/NamespaceDescriptors"

# PegasusConfiguration
relock "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/rawSessions"
relock "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/session"
relock "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/feedback"
relock "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/EngagedCompletions"
relock "$HOME/Library/Group Containers/group.com.apple.PegasusConfiguration/local"
relock "$HOME/Library/Caches/com.apple.parsecd"

# Surveillance containers
relock "$HOME/Library/PersonalizationPortrait"
relock "$HOME/Library/Containers/com.apple.mediaanalysisd"
relock "$HOME/Library/Containers/com.apple.photoanalysisd"
relock "$HOME/Library/Containers/com.apple.geod"
relock "$HOME/Library/Group Containers/group.com.apple.UserNotifications"
relock "$HOME/Library/Group Containers/group.com.apple.chronod"
relock "$HOME/Library/Group Containers/group.com.apple.CoreSpeech"
relock "$HOME/Library/Group Containers/group.com.apple.siri.remembers"
relock "$HOME/Library/Assistant"
relock "$HOME/Library/HTTPStorages/com.apple.siriknowledged"
relock "$HOME/Library/Group Containers/group.com.apple.siri.userfeedbacklearning"
relock "$HOME/Library/Group Containers/group.com.apple.feedbacklogger"
relock "$HOME/Library/Group Containers/group.com.apple.siri.GMSSELFIngestor"
relock "$HOME/Library/Group Containers/group.com.apple.siri.sirisuggestions"
relock "$HOME/Library/Group Containers/group.com.apple.replayd"
relock "$HOME/Library/Group Containers/group.com.apple.screencapture/ScreenRecordings"
relock "$HOME/Library/Application Support/com.apple.replayd"
relock "$HOME/Library/AppleMediaServices/Engagement"
relock "$HOME/Library/Application Support/com.apple.ap.promotedcontentd"
relock "$HOME/Library/Group Containers/group.com.apple.contentdelivery"
relock "$HOME/Library/Containers/com.apple.lighthouse.BiomeLibraryEventUploader"
relock "$HOME/Library/Containers/com.apple.lighthouse.BiomeSELFIngestor"
relock "$HOME/Library/Containers/com.apple.lighthouse.IFTelemetrySELFIngestor"
relock "$HOME/Library/Containers/com.apple.lighthouse.IFTranscriptSELFIngestor"
relock "$HOME/Library/Containers/com.apple.lighthouse.SiriCoreMetricsWorker"
relock "$HOME/Library/Containers/com.apple.lighthouse.PnROnDeviceWorker"
relock "$HOME/Library/Containers/com.apple.lighthouse.IEMetricsWorker"
relock "$HOME/Library/Containers/com.apple.lighthouse.SAExtensionOrchestrator"
relock "$HOME/Library/Containers/com.apple.LighthouseBitacoraFramework.BitacoraWorker"
relock "$HOME/Library/Containers/com.apple.LighthouseBitacoraFramework.LighthouseBitacoraPlugin"
relock "$HOME/Library/Containers/com.apple.biome.BiomeStreams.BiomeLighthousePlugin"
relock "$HOME/Library/Containers/com.apple.proactive.AppleIntelligenceReportingSELFIngestor"
relock "$HOME/Library/Containers/com.apple.proactive.PersonalUnderstanding.LighthousePlugin"
relock "$HOME/Library/Containers/com.apple.siri.SiriSuggestionsLightHousePlugin"
relock "$HOME/Library/Logs/DiagnosticReports"
relock "$HOME/Library/Application Support/CrashReporter"

# Spotlight ML pipelines
relock "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledge/index.V2/DocumentProcessing"
relock "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledge/index.V2/KG"
relock "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledge/index.V2/updates"
relock "$HOME/Library/Metadata/CoreSpotlight/SpotlightKnowledgeEvents/index.V2/embedding_cache"
relock "$HOME/Library/Metadata/CoreSpotlight/Priority"
relock "$HOME/Library/Metadata/CoreSpotlight/PasteboardHistory"
relock "$HOME/Library/Metadata/CoreSpotlight/PipelineCompletenessReporting"

# Chrome AI models
relock "$HOME/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel"
relock "$HOME/Library/Application Support/Google/Chrome/optimization_guide_model_store"
relock "$HOME/Library/Application Support/Google/Chrome/screen_ai"
relock "$HOME/Library/Application Support/Google/Chrome/SODA"
relock "$HOME/Library/Application Support/Google/Chrome/SODALanguagePacks"
relock "$HOME/Library/Application Support/Google/Chrome/WasmTtsEngine"
relock "$HOME/Library/Application Support/Google/Chrome/OnDeviceHeadSuggestModel"
relock "$HOME/Library/Application Support/Google/Chrome/OptimizationHints"

# ============================================================
# Delete Spotlight ML receiver plists if they reappear
# ============================================================

for plist in \
    "$HOME/Library/Metadata/CoreSpotlight/com.apple.corespotlight.receiver.coreduet.plist" \
    "$HOME/Library/Metadata/CoreSpotlight/com.apple.corespotlight.receiver.suggestions.plist" \
    "$HOME/Library/Metadata/CoreSpotlight/com.apple.corespotlight.receiver.textunderstandingd.plist" \
    "$HOME/Library/Metadata/CoreSpotlight/com.apple.corespotlight.receiver.photos.plist"; do
    if [ -f "$plist" ]; then
        rm -f "$plist" 2>/dev/null
        log "DELETED Spotlight receiver: $(basename "$plist")"
        FOUND_ISSUE=true
    fi
done

# ============================================================
# Verify hosts file blocks
# ============================================================

if ! grep -q "smoot.apple.com" /etc/hosts 2>/dev/null; then
    log "WARNING: /etc/hosts telemetry blocks are MISSING — re-run: sudo bash nuke.sh"
    FOUND_ISSUE=true
fi

# ============================================================
# Re-disable services
# ============================================================

USER_ID=$(id -u)
for svc in com.apple.mediaanalysisd com.apple.aned com.apple.triald com.apple.parsecd com.apple.analyticsd com.apple.analyticsagent com.apple.osanalyticshelper com.apple.inputanalyticsd com.apple.geoanalyticsd com.apple.diagnostics_agent com.apple.diagnosticextensionsd com.apple.feedbackd com.apple.BiomeAgent com.apple.biomesyncd; do
    launchctl disable "user/$USER_ID/$svc" 2>/dev/null
done

if [ "$FOUND_ISSUE" = false ]; then
    log "OK"
fi
