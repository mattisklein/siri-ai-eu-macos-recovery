# Siri AI EU macOS Recovery

**Sprache:** [English](README.md) | Deutsch

Eine lokale Recovery für Siri AI auf Apple-Silicon-Macs mit macOS 27.x in einem normalerweise nicht freigeschalteten Sprach-/Regionszustand. Der im Projekt reproduzierte Ablauf belässt Siri auf `en-US`, berechnet Eligibility vorübergehend mit Englisch als primärer Systemsprache und setzt macOS sowie die Siri-AI-Oberfläche anschließend auf Deutsch.

Die finale `Siri-AI-EU-Recovery.command` wird unverändert aus dem verifizierten Projektstand veröffentlicht. Das Repository enthält ausschließlich Skript und Dokumentation; persönliche Diagnosen und Forschungsdaten sind ausgeschlossen.

**Inoffizielles Community-Projekt, ohne Verbindung zu Apple.** Interne Dienste, Schlüssel und Benachrichtigungen können sich ändern. Für zukünftige macOS-Versionen oder andere Geräte-/Accountzustände gibt es keine Funktionsgarantie.

## Voraussetzungen und Kompatibilität

| Voraussetzung | Umfang |
| --- | --- |
| Hardware | Apple Silicon; das Skript verlangt `arm64` |
| Betriebssystem | macOS `27.x`; andere Hauptversionen werden abgewiesen |
| Im lokalen Projekt verifiziert | **macOS 27.0.1, Build 26A434** |
| System-App | `/System/Applications/Siri AI.app` muss bereits vorhanden sein |
| Berechtigungen | Angemeldeter macOS-Benutzer mit Zugriff auf `sudo` |
| Zielkonfiguration | macOS Deutsch, Siri `en-US`, Siri AI / `com.apple.campo` Deutsch |
| Foundation-Prüfung | Funktionierende Swift-Toolchain, falls `/usr/bin/swift` ausführbar vorhanden ist |

Der Preflight akzeptiert andere 27.x-Builds mit Hinweis. Diese wurden dadurch **nicht** verifiziert. Intel-Macs, andere Hauptversionen, andere Sprachkombinationen und abweichende Geräte-/Accountzustände sind nicht als kompatibel bestätigt. Das Skript installiert weder die System-App noch Modelle und garantiert keine Verfügbarkeit von Apples Cloud-Diensten.

Die Abschlusskonfiguration ist fest vorgegeben: `de-DE, en-US, en-DE`. Das Skript speichert und rekonstruiert keine beliebige vorherige Sprachkonfiguration. Notiere deine bisherigen Spracheinstellungen, wenn du später dorthin zurückkehren möchtest.

## Quick Start

Kurzanleitung: [Deutsch](START-HIER.txt) | [English](START-HERE.txt).

Die Auswahl der Anleitungssprache verändert keine Systemeinstellungen. Die Konsolenausgaben der Recovery bleiben deutsch; ihr fester Endzustand ist macOS/Siri AI auf Deutsch und Siri auf `en-US`.

1. Lade im Bereich [Releases](https://github.com/mattisklein/siri-ai-eu-macos-recovery/releases) die Datei `Siri-AI-EU-Recovery-FINAL.zip` herunter und entpacke sie in Downloads.
2. Lies das Skript und diese Hinweise, schließe laufende Siri-AI-Aufgaben und starte immer nur einen Recovery-Lauf.
3. Öffne Terminal und führe aus:

```zsh
chmod +x "$HOME/Downloads/Siri-AI-EU-Recovery/Siri-AI-EU-Recovery.command"
"$HOME/Downloads/Siri-AI-EU-Recovery/Siri-AI-EU-Recovery.command"
```

Nach `chmod` kannst du die `.command`-Datei auch im Finder doppelklicken. Liegt die Datei woanders, tippe `chmod +x ` mit Leerzeichen, ziehe sie aus dem Finder ins Terminal und drücke Enter. Beim Ausführen fragt das Skript die benötigten Administratorrechte selbst über `sudo` ab; bei der Passworteingabe werden keine Zeichen angezeigt.

**Starte die gesamte Datei als normaler angemeldeter Benutzer, ohne vorangestelltes `sudo`.** Benutzerpräferenzen und Diagnoseziele müssen zu diesem Benutzer gehören. Keine parallelen Läufe, kein Hintergrundjob und keine automatische Ausführung bei jedem Login.

Für einen geklonten oder als Source-ZIP entpackten Repository-Ordner gilt dort:

```zsh
chmod +x ./Siri-AI-EU-Recovery.command
./Siri-AI-EU-Recovery.command
```

macOS kann heruntergeladene Skripte einer Sicherheitsprüfung unterziehen. Prüfe Herkunft und Inhalt und nutze gegebenenfalls die reguläre macOS-Freigabe in den Systemeinstellungen. Dieses Projekt verlangt keine Deaktivierung von Gatekeeper oder SIP.

## Technischer Kern

Der Durchbruch war die Kombination aus **frischem CFPrefs-Zustand, etwa 15 Sekunden Sprach-Propagation und anschließendem Fresh-Start von `eligibilityd`**. Allein `AppleLanguages` zu ändern erwies sich im Projekt als unzureichend.

Das Skript setzt Siri auf `en-US`, aktiviert Generative Assistant und setzt `AppleLanguages` temporär exakt auf `en-US, de-DE`. Nach kontrolliertem Neuladen von `cfprefsd` prüft es, soweit die Toolchain verfügbar ist, die englische Sprache über Foundation. Es sendet `AppleLanguagePreferencesChangedNotification` und `AFLanguageCodeDidChangeDarwinNotification`, wartet 15 Sekunden ohne die bestehende `eligibilityd`-Instanz selbst zu beenden und startet diese erst danach frisch. Die neue Instanz erhält beide Notifications erneut und darf fehlende Snapshots selbst erzeugen.

Der geprüfte Zielzustand ist:

| Wert | Erwartet |
| --- | ---: |
| `GREYMATTER` | 4 |
| `AMERICIUM` | 4 |
| `SIRI_MODE` | 4 |
| `DEVICE_AND_SIRI_LANGUAGE_MATCH` (Ausgabe: `MATCH`) | 3 |
| `HAS_LINWOOD` | 3 |
| `LINWOOD_AVAILABILITY` | 1 |

Anschließend setzt das Skript macOS auf `de-DE, en-US, en-DE` und `com.apple.campo` auf `de-DE`; Siri bleibt `en-US`. **Nach diesem Restore sendet das Skript absichtlich keine globale Sprach-Notification mehr.** So wird keine erneute Eligibility-Berechnung mit Deutsch ausdrücklich angestoßen. Es lädt Siri-/IntelligenceFlow-Benutzerprozesse und Spotlight neu, öffnet Siri AI und prüft bis zu 120 Sekunden `SiriAvailability`.

Ist Eligibility bereits vollständig aktiv, entfällt die englische Neuberechnungsphase. Details, Wiederholungen und Fehlercodes stehen in [docs/TECHNICAL.de.md](docs/TECHNICAL.de.md).

## Neustarts und Grenzen

Nach einem normalen Neustart kann Eligibility zurückfallen. Führe die Recovery dann erneut aus. Es gibt keinen dauerhaften Patch und keine Garantie, dass der Zustand einen Reboot, eine spätere Neubewertung oder ein macOS-Update übersteht.

Lokale Eligibility und tatsächlich verfügbare Siri-/Cloud-Funktionen sind verschiedene Prüfungen. Ein lokaler Erfolg bedeutet keine Zusage für Modelle, Cloud-Antworten oder die Verfügbarkeit aller Siri-AI-Funktionen. Siri-Eingaben können bei der anschließenden Nutzung durch Apples Dienste verarbeitet werden; das Skript verändert deren Datenschutz- oder Netzwerkverhalten nicht.

## Troubleshooting

| Meldung / Zustand | Vorgehen |
| --- | --- |
| Apple Silicon, macOS 27.x oder System-App fehlen | Abbruch respektieren; keine Apple-App oder Systemdateien nachkopieren. |
| Keine Administratorrechte | Im angemeldeten Benutzerkonto Zugriff auf `sudo` prüfen. Nicht die gesamte Recovery als root starten. |
| Foundation-Prüfung schlägt fehl (Exit 2) | Swift-Toolchain prüfen, z. B. `xcrun --find swift`. Ein vorhandener `/usr/bin/swift`-Shim ohne funktionierende Toolchain kann scheitern. Nach dem Abbruch nur einen erneuten Lauf starten. |
| Keine neue `eligibilityd`-PID (Exit 3/4) | Den Lauf beenden lassen und den lokalen Report prüfen. Keine zusätzlichen Systemdienste auf Verdacht beenden. |
| Snapshots fehlen oder Zielwerte werden nicht erreicht (Exit 5) | Der Daemon erhält einen begrenzten zweiten Versuch. Danach lokal diagnostizieren; die Plists niemals manuell erzeugen oder Antworten auf 4 setzen. |
| Eligibility fällt beim deutschen Restore zurück (Exit 6) | Lauf beendet sich ohne weitere Sprach-Notifications; dieser Zustand ist für die konkrete Konfiguration nicht bestätigt. |
| Lokale Freischaltung erfolgreich, Siri noch nicht bereit | Mac online und wach lassen. Das Skript wartet bis zu 120 Sekunden; der Bereitschaftstest weist keine erfolgreiche Cloud-Anfrage nach. Keine PCC-/Netzwerk-Daemons neu starten. |
| Nach Reboot wieder deaktiviert | Recovery erneut als Benutzer ausführen. |
| Fenster schließt früh bei Fehler | Über Terminal starten und den lokalen Report lesen. Die Schlussausgabe und Fehlercodes beachten; Exit 0 allein bestätigt keinen erfolgreichen Cloud-Aufruf. |

Bei Signalen und Fehlern nach bestandenem Preflight versucht das Skript, die feste deutsche Abschlusskonfiguration herzustellen. Schreibfehler, harte Prozessabbrüche oder Stromausfall können diesen Versuch verhindern. Prüfe danach macOS- und Siri-Sprache manuell. Es gibt keine Instanzsperre; parallele Läufe können sich gegenseitig stören.

## Sicherheit und Datenschutz

Die Recovery verändert Benutzerpräferenzen und startet ausgewählte lokale Prozesse neu. Sie verändert ausdrücklich nicht SIP, `/System`, WARP, Surge, DNS/VPN, `networkserviceproxy`, `privatecloudcomputed` oder Apple-Modell-/Asset-Dateien. Eligibility-Antworten werden ausschließlich gelesen; fehlende Snapshots unter `/private/var/db/eligibilityd/` und `/private/var/db/os_eligibility/` erstellt Apples `eligibilityd` selbst.

Beim Ausführen entstehen lokale Dateien auf dem Desktop:

```text
Siri-AI-Post-Boot-<Zeitstempel>.txt
Siri-AI-Post-Boot-<Zeitstempel>-Propagation.log
```

Der Report enthält Diagnoseausgaben, im Fehlerfall auch gefilterte Systemlogs. Das Propagation-Log erfasst Debug-Ausgaben der beteiligten Dienste. **Diese Dateien können private Account-, Geräte-, Pfad- oder Laufzeitinformationen enthalten. Niemals ungeprüft in Issues, Kommentare oder öffentliche Repositories hochladen.** Die anfängliche `umask 077` beschränkt neue Dateien, ersetzt aber keine Inhaltsprüfung. Die Recovery lädt diese Dateien nicht hoch. Bei Fehlern kann der begrenzte Log-Stream bis zu seinem Timeout weiterlaufen; die Dateien verbleiben zur lokalen Diagnose.

Für Fehlermeldungen reichen normalerweise die Betriebssystemversion, der Build, der betroffene Schritt und die anonymisierten sechs Zielwerte. Entferne Namen, Benutzernamen, persönliche Pfade, Seriennummern, Apple-ID-/E-Mail-Daten, IPs, Tokens, Cookies und Authentifizierungsdaten. Keine Screenshots, kompletten Systemreports oder Plist-Dumps veröffentlichen.

Die `.gitignore` verwendet eine ausdrückliche Dateiliste. Neue Dateien müssen bewusst freigegeben und vor dem Commit geprüft werden. [docs/VALIDATION.de.md](docs/VALIDATION.de.md) beschreibt den Umfang der Veröffentlichung und ihrer Prüfungen.

## Lizenz und Disclaimer

Skript und Dokumentation stehen unter der [MIT-Lizenz](LICENSE). Apple-Software, Systemdateien, Binaries, Modelle und andere Apple-Assets sind nicht Bestandteil dieses Repositories und werden nicht mitlizenziert.

Nutzung auf eigene Verantwortung und ohne Gewährleistung. Das Projekt ist inoffiziell und stammt nicht von Apple. Die dokumentierten internen Namen und Zahlen beschreiben den beobachteten Projektstand; es handelt sich nicht um eine zugesicherte öffentliche Apple-API. Zukünftige macOS-Versionen können einen anderen internen Ablauf verwenden.
