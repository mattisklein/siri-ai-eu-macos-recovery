# Technischer Ablauf der Recovery

Diese Dokumentation beschreibt `Siri-AI-EU-Recovery.command`. Die Angaben zur erfolgreichen Aktivierung stammen aus dem lokalen Projekt: verifiziert wurde ein Apple-Silicon-Mac mit **macOS 27.0.1, Build 26A434** und vorhandener `/System/Applications/Siri AI.app`. Das ist ein berichteter Testzustand, keine unabhängige Bestätigung für sämtliche Macs, Regionen oder Sprachkombinationen.

Das Skript akzeptiert im Preflight macOS `27.x`. Diese Versionsprüfung erweitert den Kreis möglicher Versuche; sie belegt keine Kompatibilität weiterer Versionen oder Builds. Auf anderen Builds erscheint ein Hinweis und das Skript fährt fort. Apples interne Preference-Schlüssel, Notifications, Daemons und Statuswerte sind keine stabile öffentliche Schnittstelle.

## Was den erfolgreichen Ablauf auszeichnet

Im dokumentierten Versuch reichte es nicht, `AppleLanguages` allein zu ändern. Die erfolgreiche Reihenfolge kombinierte drei Schritte:

1. Die temporäre englische Sprachkonfiguration wurde mit neu geladenen `cfprefsd`-Prozessen für Preference-Leser sichtbar gemacht.
2. Nach den Sprach-Notifications blieb die bestehende `eligibilityd`-Instanz ungefähr **15 Sekunden** am Leben.
3. Erst anschließend wurde `eligibilityd` beendet und eine Instanz mit neuer PID abgewartet; diese erhielt die Notifications erneut.

Die Propagationsphase soll `assistantd`, `generativeexperiencesd` und CFPrefs Gelegenheit geben, die Sprachänderung zu verarbeiten. Das ist die aus den Beobachtungen abgeleitete Erklärung für die gewählte Reihenfolge. Das Projekt beweist damit weder eine bestimmte interne Apple-Implementierung noch, dass exakt 15 Sekunden unter allen Bedingungen ausreichen oder erforderlich sind. Eine neue PID bestätigt einen Prozesswechsel, aber nicht allein den Inhalt aller internen Caches.

## 1. Preflight und Berechtigungen

Das Skript prüft:

- `uname -m` muss `arm64` melden. Auch ein Apple-Silicon-Mac muss das Skript daher in einer nativen Umgebung ausführen.
- `sw_vers -productVersion` muss mit `27.` beginnen.
- `/System/Applications/Siri AI.app` muss als Verzeichnis vorhanden sein. Das Skript erzeugt oder installiert diese App nicht.
- `sudo -v` muss erfolgreich sein. Administratorrechte werden zum Lesen der geschützten Eligibility-Plists und zum kontrollierten Beenden von Systemprozessen benötigt.

Erst nach diesen Prüfungen wird der Abschluss-Handler zum Setzen der deutschen Konfiguration freigegeben. Bei einem frühen Preflight-Abbruch schreibt das Skript keine Spracheinstellungen. Lokale Report- und temporäre Dateien werden allerdings bereits vor dem Preflight angelegt.

Die `.command`-Datei soll als angemeldeter Benutzer gestartet werden, **nicht als vollständiges Skript mit `sudo`**. Die einzelnen privilegierten Aufrufe erfolgen innerhalb des Skripts. So beziehen sich die normalen `defaults`-Aufrufe auf den vorgesehenen Benutzer.

## 2. Zustand lesen und bereits aktive Geräte behandeln

Die Recovery liest ausgewählte Schlüssel aus zwei vorhandenen Snapshots:

```text
/private/var/db/eligibilityd/eligibility.plist
/private/var/db/os_eligibility/eligibility.plist
```

`PlistBuddy` wird dabei ausschließlich mit `Print` verwendet. Es gibt keine Befehle, die Eligibility-Antworten direkt verändern. Ein fehlender Snapshot wird als fehlender Zustand behandelt; die Recovery legt keinen Ersatz mit vorgegebenen Antworten an.

Für den lokalen Erfolg müssen alle sechs Prüfungen gleichzeitig passen:

| Ausgabebezeichnung | Snapshot / Domain / Schlüssel | Ziel |
| --- | --- | ---: |
| `GREYMATTER` | `eligibilityd`, `OS_ELIGIBILITY_DOMAIN_GREYMATTER`, `os_eligibility_answer_t` | `4` |
| `AMERICIUM` | `eligibilityd`, `OS_ELIGIBILITY_DOMAIN_AMERICIUM`, `os_eligibility_answer_t` | `4` |
| `SIRI_MODE` | `os_eligibility`, `OS_ELIGIBILITY_DOMAIN_SIRI_MODE`, `os_eligibility_answer_t` | `4` |
| `MATCH` | `eligibilityd`, GREYMATTER, `status:OS_ELIGIBILITY_INPUT_DEVICE_AND_SIRI_LANGUAGE_MATCH` | `3` |
| `HAS_LINWOOD` | `eligibilityd`, AMERICIUM, `status:OS_ELIGIBILITY_INPUT_HAS_LINWOOD` | `3` |
| `LINWOOD_AVAILABILITY` | `eligibilityd`, AMERICIUM, `context:OS_ELIGIBILITY_CONTEXT_LINWOOD_AVAILABILITY` | `1` |

Die beiden zusätzlich ausgegebenen `DEVICE_LANGUAGE`-Werte sind diagnostisch; `eligible_now()` verwendet sie nicht als Erfolgskriterium. Die Zahlen werden hier als beobachtete Zielwerte beschrieben. Ihre Namen allein erlauben keine verlässliche vollständige Interpretation der internen Apple-Enums.

Wenn bereits alle sechs Zielwerte vorliegen, überspringt das Skript die temporäre englische Phase, den CFPrefs-Neustart und die Eligibility-Neuberechnung. Es setzt trotzdem die unten beschriebene feste Abschlusskonfiguration, prüft den Zustand erneut und lädt die Siri-Benutzerprozesse neu.

## 3. Temporäre Sprachkonfiguration setzen

Wenn eine Neuberechnung nötig ist, wird Siri AI zunächst geschlossen. Danach setzt das Skript:

```text
com.apple.assistant.backedup / Session Language = en-US
com.apple.siri.generativeassistantsettings / isEnabled = true
NSGlobalDomain / AppleLanguages = [en-US, de-DE]
```

Die globale Liste enthält in dieser Phase **exakt** `en-US`, anschließend `de-DE`. Siri bleibt englisch. Die Reihenfolge ist Teil des reproduzierten Ablaufs. Die Recovery bietet keine allgemeine Auswahl für beliebige Sprachlisten oder andere Siri-Sprachen.

## 4. CFPrefs neu laden und Foundation prüfen

`refresh_preference_daemons()` beendet zunächst erreichbare `cfprefsd`-Prozesse mit `killall`, dann zusätzlich mit `sudo killall`. Anschließend wartet es **3 Sekunden** und zeigt die wieder vorhandenen Prozesse an. Die Recovery verändert keine Preference-Dateien des Systems direkt und schreibt keinen Cache von Hand.

Wenn `/usr/bin/swift` ausführbar vorhanden ist, startet das Skript einen kurzen Foundation-Test. Dieser gibt `Locale.preferredLanguages` und die bevorzugte Lokalisierung für die Kandidaten `en`, `de`, `fr`, `es`, `it` aus. Als bestanden gilt die Ausgabe, wenn entweder die Sprachliste mit `en-US` beginnt oder die bevorzugte Lokalisierung mit `en` beginnt.

Bei einem fehlgeschlagenen Test wird CFPrefs erneut geladen. Es gibt höchstens **drei Foundation-Versuche**. Sind sie erfolglos, endet der Aktivierungsdurchlauf mit Exit-Code `2`; der Abschluss-Handler versucht dann die deutsche Konfiguration zu setzen.

Fehlt eine ausführbare `/usr/bin/swift`, überspringt das Skript diese zusätzliche Prüfung. Eine erfolgreiche Recovery ohne diesen Test enthält deshalb keine direkte Foundation-Verifikation. Ein vorhandener Swift-Starter ohne funktionierende Toolchain kann dagegen fehlschlagen und zum Abbruch führen. Die Prüfung ist kein umfassender Nachweis für den Sprachzustand aller bereits laufenden Prozesse.

## 5. Notifications und 15 Sekunden Propagation

Das Skript startet einen lokalen Unified-Log-Stream für `eligibilityd`, `assistantd`, `generativeexperiencesd` und `cfprefsd` mit einer Laufzeit von bis zu 60 Sekunden. Danach sendet es über `notifyutil -p`:

```text
AppleLanguagePreferencesChangedNotification
AFLanguageCodeDidChangeDarwinNotification
```

Es wartet anschließend **15 Sekunden**, ohne selbst die bestehende `eligibilityd`-Instanz zu beenden. Dieser Abstand zwischen Preference-Änderung und Prozesswechsel ist ein wesentlicher Teil des dokumentierten erfolgreichen Ablaufs. Die Recovery kann nicht verhindern, dass das Betriebssystem einen Prozess in dieser Zeit aus anderen Gründen beendet.

## 6. Eligibility mit einer frischen Instanz berechnen lassen

`restart_eligibilityd()` ermittelt die erste von `pgrep -x eligibilityd` gemeldete PID und sendet ihr, sofern vorhanden, mit `sudo kill -TERM` ein Terminationssignal. Danach sucht es in Schritten von 0,25 Sekunden bis zu ungefähr **15 Sekunden** nach einer neuen, unterschiedlichen PID.

Fehlt eine neue PID weiterhin, sendet das Skript `AppleLanguagePreferencesChangedNotification` als im Projekt verwendetes LaunchEvent und sucht nochmals bis zu ungefähr 15 Sekunden. Es installiert keinen LaunchDaemon und ersetzt keine Apple-Binärdatei. Kommt keine neue PID zustande, bricht der erste Versuch mit Exit-Code `3` ab.

Nach erfolgreichem Prozesswechsel folgt diese Reihenfolge:

1. **2 Sekunden** warten.
2. Beide Sprach-Notifications erneut senden.
3. **8 Sekunden** Initialisierung abwarten.
4. Bis zu ungefähr **10 Sekunden** prüfen, ob beide Snapshot-Dateien vorhanden sind: maximal 20 Prüfungen mit jeweils 0,5 Sekunden Abstand.
5. Die ausgewählten Statuswerte lesen und alle sechs Zielwerte vergleichen.

Das Warten prüft die Existenz der Dateien, nicht einen Zeitstempel oder eine garantierte Neuschreibung aller Inhalte. Fehlende Snapshots darf **Apples `eligibilityd` selbst regenerieren**. Das Skript löscht keine Snapshots und schreibt weder Antworten auf `4` noch Statuswerte auf andere Zielzahlen.

Sind die sechs Zielwerte nach dem ersten Versuch nicht vollständig erreicht, folgt **genau ein zweiter kontrollierter Prozesswechsel** mit derselben Reihenfolge `2 Sekunden → Notifications → 8 Sekunden → Snapshot-Warten`. Eine erneute 15-Sekunden-Propagationsphase gibt es beim zweiten Versuch nicht.

Scheitert der zweite Prozesswechsel, folgt Exit-Code `4`. Bleibt der Zielzustand nach beiden Versuchen unvollständig, folgt Exit-Code `5`. In diesem Fall schreibt die Recovery zusätzlich ausgewählte lokale Diagnosen in ihren Report. Auch hier werden keine Eligibility-Antworten manuell ersetzt.

## 7. Feste deutsche Abschlusskonfiguration

Nach erfolgreicher lokaler Eligibility-Prüfung setzt `finalize_german()`:

```text
NSGlobalDomain / AppleLanguages = [de-DE, en-US, en-DE]
com.apple.assistant.backedup / Session Language = en-US
com.apple.siri.generativeassistantsettings / isEnabled = true
com.apple.campo / AppleLanguages = [de-DE]
```

Damit wird Deutsch als primäre globale Sprache konfiguriert, Siri bleibt `en-US`, und Siri AI / Campo erhält eine deutsche App-Lokalisierung. Die tatsächliche Darstellung bereits laufender anderer Apps kann einen späteren App-Neustart benötigen.

Der Begriff „Restore“ bezeichnet hier **diese feste Zielkonfiguration**. Das Skript sichert keine beliebige vorherige Sprachliste und stellt sie nicht automatisch wieder her. Auch der bereits aktive Fast Path setzt diesen Endzustand. Für ein anderes gewünschtes Sprachprofil ist das veröffentlichte Skript daher nicht unverändert geeignet.

Nach diesen Preference-Schreibvorgängen sendet das Skript **absichtlich keine weitere explizite globale Sprach-Notification**. Im dokumentierten Versuch blieb so der zuvor unter Englisch berechnete Eligibility-Zustand erhalten. Daraus folgt keine Garantie, dass Apple oder andere Prozesse keine spätere Neuberechnung auslösen können.

Unmittelbar nach dem Setzen der deutschen Konfiguration werden die sechs Eligibility-Werte erneut geprüft. Sind sie zurückgefallen, folgt Exit-Code `6`; das Skript sendet keine zusätzlichen Sprach-Notifications und öffnet Siri AI auf diesem Abbruchpfad nicht.

Der Abschluss-Handler versucht diese deutsche Konfiguration auch bei Fehlern nach bestandenem Preflight sowie bei `INT`, `TERM` und `HUP`. Das ist eine Best-Effort-Wiederherstellung. Fehlgeschlagene `defaults`-Schreibvorgänge, ein erzwungenes `SIGKILL`, Stromverlust oder andere Unterbrechungen können sie verhindern. Das Skript prüft nicht jeden einzelnen Schreibvorgang auf Erfolg und läuft mit `set +e`; es gibt keine absolute Wiederherstellungsgarantie.

## 8. Siri-Benutzerprozesse neu laden und Verfügbarkeit abwarten

Nach der deutschen Konfiguration und der erneuten Eligibility-Prüfung schließt das Skript Siri AI nochmals und beendet die erreichbaren Benutzerprozesse:

```text
intelligenceflowd
intelligencecontextd
siriactionsd
assistantd
Spotlight
```

Spotlight wird ebenfalls neu geladen, damit seine Oberfläche die deutsche Lokalisierung frisch übernehmen kann. Nach **4 Sekunden** wird die vorhandene Siri-AI-App geöffnet. Diese Prozessneustarts können laufende Siri-Interaktionen unterbrechen.

Danach prüft das Skript bis zu **120 Sekunden**, ob `com.apple.assistant.backedup / SiriAvailability` die Textdarstellung `isAvailable = 1;` enthält. Es zeigt dabei ausgewählte Verfügbarkeitsfelder an. Diese Prüfung ist vom lokalen Eligibility-Erfolg getrennt.

Wenn die Eligibility-Prüfung erfolgreich war, `SiriAvailability` aber nach 120 Sekunden noch nicht bereit ist, meldet das Skript eine erfolgreiche lokale Freischaltung mit weiterhin ausstehender Verfügbarkeit. Es erzwingt dafür **keinen eigenen Fehlercode**. Ein normaler Exit allein bestätigt deshalb weder eine einsatzbereite Siri-AI-Oberfläche noch einen erfolgreichen Test einer Cloud-Anfrage. Der Abschlusstext und die angezeigten Statuswerte müssen ebenfalls betrachtet werden.

## Exit-Codes und Abbruchpfade

| Code | Bedeutung |
| ---: | --- |
| `1` | Preflight fehlgeschlagen: Architektur, macOS-Version, vorhandene Siri-AI-App oder Administratorzugriff. |
| `2` | Die optionale, aber tatsächlich ausgeführte Foundation-Prüfung bestätigte Englisch auch nach drei Versuchen nicht. |
| `3` | Beim ersten Eligibility-Neustart wurde keine neue PID gefunden. |
| `4` | Beim zweiten Eligibility-Neustart wurde keine neue PID gefunden. |
| `5` | Der vollständige lokale Eligibility-Zielzustand wurde nach beiden Versuchen nicht erreicht. |
| `6` | Der Zielzustand fiel unmittelbar nach dem Setzen der deutschen Konfiguration zurück. |
| `130` | Der Signal-Handler wurde durch `INT`, `TERM` oder `HUP` ausgelöst. |

Im normalen Abschluss wartet das Skript auf den Log-Stream, entfernt sein temporäres Arbeitsverzeichnis und hält das Terminalfenster bis zur Eingabetaste offen. Die expliziten Fehlerpfade `2` bis `6` verlassen das Skript vorher; der EXIT-Handler übernimmt dabei die Best-Effort-Abschlusskonfiguration und das Aufräumen.

## Reboot und Grenzen der Aussage

Nach einem normalen Neustart kann Eligibility wieder zurückfallen. Die Recovery kann anschließend erneut ausgeführt werden. Sie ist keine dauerhafte Freischaltung über alle Neustarts, Systemupdates oder Apple-seitigen Änderungen hinweg.

Der beobachtete Zusammenhang zwischen Sprachkonfiguration, CFPrefs, Propagation und neuem `eligibilityd`-Prozess erklärt die gewählte Recovery-Reihenfolge. Das Skript besitzt keine Kontrolle über serverseitige Verfügbarkeit, Kontobedingungen, Asset-Bereitstellung oder spätere interne Neubewertungen. Es gibt keine Zusage, dass zukünftige macOS-Versionen dieselben Schlüssel oder denselben Ablauf verwenden.

## Änderungsumfang und private Diagnosen

Die Recovery schreibt die genannten Benutzer-Preferences, liest Eligibility-Snapshots, sendet lokale Notifications, beendet die beschriebenen Prozesse und öffnet die vorhandene Siri-AI-App. Sie verändert ausdrücklich nicht:

- SIP oder Dateien unter `/System`;
- WARP, Surge, DNS- oder VPN-Konfiguration;
- `networkserviceproxy` oder `privatecloudcomputed`;
- Apple-Modelle, Asset-Dateien oder Apple-Binärdateien;
- Eligibility-Antworten durch direktes Editieren.

Sie ist kein Netzwerk- oder Cloud-Proxy. Die anschließend geöffnete Apple-App kann im Rahmen ihrer normalen Funktion Netzwerkdienste verwenden.

Die Recovery erzeugt auf dem Desktop einen `Siri-AI-Post-Boot-<Zeitstempel>.txt`-Report und einen `Siri-AI-Post-Boot-<Zeitstempel>-Propagation.log`. Mit `umask 077` beschränkt sie die normalen Berechtigungen neu angelegter Dateien auf den ausführenden Benutzer. **Diese Dateien bleiben private Diagnosen und gehören nicht in das öffentliche Repository, Releases oder ungeprüfte GitHub-Issues.**

Reports können lokale Benutzerpfade und weitere personenbezogene oder gerätebezogene Inhalte enthalten. Unified Logs können trotz Prozessfilter zusätzliche private Daten enthalten. Das Skript anonymisiert die Reports nicht; Dateiberechtigungen sind keine Anonymisierung und verhindern auch keine Synchronisation durch eine vorhandene Desktop-Cloud-Sicherung. Für die öffentliche Dokumentation wurden keine Rohlogs, Account-Dumps oder Geräteberichte übernommen.

Das Projekt ist inoffiziell und stammt nicht von Apple. Die Lizenz dieses Repositorys betrifft seinen eigenen Code und seine Dokumentation; sie liefert keine Apple-Software, Modelle oder System-Assets mit.
