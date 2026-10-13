#!/bin/zsh
#
# Siri AI EU – Final Post-Boot Recovery
# Verifiziert auf macOS 27.0.1 (26A434), Apple Silicon.
#
# Zielzustand am Ende:
#   - macOS-Oberflächensprache: Deutsch (de-DE an Position 1)
#   - Siri-Sprache: en-US
#   - Siri AI / Campo UI: Deutsch
#   - GREYMATTER = 4
#   - AMERICIUM = 4
#   - SIRI_MODE = 4
#   - MATCH = 3
#   - HAS_LINWOOD = 3
#   - LINWOOD_AVAILABILITY = 1
#
# Das Skript editiert KEINE Eligibility-Antwort manuell.
# Fehlende Eligibility-Snapshots werden ausschließlich durch Apples
# eligibilityd regeneriert.
#
# Nicht verändert:
#   SIP, /System, WARP, Surge, DNS, VPN,
#   networkserviceproxy, privatecloudcomputed, Modell-/Asset-Dateien.
#

set +e
setopt NO_NOMATCH
umask 077

STAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT="$HOME/Desktop/Siri-AI-Post-Boot-${STAMP}.txt"
PROPLOG="$HOME/Desktop/Siri-AI-Post-Boot-${STAMP}-Propagation.log"
TMP="$(mktemp -d /tmp/siriai-postboot.XXXXXX)"

ELIG="/private/var/db/eligibilityd/eligibility.plist"
OSELIG="/private/var/db/os_eligibility/eligibility.plist"
SIRI_APP="/System/Applications/Siri AI.app"

LOGPID=""
RECOVERY_OK=0
FINALIZED=0
SAFE_TO_FINALIZE=0

exec > >(tee -a "$REPORT") 2>&1

section() {
    echo
    echo "========================================================================"
    echo "$1"
    echo "========================================================================"
}

pause_end() {
    echo
    echo "Report:"
    echo "$REPORT"
    echo
    echo "Propagation-Log:"
    echo "$PROPLOG"
    echo
    read "?Enter drücken zum Schließen ..."
}

finalize_german() {
    (( FINALIZED )) && return
    FINALIZED=1

    echo
    echo "Finaler Sprachzustand wird gesetzt ..."

    # Gewünschter Endzustand:
    # macOS Deutsch, Englisch als Fallback, Siri weiterhin en-US.
    /usr/bin/defaults write \
        NSGlobalDomain \
        AppleLanguages \
        -array "de-DE" "en-US" "en-DE"

    /usr/bin/defaults write \
        com.apple.assistant.backedup \
        "Session Language" \
        -string "en-US"

    /usr/bin/defaults write \
        com.apple.siri.generativeassistantsettings \
        isEnabled \
        -bool true

    # Per-App-Lokalisierung: Siri AI / Campo soll auf Deutsch starten.
    /usr/bin/defaults write \
        com.apple.campo \
        AppleLanguages \
        -array "de-DE"

    # WICHTIG:
    # Nach diesem Restore KEINE globale Language-Notification posten.
    # So bleibt der unter en-US berechnete Eligibility-Zustand unangetastet.

    echo
    echo "AppleLanguages:"
    /usr/bin/defaults read -g AppleLanguages 2>&1

    echo
    echo "Siri Session Language:"
    /usr/bin/defaults read \
        com.apple.assistant.backedup \
        "Session Language" 2>&1

    echo
    echo "Siri AI App-Lokalisierung:"
    /usr/bin/defaults read \
        com.apple.campo \
        AppleLanguages 2>&1

}

cleanup() {
    [[ -n "$LOGPID" ]] && kill "$LOGPID" 2>/dev/null || true

    # Erst NACH bestandenem Preflight dürfen wir überhaupt Einstellungen
    # verändern. So bleibt ein inkompatibler Mac bei einem frühen Abbruch
    # vollständig unangetastet.
    if (( SAFE_TO_FINALIZE )); then
        # Egal ob Erfolg oder Fehler: niemals mit temporär englischer
        # Systemsprache enden.
        finalize_german
    fi

    rm -rf "$TMP" 2>/dev/null || true
}

on_signal() {
    trap - EXIT INT TERM HUP
    echo
    echo "Abbruch erkannt."
    [[ -n "$LOGPID" ]] && kill "$LOGPID" 2>/dev/null || true
    if (( SAFE_TO_FINALIZE )); then
        finalize_german
    fi
    rm -rf "$TMP" 2>/dev/null || true
    exit 130
}

trap cleanup EXIT
trap on_signal INT TERM HUP

read_answer() {
    local plist="$1" domain="$2"

    [[ -f "$plist" ]] || {
        echo "?"
        return
    }

    sudo /usr/libexec/PlistBuddy \
        -c "Print :${domain}:os_eligibility_answer_t" \
        "$plist" 2>/dev/null
}

read_status() {
    local plist="$1" domain="$2" key="$3"

    [[ -f "$plist" ]] || {
        echo "?"
        return
    }

    sudo /usr/libexec/PlistBuddy \
        -c "Print :${domain}:status:${key}" \
        "$plist" 2>/dev/null
}

read_context() {
    local plist="$1" domain="$2" key="$3"

    [[ -f "$plist" ]] || {
        echo "?"
        return
    }

    sudo /usr/libexec/PlistBuddy \
        -c "Print :${domain}:context:${key}" \
        "$plist" 2>/dev/null
}

show_status() {
    echo "GREYMATTER = $(read_answer "$ELIG" OS_ELIGIBILITY_DOMAIN_GREYMATTER)"
    echo "AMERICIUM = $(read_answer "$ELIG" OS_ELIGIBILITY_DOMAIN_AMERICIUM)"
    echo "SIRI_MODE = $(read_answer "$OSELIG" OS_ELIGIBILITY_DOMAIN_SIRI_MODE)"

    echo "MATCH = $(read_status \
        "$ELIG" \
        OS_ELIGIBILITY_DOMAIN_GREYMATTER \
        OS_ELIGIBILITY_INPUT_DEVICE_AND_SIRI_LANGUAGE_MATCH)"

    echo "GREYMATTER DEVICE_LANGUAGE = $(read_status \
        "$ELIG" \
        OS_ELIGIBILITY_DOMAIN_GREYMATTER \
        OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE)"

    echo "AMERICIUM DEVICE_LANGUAGE = $(read_status \
        "$ELIG" \
        OS_ELIGIBILITY_DOMAIN_AMERICIUM \
        OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE)"

    echo "HAS_LINWOOD = $(read_status \
        "$ELIG" \
        OS_ELIGIBILITY_DOMAIN_AMERICIUM \
        OS_ELIGIBILITY_INPUT_HAS_LINWOOD)"

    echo "LINWOOD_AVAILABILITY = $(read_context \
        "$ELIG" \
        OS_ELIGIBILITY_DOMAIN_AMERICIUM \
        OS_ELIGIBILITY_CONTEXT_LINWOOD_AVAILABILITY)"
}

eligible_now() {
    [[ "$(read_answer "$ELIG" OS_ELIGIBILITY_DOMAIN_GREYMATTER)" == "4" \
       && "$(read_answer "$ELIG" OS_ELIGIBILITY_DOMAIN_AMERICIUM)" == "4" \
       && "$(read_answer "$OSELIG" OS_ELIGIBILITY_DOMAIN_SIRI_MODE)" == "4" \
       && "$(read_status "$ELIG" OS_ELIGIBILITY_DOMAIN_GREYMATTER OS_ELIGIBILITY_INPUT_DEVICE_AND_SIRI_LANGUAGE_MATCH)" == "3" \
       && "$(read_status "$ELIG" OS_ELIGIBILITY_DOMAIN_AMERICIUM OS_ELIGIBILITY_INPUT_HAS_LINWOOD)" == "3" \
       && "$(read_context "$ELIG" OS_ELIGIBILITY_DOMAIN_AMERICIUM OS_ELIGIBILITY_CONTEXT_LINWOOD_AVAILABILITY)" == "1" ]]
}

post_language_notifications() {
    /usr/bin/notifyutil \
        -p AppleLanguagePreferencesChangedNotification \
        2>/dev/null || true

    /usr/bin/notifyutil \
        -p AFLanguageCodeDidChangeDarwinNotification \
        2>/dev/null || true
}

refresh_preference_daemons() {
    echo "cfprefsd wird kontrolliert neu geladen ..."

    killall cfprefsd 2>/dev/null || true
    sudo killall cfprefsd 2>/dev/null || true

    sleep 3

    echo "cfprefsd danach:"
    pgrep -fl cfprefsd || true
}

foundation_language_check() {
    local out=""

    if [[ -x /usr/bin/swift ]]; then
        out="$(/usr/bin/swift -e '
import Foundation
print("Locale.preferredLanguages =", Locale.preferredLanguages)
let candidates = ["en", "de", "fr", "es", "it"]
print("preferredLocalizations =", Bundle.preferredLocalizations(from: candidates, forPreferences: Locale.preferredLanguages))
' 2>&1)"

        echo "$out"

        echo "$out" | grep -Eq \
            'Locale\.preferredLanguages = \["en-US"|preferredLocalizations = \["en"'

        return $?
    fi

    # Auf einem Mac ohne Swift/Command Line Tools wird die Recovery nicht
    # blockiert. defaults + frischer cfprefsd entsprechen trotzdem demselben
    # Preferences-Pfad; nur die zusätzliche Foundation-Verifikation entfällt.
    echo "Swift ist nicht installiert; Foundation-Verifikation wird übersprungen."
    return 0
}

restart_eligibilityd() {
    local old new

    old="$(pgrep -x eligibilityd | head -1)"
    echo "Alter eligibilityd PID: ${old:-<keiner>}"

    [[ -n "$old" ]] && sudo kill -TERM "$old" 2>/dev/null || true

    new=""

    for i in {1..60}; do
        sleep 0.25
        new="$(pgrep -x eligibilityd | head -1)"
        [[ -n "$new" && "$new" != "$old" ]] && break
    done

    if [[ -z "$new" || "$new" == "$old" ]]; then
        # Diese Notification ist gleichzeitig ein LaunchEvent für eligibilityd.
        /usr/bin/notifyutil \
            -p AppleLanguagePreferencesChangedNotification \
            2>/dev/null || true

        for i in {1..60}; do
            sleep 0.25
            new="$(pgrep -x eligibilityd | head -1)"
            [[ -n "$new" && "$new" != "$old" ]] && break
        done
    fi

    echo "Neuer eligibilityd PID: ${new:-<nicht gefunden>}"

    [[ -n "$new" && "$new" != "$old" ]]
}

wait_for_snapshots() {
    local i

    for i in {1..20}; do
        [[ -f "$ELIG" && -f "$OSELIG" ]] && return 0
        sleep 0.5
    done

    return 1
}

restart_siri_user_stack() {
    osascript -e 'tell application "Siri AI" to quit' 2>/dev/null || true
    pkill -f '/System/Applications/Siri AI.app/' 2>/dev/null || true

    for p in \
        intelligenceflowd \
        intelligencecontextd \
        siriactionsd \
        assistantd
    do
        killall "$p" 2>/dev/null || true
    done

    # Spotlight-UI darf die deutsche Lokalisierung ebenfalls frisch laden.
    killall Spotlight 2>/dev/null || true

    sleep 4
}

siri_available() {
    /usr/bin/defaults read \
        com.apple.assistant.backedup \
        SiriAvailability \
        2>/dev/null \
        | grep -Eq 'isAvailable = 1;'
}

show_siri_availability() {
    /usr/bin/defaults read \
        com.apple.assistant.backedup \
        SiriAvailability \
        2>/dev/null \
        | grep -E \
          'linwoodCapabilities|saeCapabilities|currentOrchestrationMode|desiredOrchestrationMode|desiredOrchestrationModeIfEnabled|isAvailable|linwoodEverAvailable|restrictionReasons|siriLocale|unavailabilityReasons' \
        || true
}

section "SIRI AI EU – FINAL POST-BOOT RECOVERY – PREFLIGHT"

echo "Zeit: $(date)"
VERSION="$(sw_vers -productVersion 2>/dev/null)"
BUILD="$(sw_vers -buildVersion 2>/dev/null)"

sw_vers
echo "Architektur: $(uname -m)"

if [[ "$(uname -m)" != "arm64" ]]; then
    echo
    echo "ABBRUCH: Apple-Silicon-Mac erforderlich."
    pause_end
    exit 1
fi

if [[ "$VERSION" != 27.* ]]; then
    echo
    echo "ABBRUCH: Diese Recovery ist für macOS 27.x gebaut."
    echo "Gefunden: $VERSION ($BUILD)"
    pause_end
    exit 1
fi

if [[ ! -d "$SIRI_APP" ]]; then
    echo
    echo "ABBRUCH: $SIRI_APP ist auf diesem Mac nicht vorhanden."
    echo "Die Recovery erzeugt keine System-App künstlich."
    pause_end
    exit 1
fi

if [[ "$BUILD" != "26A434" ]]; then
    echo
    echo "HINWEIS: Verifiziert wurde Build 26A434."
    echo "Dieser Mac nutzt Build $BUILD. Es wird mit denselben Apple-27.x-APIs fortgefahren."
fi

echo
echo "Administratorrechte werden benötigt."
sudo -v || {
    echo "ABBRUCH: Keine Administratorrechte."
    pause_end
    exit 1
}

# Ab hier sind Plattform, Siri-AI-App und Administratorzugriff geprüft.
# Erst jetzt darf der EXIT-Handler im Fehlerfall den gewünschten deutschen
# Endzustand herstellen.
SAFE_TO_FINALIZE=1

echo
echo "Aktuelle AppleLanguages:"
defaults read -g AppleLanguages 2>&1

echo
echo "Aktuelle Siri-Sprache:"
defaults read \
    com.apple.assistant.backedup \
    "Session Language" 2>&1

section "AKTUELLER ELIGIBILITY-ZUSTAND"

show_status

if eligible_now; then
    echo
    echo "✓ Eligibility ist bereits vollständig aktiv."
    echo "Der Freischaltungsdurchlauf wird übersprungen."
    RECOVERY_OK=1
else
    section "1. TEMPORÄREN VERIFIZIERTEN ERFOLGSZUSTAND HERSTELLEN"

    # Siri AI während Englisch-Phase geschlossen halten, damit die UI nicht
    # englisch gecacht wird.
    osascript -e 'tell application "Siri AI" to quit' 2>/dev/null || true
    pkill -f '/System/Applications/Siri AI.app/' 2>/dev/null || true

    /usr/bin/defaults write \
        com.apple.assistant.backedup \
        "Session Language" \
        -string "en-US"

    /usr/bin/defaults write \
        com.apple.siri.generativeassistantsettings \
        isEnabled \
        -bool true

    # Exakt der auf dem Test-Mac bewiesene Eligibility-Zustand.
    /usr/bin/defaults write \
        NSGlobalDomain \
        AppleLanguages \
        -array "en-US" "de-DE"

    echo "AppleLanguages temporär:"
    defaults read -g AppleLanguages

    echo
    echo "Siri temporär:"
    defaults read \
        com.apple.assistant.backedup \
        "Session Language" 2>&1

    section "2. PREFERENCES-CACHE FRISCH LADEN"

    refresh_preference_daemons

    echo
    echo "Foundation-Sprachprüfung:"
    FOUNDATION_OK=0

    for attempt in 1 2 3; do
        echo "Versuch $attempt:"
        if foundation_language_check; then
            FOUNDATION_OK=1
            break
        fi

        echo
        echo "Preferences erneut laden ..."
        refresh_preference_daemons
    done

    if (( FOUNDATION_OK == 0 )); then
        echo
        echo "ABBRUCH: Die temporäre englische Sprache ist noch nicht im"
        echo "Foundation-Layer angekommen."
        exit 2
    fi

    section "3. 15 SEKUNDEN SPRACH-PROPAGATION"

    sudo log stream \
        --style compact \
        --level debug \
        --predicate '
            process == "eligibilityd"
            OR process == "assistantd"
            OR process == "generativeexperiencesd"
            OR process == "cfprefsd"
        ' \
        --timeout 60s \
        >"$PROPLOG" 2>&1 &

    LOGPID=$!

    post_language_notifications

    echo "Die bestehende eligibilityd-Instanz bleibt 15 Sekunden am Leben,"
    echo "damit assistantd / generativeexperiencesd / CFPrefs propagieren."

    for i in {15..1}; do
        printf "\rPropagation: %2d s " "$i"
        sleep 1
    done
    echo

    section "4. ELIGIBILITYD FRISCH STARTEN"

    if ! restart_eligibilityd; then
        echo "ABBRUCH: eligibilityd bekam keine neue PID."
        exit 3
    fi

    # Apple-Daemon darf fehlende Snapshots selbst regenerieren.
    sleep 2

    echo
    echo "Notifications an die frische Instanz ..."
    post_language_notifications

    echo "8 Sekunden Initialisierung ..."
    sleep 8

    if ! wait_for_snapshots; then
        echo
        echo "Hinweis: Mindestens ein Eligibility-Snapshot fehlt weiterhin."
        echo "Ein zweiter kontrollierter Fresh-Start folgt."
    fi

    echo
    echo "Status nach Versuch 1:"
    show_status

    if ! eligible_now; then
        section "5. ZWEITER KONTROLLIERTER FRESH-START"

        if ! restart_eligibilityd; then
            echo "ABBRUCH: Zweiter eligibilityd-Start fehlgeschlagen."
            exit 4
        fi

        sleep 2
        post_language_notifications
        sleep 8
        wait_for_snapshots || true

        echo
        echo "Status nach Versuch 2:"
        show_status
    fi

    if eligible_now; then
        RECOVERY_OK=1
    else
        section "RECOVERY NICHT ERFOLGREICH"

        echo "Die lokalen Eligibility-Werte konnten nicht vollständig"
        echo "auf den Zielzustand gebracht werden."
        echo
        echo "Snapshots:"
        ls -la "$ELIG" "$OSELIG" 2>&1 || true

        echo
        echo "Die Dateien werden NICHT manuell erfunden oder auf 4 editiert."
        echo "Sie dürfen ausschließlich von Apples eligibilityd erzeugt werden."

        echo
        echo "Relevante Logs:"
        sudo log show \
            --last 4m \
            --style compact \
            --info \
            --debug \
            --predicate '
                process == "eligibilityd"
                OR process == "assistantd"
                OR process == "generativeexperiencesd"
                OR process == "cfprefsd"
            ' \
            2>/dev/null \
            | grep -Ei \
              'language|linwood|eligib|recompute|darwin notification|AppleLanguage|AFLanguage|preferred|cfpref|started|MobileAsset|deviceNotCapable' \
            | tail -1800 || true

        exit 5
    fi
fi

section "6. DEUTSCHEN ENDZUSTAND HERSTELLEN"

finalize_german

echo
echo "Eligibility NACH deutschem Restore – ohne Language-Notification:"
show_status

if ! eligible_now; then
    echo
    echo "WARNUNG: Eligibility ist bereits beim lokalen Restore zurückgefallen."
    echo "Es werden keine weiteren Language-Notifications gesendet."
    exit 6
fi

section "7. SIRI AI UNTER DEUTSCH FRISCH STARTEN"

restart_siri_user_stack

# Erst jetzt, also nach deutschem globalem + per-App-Sprachzustand, öffnen.
open "$SIRI_APP" 2>/dev/null || true

echo
echo "Warte bis zu 120 Sekunden auf SiriAvailability ..."

AVAILABLE=0

for i in {1..120}; do
    if siri_available; then
        AVAILABLE=1
        break
    fi

    if (( i == 1 || i % 15 == 0 )); then
        echo
        echo "SiriAvailability nach ${i}s:"
        show_siri_availability
    fi

    printf "\rSiriAvailability: %3d / 120 s" "$i"
    sleep 1
done
echo

section "8. ENDERGEBNIS"

echo "AppleLanguages:"
defaults read -g AppleLanguages 2>&1

echo
echo "Siri-Sprache:"
defaults read \
    com.apple.assistant.backedup \
    "Session Language" 2>&1

echo
echo "Siri AI App-Lokalisierung:"
defaults read \
    com.apple.campo \
    AppleLanguages 2>&1

echo
echo "Eligibility:"
show_status

echo
echo "SiriAvailability:"
show_siri_availability

echo
echo "Eligibility-Snapshots:"
ls -la "$ELIG" "$OSELIG" 2>&1 || true

if (( RECOVERY_OK )) && (( AVAILABLE )); then
    echo
    echo "========================================================================"
    echo "ERFOLG: Siri AI ist freigeschaltet, Siri ist en-US,"
    echo "macOS/Siri-AI-UI sind auf Deutsch konfiguriert."
    echo "========================================================================"
elif (( RECOVERY_OK )); then
    echo
    echo "========================================================================"
    echo "LOKALE FREISCHALTUNG ERFOLGREICH."
    echo "SiriAvailability ist nach 120 Sekunden noch nicht vollständig bereit."
    echo "========================================================================"
    echo
    echo "In diesem Zustand KEINE PCC-/networkserviceproxy-Daemons neu starten."
    echo "Mac online und wach lassen. Apple-Assets/PCC/Privacy-Relay können nach"
    echo "einem Boot noch etwas Zeit benötigen."
fi

echo
echo "Nicht verändert wurden:"
echo "- SIP / /System"
echo "- WARP / Surge / DNS / VPN"
echo "- networkserviceproxy / privatecloudcomputed"
echo "- keine Eligibility-Antwort wurde manuell auf 4 editiert"

[[ -n "$LOGPID" ]] && wait "$LOGPID" 2>/dev/null || true
LOGPID=""

trap - EXIT INT TERM HUP
rm -rf "$TMP" 2>/dev/null || true

pause_end
