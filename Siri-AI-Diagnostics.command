#!/bin/zsh
# Siri AI Diagnostics for macOS 27.x
# Companion diagnostic for siri-ai-eu-macos-recovery
#
# Read-only with respect to system settings and Apple eligibility state.
# It does NOT write defaults, send language notifications, kill/restart daemons,
# edit eligibility plists, change SIP, modify /System, or touch network settings.
#
# Optional:
#   ./Siri-AI-Diagnostics.command --save
# Saves the same terminal output to a timestamped report on the Desktop.

set +e
setopt NO_NOMATCH

SAVE_REPORT=0
if [[ "${1:-}" == "--save" ]]; then
  SAVE_REPORT=1
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--save]"
  exit 64
fi

STAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT="$HOME/Desktop/Siri-AI-Diagnostics-${STAMP}.txt"

if (( SAVE_REPORT )); then
  umask 077
  exec > >(tee -a "$REPORT") 2>&1
fi

ELIG="/private/var/db/eligibilityd/eligibility.plist"
OSELIG="/private/var/db/os_eligibility/eligibility.plist"
SIRI_APP="/System/Applications/Siri AI.app"
TMP="$(mktemp -d /tmp/siriai-diagnostics.XXXXXX)"
ELIG_READ="$TMP/eligibility.plist"
OSELIG_READ="$TMP/os_eligibility.plist"

cleanup() {
  rm -rf "$TMP" 2>/dev/null || true
}
trap cleanup EXIT INT TERM HUP

section() {
  echo
  echo "========================================================================"
  echo "$1"
  echo "========================================================================"
}

read_default() {
  local domain="$1" key="$2"
  /usr/bin/defaults read "$domain" "$key" 2>/dev/null
}

read_global() {
  local key="$1"
  /usr/bin/defaults read -g "$key" 2>/dev/null
}

SUDO_OK=0
ensure_read_access() {
  if sudo -n true 2>/dev/null; then
    SUDO_OK=1
    return 0
  fi

  echo
  echo "Für die geschützten Eligibility-Snapshots sind Administratorrechte nötig."
  echo "Es werden ausschließlich lesende Zugriffe verwendet."
  if sudo -v; then
    SUDO_OK=1
    return 0
  fi

  echo "Hinweis: Kein sudo-Zugriff. Geschützte Eligibility-Werte werden übersprungen."
  return 1
}

copy_snapshot_readonly() {
  local source="$1" destination="$2"

  [[ -f "$source" ]] || return 1

  if (( SUDO_OK )); then
    sudo /bin/cat "$source" > "$destination" 2>/dev/null
  else
    /bin/cat "$source" > "$destination" 2>/dev/null
  fi

  [[ -s "$destination" ]]
}

plist_print() {
  local plist="$1" keypath="$2" buddy_path="$3"
  local out=""

  [[ -f "$plist" ]] || {
    echo "?"
    return 1
  }

  out="$(/usr/bin/plutil -extract "$keypath" raw -o - "$plist" 2>/dev/null)"
  if [[ -n "$out" ]]; then
    echo "$out"
    return 0
  fi

  out="$(/usr/libexec/PlistBuddy -c "Print :${buddy_path}" "$plist" 2>/dev/null)"
  if [[ -n "$out" ]]; then
    echo "$out"
    return 0
  fi

  echo "?"
  return 1
}

read_answer() {
  local plist="$1" domain="$2"
  plist_print \
    "$plist" \
    "${domain}.os_eligibility_answer_t" \
    "${domain}:os_eligibility_answer_t"
}

read_status() {
  local plist="$1" domain="$2" key="$3"
  plist_print \
    "$plist" \
    "${domain}.status.${key}" \
    "${domain}:status:${key}"
}

read_context() {
  local plist="$1" domain="$2" key="$3"
  plist_print \
    "$plist" \
    "${domain}.context.${key}" \
    "${domain}:context:${key}"
}

process_state() {
  local name="$1"
  local lines
  lines="$(pgrep -fl "$name" 2>/dev/null)"
  if [[ -n "$lines" ]]; then
    echo "RUNNING  $name"
    echo "$lines" | sed 's/^/         /'
  else
    echo "STOPPED  $name"
  fi
}

section "SIRI AI DIAGNOSTICS – SYSTEM"

VERSION="$(sw_vers -productVersion 2>/dev/null)"
BUILD="$(sw_vers -buildVersion 2>/dev/null)"
ARCH="$(uname -m 2>/dev/null)"

echo "Zeit:             $(date)"
echo "macOS:            ${VERSION:-?}"
echo "Build:            ${BUILD:-?}"
echo "Architektur:      ${ARCH:-?}"
echo "Siri AI.app:      $([[ -d "$SIRI_APP" ]] && echo vorhanden || echo FEHLT)"

if [[ "$ARCH" != "arm64" ]]; then
  echo "Bewertung: Apple Silicon wurde nicht erkannt."
fi

if [[ "$VERSION" != 27.* ]]; then
  echo "Bewertung: Dieses Diagnoseprofil ist für macOS 27.x ausgelegt."
fi

if [[ "$BUILD" == "26A434" ]]; then
  echo "Recovery-Build:   exakt der öffentlich verifizierte Referenz-Build 26A434"
else
  echo "Recovery-Build:   anderer Build als der verifizierte Referenz-Build 26A434"
fi

section "SPRACH- UND FEATURE-ZUSTAND"

echo "AppleLanguages:"
read_global AppleLanguages || echo "<nicht lesbar>"

echo
echo "Siri Session Language:"
read_default com.apple.assistant.backedup "Session Language" || echo "<nicht gesetzt / nicht lesbar>"

echo
echo "Siri AI / Campo AppleLanguages:"
read_default com.apple.campo AppleLanguages || echo "<nicht gesetzt / nicht lesbar>"

echo
echo "Generative Assistant isEnabled:"
read_default com.apple.siri.generativeassistantsettings isEnabled || echo "<nicht gesetzt / nicht lesbar>"

section "FOUNDATION-SPRACHWAHRNEHMUNG"

if [[ -x /usr/bin/swift ]]; then
  /usr/bin/swift -e '
import Foundation
print("Locale.preferredLanguages =", Locale.preferredLanguages)
let candidates = ["en", "de", "fr", "es", "it", "ja", "ko", "pt"]
print("preferredLocalizations =", Bundle.preferredLocalizations(from: candidates, forPreferences: Locale.preferredLanguages))
' 2>/dev/null || echo "Swift/Foundation-Test konnte nicht ausgeführt werden."
else
  echo "Swift nicht verfügbar; zusätzliche Foundation-Prüfung übersprungen."
fi

section "ELIGIBILITY-SNAPSHOTS"

ensure_read_access || true

echo "eligibilityd snapshot:"
if [[ -f "$ELIG" ]]; then
  ls -l "$ELIG" 2>/dev/null || true
else
  echo "FEHLT: $ELIG"
fi

echo
echo "os_eligibility snapshot:"
if [[ -f "$OSELIG" ]]; then
  ls -l "$OSELIG" 2>/dev/null || true
else
  echo "FEHLT: $OSELIG"
fi

if ! copy_snapshot_readonly "$ELIG" "$ELIG_READ"; then
  rm -f "$ELIG_READ" 2>/dev/null || true
  echo "Hinweis: eligibilityd-Snapshot konnte nicht in den privaten Diagnosebereich gelesen werden."
fi

if ! copy_snapshot_readonly "$OSELIG" "$OSELIG_READ"; then
  rm -f "$OSELIG_READ" 2>/dev/null || true
  echo "Hinweis: os_eligibility-Snapshot konnte nicht in den privaten Diagnosebereich gelesen werden."
fi

GREYMATTER="$(read_answer "$ELIG_READ" OS_ELIGIBILITY_DOMAIN_GREYMATTER)"
AMERICIUM="$(read_answer "$ELIG_READ" OS_ELIGIBILITY_DOMAIN_AMERICIUM)"
SIRI_MODE="$(read_answer "$OSELIG_READ" OS_ELIGIBILITY_DOMAIN_SIRI_MODE)"
MATCH="$(read_status "$ELIG_READ" OS_ELIGIBILITY_DOMAIN_GREYMATTER OS_ELIGIBILITY_INPUT_DEVICE_AND_SIRI_LANGUAGE_MATCH)"
HAS_LINWOOD="$(read_status "$ELIG_READ" OS_ELIGIBILITY_DOMAIN_AMERICIUM OS_ELIGIBILITY_INPUT_HAS_LINWOOD)"
LINWOOD_AVAILABILITY="$(read_context "$ELIG_READ" OS_ELIGIBILITY_DOMAIN_AMERICIUM OS_ELIGIBILITY_CONTEXT_LINWOOD_AVAILABILITY)"
GREYMATTER_DEVICE_LANGUAGE="$(read_status "$ELIG_READ" OS_ELIGIBILITY_DOMAIN_GREYMATTER OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE)"
AMERICIUM_DEVICE_LANGUAGE="$(read_status "$ELIG_READ" OS_ELIGIBILITY_DOMAIN_AMERICIUM OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE)"

printf "%-28s %s\n" "GREYMATTER" "${GREYMATTER:-?}"
printf "%-28s %s\n" "AMERICIUM" "${AMERICIUM:-?}"
printf "%-28s %s\n" "SIRI_MODE" "${SIRI_MODE:-?}"
printf "%-28s %s\n" "MATCH" "${MATCH:-?}"
printf "%-28s %s\n" "HAS_LINWOOD" "${HAS_LINWOOD:-?}"
printf "%-28s %s\n" "LINWOOD_AVAILABILITY" "${LINWOOD_AVAILABILITY:-?}"
printf "%-28s %s\n" "GREYMATTER DEVICE_LANGUAGE" "${GREYMATTER_DEVICE_LANGUAGE:-?}"
printf "%-28s %s\n" "AMERICIUM DEVICE_LANGUAGE" "${AMERICIUM_DEVICE_LANGUAGE:-?}"

ELIGIBLE=0
ELIGIBILITY_READABLE=1

for value in \
  "$GREYMATTER" \
  "$AMERICIUM" \
  "$SIRI_MODE" \
  "$MATCH" \
  "$HAS_LINWOOD" \
  "$LINWOOD_AVAILABILITY"
do
  [[ -z "$value" || "$value" == "?" ]] && ELIGIBILITY_READABLE=0
done

if [[ "$GREYMATTER" == "4" \
   && "$AMERICIUM" == "4" \
   && "$SIRI_MODE" == "4" \
   && "$MATCH" == "3" \
   && "$HAS_LINWOOD" == "3" \
   && "$LINWOOD_AVAILABILITY" == "1" ]]; then
  ELIGIBLE=1
fi

section "SIRI AVAILABILITY"

SIRI_AVAIL="$(read_default com.apple.assistant.backedup SiriAvailability)"
if [[ -n "$SIRI_AVAIL" ]]; then
  echo "$SIRI_AVAIL" \
    | grep -E 'linwoodCapabilities|saeCapabilities|currentOrchestrationMode|desiredOrchestrationMode|desiredOrchestrationModeIfEnabled|isAvailable|linwoodEverAvailable|restrictionReasons|siriLocale|unavailabilityReasons' \
    || echo "$SIRI_AVAIL"
else
  echo "SiriAvailability ist nicht gesetzt oder nicht lesbar."
fi

AVAILABLE=0
if echo "$SIRI_AVAIL" | grep -Eq 'isAvailable = 1;'; then
  AVAILABLE=1
fi

section "RELEVANTE PROZESSE"

for p in \
  eligibilityd \
  assistantd \
  intelligenceflowd \
  intelligencecontextd \
  siriactionsd \
  generativeexperiencesd \
  cfprefsd
 do
  process_state "$p"
 done

section "ZUSAMMENFASSUNG"

if (( ELIGIBLE )) && (( AVAILABLE )); then
  echo "STATUS: LOKAL FREIGESCHALTET UND SIRIAVAILABILITY BEREIT"
  echo "Die sechs beobachteten Eligibility-Zielwerte stimmen und isAvailable = 1."
  echo "Das beweist keine erfolgreiche Cloud-/PCC-Anfrage, ist aber der stärkste lokale Zustand."
elif (( ELIGIBLE )); then
  echo "STATUS: LOKALE ELIGIBILITY AKTIV, SIRIAVAILABILITY NOCH NICHT BEREIT"
  echo "Die sechs Eligibility-Zielwerte stimmen, aber isAvailable = 1 wurde nicht erkannt."
  echo "Mögliche Ursachen liegen danach eher bei Asset-/Dienst-/Account-/Cloud-Bereitschaft als bei Eligibility."
elif (( ! ELIGIBILITY_READABLE )) && (( AVAILABLE )); then
  echo "STATUS: SIRIAVAILABILITY BEREIT; ELIGIBILITY-SNAPSHOTS NICHT VOLLSTÄNDIG AUSLESBAR"
  echo "isAvailable = 1 wurde erkannt, die sechs Snapshot-Zielwerte konnten aber nicht vollständig verifiziert werden."
  echo "Das ist kein negativer Eligibility-Nachweis; prüfe die Hinweise im Abschnitt ELIGIBILITY-SNAPSHOTS."
else
  echo "STATUS: ELIGIBILITY-ZIELZUSTAND NICHT VOLLSTÄNDIG"
  echo "Mindestens einer der sechs im Recovery-Projekt beobachteten Zielwerte weicht ab."
fi

echo
GEN_ENABLED="$(read_default com.apple.siri.generativeassistantsettings isEnabled)"
SIRI_LANG="$(read_default com.apple.assistant.backedup "Session Language")"
CAMPO_LANGS="$(read_default com.apple.campo AppleLanguages)"
GLOBAL_LANGS="$(read_global AppleLanguages)"

echo "Konfigurationshinweise:"
[[ "$SIRI_LANG" == "en-US" ]] \
  && echo "  ✓ Siri Session Language = en-US" \
  || echo "  ! Siri Session Language ist nicht en-US: ${SIRI_LANG:-<leer>}"

[[ "$GEN_ENABLED" == "1" ]] \
  && echo "  ✓ Generative Assistant ist aktiviert" \
  || echo "  ! Generative Assistant isEnabled ist nicht 1: ${GEN_ENABLED:-<leer>}"

echo "$GLOBAL_LANGS" | grep -q 'de-DE' \
  && echo "  ✓ de-DE ist in AppleLanguages vorhanden" \
  || echo "  ! de-DE wurde in AppleLanguages nicht erkannt"

echo "$CAMPO_LANGS" | grep -q 'de-DE' \
  && echo "  ✓ Siri AI / Campo ist auf de-DE lokalisiert" \
  || echo "  ! Siri AI / Campo de-DE wurde nicht erkannt"

section "DATENSCHUTZ / VERHALTEN"

echo "Dieses Skript hat keine Einstellungen verändert, keine Daemons beendet,"
echo "keine Notifications gesendet und keine Eligibility-Dateien editiert."
echo "Für die Auswertung werden höchstens private temporäre Lesekopien der Snapshots erzeugt"
echo "und beim Beenden wieder gelöscht. Es führt keine Netzwerk- oder Cloud-Anfrage aus."
echo "Ein mit --save erzeugter Report kann Geräte-/Laufzeitinformationen enthalten;"
echo "vor öffentlichem Teilen immer prüfen und sensible Angaben entfernen."

if (( SAVE_REPORT )); then
  echo
echo "Report gespeichert unter:"
  echo "$REPORT"
fi

exit 0
