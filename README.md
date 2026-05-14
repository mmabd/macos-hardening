# macOS Hardening

Purge Apple's hidden surveillance data from your Mac and block it from coming back.

## What Apple collects on your machine

This isn't speculation. We read the databases. Here's what we found:

### PersonalizationPortrait
Apple reads **every webpage you visit in Safari** and builds a scored profile of your interests, contacts, and locations. It extracts named entities (people, businesses, places), categorizes your interests using Wikidata topic IDs, stores your contacts' phone numbers in plaintext, and ranks your "significant" relationships. The database is called `PPSQLDatabase.db` and lives at `~/Library/PersonalizationPortrait/`.

### PegasusConfiguration
Apple's Spotlight/Siri telemetry backend (codename "Pegasus") runs 16 feedback channels — each with a 2 MB upload buffer — collecting data on: app usage, Safari autofill behavior, search result engagement, notification interactions, and more. It includes a "Silhouette" user profiling framework that downloads topic mappings and fingerprinting configs from `cdn.smoot.apple.com`. A persistent device UUID ties all telemetry to your machine.

### Trial (A/B Experiments)
Apple runs dozens of experiments on your machine without consent: DRM enforcement testing, ad placement A/B tests, Safari search result manipulation, Siri behavioral memory, financial data extraction, and opaque codename projects (BLACKPEARL_SPARROW, PICKLED_RIND). Each experiment downloads treatment payloads — some over 24 MB of ML model weights.

### Spotlight ML Pipelines
Spotlight isn't just file search. It runs ML pipelines that:
- Read your emails, iMessages, Safari history, calendar, and Notes
- Extract events, orders, and receipts from your documents ("LSSR5EventsandordersUrgent")
- **Scan for ID documents** — passports, licenses ("LSSR5IdentificationdocumentsBackground")
- Generate ML vector embeddings of your content
- Build a knowledge graph of your life
- Extract keyphrases from everything
- Feed all of this to `textunderstandingd` — Apple's text comprehension AI

The `mds_stores` process uses up to **1 GB of RAM** running these pipelines.

### Tracking Containers
- `mediaanalysisd` (457 MB) — ML analysis of your photos and media
- `photoanalysisd` (92 MB) — more photo ML
- `geod` (381 MB) — location data cache
- `UserNotifications` (881 MB) — full notification history
- `chronod` (51 MB) — time-based behavioral tracking
- `CoreSpeech` (13 MB) — speech recognition data
- `siri.remembers` — Siri's memory of your behavior
- `replayd` — tracks screen capture usage per app (7,597 captures logged for Chrome alone)
- `AppleMediaServices/Engagement` — App Store engagement tracking with "journeys" and "recommendations" databases

### Chrome AI Models
Chrome silently downloads ~4.5 GB of ML models: Gemini Nano (full LLM), toxicity scorer, phishing model, speech recognition, text-to-speech, and more.

### Total: 3+ GB of surveillance data on a typical Mac

## What this tool does

1. **`scan.sh`** — Read-only scan. Shows everything Apple is collecting, how much data, whether processes are running. Run this first.
2. **`nuke.sh`** — Purges all tracking data, locks directories with `chmod 000`, kills processes, disables services, blocks 19 telemetry domains in `/etc/hosts`, and hardens Spotlight/Siri/ad settings. Safe defaults — nothing user-facing breaks.
3. **`nuke-plus.sh`** — Optional extended hardening. Interactive — asks y/N for each item. Disables features like Handoff, Screen Time, Siri daemons, Spotlight knowledge, proactive suggestions, location routines, and cloud telemetry. Run after `nuke.sh`.
4. **`install-watchdog.sh`** — Installs a LaunchAgent that runs every 30 minutes to re-lock anything Apple tries to undo after updates or reboots.
5. **`uninstall.sh`** — Removes the watchdog and restores directory permissions. Purged data stays gone.

## Usage

### Open Terminal
Press **Cmd + Space**, type **Terminal**, and hit Enter. Then paste the commands below.

```bash
# Clone the repo
git clone https://github.com/mmabd/macos-hardening.git
cd macos-hardening

# 1. See what Apple is collecting (read-only, safe)
bash scan.sh

# 2. Nuke all tracking data (requires sudo, asks for confirmation)
sudo bash nuke.sh

# 3. Optional: extended hardening (interactive, asks y/N per feature)
sudo bash nuke-plus.sh

# 4. Install the watchdog (NO sudo — run as your user)
bash install-watchdog.sh

# 5. Reboot to fully kill SIP-protected daemons
sudo reboot
```

**Important:**
- Always use `sudo bash nuke.sh` directly — do NOT use `sudo su` first
- Do NOT use `sudo` for `install-watchdog.sh` or `uninstall.sh`
- `nuke.sh` is safe defaults — no user-facing features break
- `nuke-plus.sh` disables real features — it tells you exactly what breaks before each step

## After running

- **Cmd+Space still works** — Spotlight search for apps, files, folders, and calculator is preserved
- **Messages, Mail, Safari work normally** — only the surveillance backends are killed
- **Check the watchdog log** to see what Apple tries to restore:
  ```bash
  cat ~/.macos-hardening/watchdog.log
  ```

### Known side effects
- **App notifications** may stop appearing (Calendar alerts, Reminders, Messages previews) because `UserNotifications` is locked. They resume after uninstall.
- **Location services** will be degraded — Maps, Weather, and Find My may not work correctly because `geod` is locked.
- **Speech recognition** data is cleared — Siri/Dictation may need to relearn your voice.

## Limitations

- **SIP-protected daemons** (`aned`, `triald_system`) run as root and macOS will resurrect them on every boot. The watchdog kills user-level variants; the `/etc/hosts` blocks ensure even root-level daemons can't exfiltrate data.
- **macOS updates** may reset directory permissions and re-enable services. The watchdog catches this within 30 minutes. The hosts file may also be overwritten — the watchdog logs a warning if telemetry blocks are missing.
- **This does not affect iOS.** Your iPhone runs the same pipelines but without root access, you can't do anything about it. Consider GrapheneOS on a Pixel.

## What gets blocked

### Processes killed
| Process | What it does |
|---|---|
| `mediaanalysisd` | Photo/media ML analysis |
| `aned` | Apple Neural Engine compiler (root-owned, may require SIP disable) |
| `triald` / `triald_system` | A/B experiment manager |
| `parsecd` | Pegasus/Spotlight telemetry |
| `mdworker` | Spotlight ML worker |
| `mdbulkimport` | Spotlight bulk indexer |

### Processes monitored (scan only)
| Process | What it does |
|---|---|
| `mds_stores` | Spotlight ML indexer (not killed — breaks Cmd+Space search) |
| `corespotlightd` | Spotlight knowledge engine (not killed — breaks file search) |

### Domains blocked in /etc/hosts
```
0.0.0.0 api.smoot.apple.com
0.0.0.0 api-glb-aeun1a.smoot.apple.com
0.0.0.0 api-glb-aeun1b.smoot.apple.com
0.0.0.0 cdn.smoot.apple.com
0.0.0.0 fbs.smoot.apple.com
0.0.0.0 xp.apple.com
0.0.0.0 metrics.apple.com
0.0.0.0 metrics.icloud.com
0.0.0.0 idiagnostics.apple.com
0.0.0.0 diagnostics.apple.com
0.0.0.0 securemetrics.apple.com
0.0.0.0 supportmetrics.apple.com
0.0.0.0 feedbackws.apple.com
0.0.0.0 radarsubmissions.apple.com
0.0.0.0 iphonesubmissions.apple.com
0.0.0.0 pancake.apple.com
0.0.0.0 weather-analytics.apple.com
0.0.0.0 books-analytics.apple.com
0.0.0.0 notes-analytics.apple.com
```

### Directories locked (chmod 000)
Over 40 directories across Biome, IntelligencePlatform, DuetExpertCenter, Trial, PegasusConfiguration, PersonalizationPortrait, Spotlight ML pipelines, surveillance containers, and Chrome AI model directories.

## Uninstall

```bash
bash uninstall.sh
```

This removes the watchdog, restores directory permissions, and re-enables disabled services. It does **NOT** automatically undo:

- **`/etc/hosts` blocks** — edit `/etc/hosts` manually and delete lines under `# macOS-hardening telemetry blocks`
- **Spotlight/Siri settings** — the uninstall script prints `defaults` commands to restore them
- **Purged data** — gone permanently; Apple will rebuild it over time once directories are unlocked

## License

MIT
