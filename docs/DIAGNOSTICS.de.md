# Siri AI Diagnostics

**Sprache:** [English](DIAGNOSTICS.md) | Deutsch

Zurück zur [Projektübersicht](../README.de.md).

`Siri-AI-Diagnostics.command` ist ein ergänzendes, rein diagnostisches Skript für macOS 27.x. Es verändert keine Siri-, Sprach- oder Eligibility-Einstellungen und startet keine Dienste neu.

## Was geprüft wird

Das Skript zeigt unter anderem:

- macOS-Version, Build und Architektur
- Vorhandensein von `/System/Applications/Siri AI.app`
- globale `AppleLanguages`
- Siri `Session Language`
- Siri-AI-/Campo-Lokalisierung
- `Generative Assistant isEnabled`
- Foundation-Sprachwahrnehmung
- die bekannten Eligibility-Zielwerte aus `eligibilityd` und `os_eligibility`
- `SiriAvailability`, Orchestration Mode sowie Restriction-/Unavailability-Gründe
- Status relevanter Prozesse wie `eligibilityd`, `assistantd`, `intelligenceflowd`, `intelligencecontextd`, `siriactionsd` und `generativeexperiencesd`

## Ausführen

```zsh
chmod +x ./Siri-AI-Diagnostics.command
./Siri-AI-Diagnostics.command
```

Optional kann die Ausgabe in einen lokalen Desktop-Report geschrieben werden:

```zsh
./Siri-AI-Diagnostics.command --save
```

Der Report kann Geräte-, Benutzerpfad- oder Laufzeitinformationen enthalten und sollte vor einer Veröffentlichung immer geprüft und anonymisiert werden.

## Lesender Zugriff auf Eligibility

Die Eligibility-Snapshots liegen unter:

```text
/private/var/db/eligibilityd/eligibility.plist
/private/var/db/os_eligibility/eligibility.plist
```

Für deren Inhalt kann `sudo` erforderlich sein. Das Diagnose-Skript kopiert die Dateien ausschließlich lesend in ein privates temporäres Verzeichnis, wertet die Kopien mit `plutil` bzw. `PlistBuddy` aus und löscht sie beim Beenden wieder. Es schreibt weder in die Originaldateien noch in deren Kopien.

Das Skript verwendet keine `defaults write`-Befehle, keine Language-Notifications und beendet oder startet keine Siri-/Eligibility-Daemons.

## Interpretation

Der stärkste lokale Zustand ist:

- die sechs im Recovery-Projekt beobachteten Eligibility-Zielwerte stimmen,
- `SiriAvailability` enthält `isAvailable = 1`,
- keine lokalen Restriction-/Unavailability-Gründe werden gemeldet.

Das bestätigt jedoch nicht, dass eine konkrete Cloud-/PCC-Anfrage erfolgreich war oder dass jede Siri-AI-Funktion serverseitig verfügbar ist.

Wenn die Eligibility-Werte nicht lesbar sind, `isAvailable = 1` aber vorhanden ist, meldet die Diagnose dies ausdrücklich als unvollständige Verifikation und nicht als negativen Eligibility-Nachweis.
