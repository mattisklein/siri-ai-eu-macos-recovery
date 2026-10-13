# Veröffentlichungsumfang und Prüfungen

Der öffentliche Stand wurde aus einer ausdrücklichen Dateiliste in einem neuen, separaten Staging-Verzeichnis aufgebaut. Die Forschungsordner und deren Git-History wurden nicht übernommen. Es wurde keine bestehende Forschungsdateiliste pauschal mit `git add .` importiert.

## Veröffentlichte Dateien

- `README.md`
- `LICENSE`
- `.gitignore`
- `START-HIER.txt`
- `Siri-AI-EU-Recovery.command`
- `docs/TECHNICAL.md`
- `docs/VALIDATION.md`

Die Release-Datei `Siri-AI-EU-Recovery-FINAL.zip` wird separat ausgeliefert. Sie enthält ausschließlich den Ordner `Siri-AI-EU-Recovery/` mit `Siri-AI-EU-Recovery.command` und `START-HIER.txt`. Beide Dateien stimmen bytegenau mit den Dateien des Repositories überein. `SHA256SUMS` im Release ermöglicht eine Integritätsprüfung:

```zsh
# Im Ordner mit beiden heruntergeladenen Release-Dateien:
shasum -a 256 -c SHA256SUMS
```

SHA-256 der unveränderten Recovery-Datei:

```text
6157720a53aae10fec8e4477f1ddb860fae8eb9d0eb4af4c37c425dfae2d4a8f
```

SHA-256 der unveränderten finalen ZIP:

```text
8e8542c3e5d6665ca1c6c5eb375730dfde9d43c69f5a32f1ea8551a9895cee01
```

## Syntax und Plausibilität

- `/bin/zsh -n Siri-AI-EU-Recovery.command` prüft die vollständige Shell-Syntax, ohne die Recovery auszuführen.
- Vollständige statische Durchsicht prüft Preflight, Privilegien, feste Preference-Ziele, lesende Eligibility-Zugriffe, Reihenfolge der Notifications, 15-Sekunden-Propagation, neue Daemon-PID und Abschlusskonfiguration.
- Eine lokale Prüfung bestätigt die relevanten Codeabschnitte und deren Reihenfolge sowie das Fehlen eines expliziten globalen Notification-Aufrufs nach dem Restore.
- Der eingebettete Swift/Foundation-Ausdruck wird separat typgeprüft, ohne die Recovery oder Preference-Änderungen auszuführen.
- Original, öffentliche Skriptkopie und ZIP-Inhalt werden bytegenau verglichen; ZIP-CRC und Member-Liste werden geprüft.

ShellCheck wurde nicht eingesetzt; das Skript verwendet zsh. Die Veröffentlichung führte die Recovery nicht erneut aus und änderte keine Systemeinstellungen. Der Funktionsnachweis auf macOS 27.0.1 / Build 26A434 stammt aus dem lokalen Projekt. Syntax- und Plausibilitätsprüfungen ersetzen keinen Test auf anderen Builds oder Macs.

## Privacy- und Secret-Prüfung

Alle geplanten öffentlichen Textdateien, die entpackten Release-Inhalte und die vollständige neue Git-History werden vor der Veröffentlichung kontrolliert. Die Prüfung kombiniert Gitleaks mit einer zusätzlichen Suche nach persönlichen Pfaden, lokaler Benutzer-/Git-Identität, E-Mail-Adressen, IP-Adressen, Geräte-/Accountkennungen, privaten Schlüsseln, Tokenmustern und Authentifizierungsdaten. Eine unabhängige manuelle Durchsicht ergänzt die automatischen Prüfungen.

Die ZIP-Prüfung umfasst auch Kommentare, Zusatzfelder, Ressource-Forks, unerwartete Mitglieder und nachgestellte Daten. Git-Dateiinhalte und ZIP-Mitglieder enthalten keine übernommenen erweiterten Dateiattribute. Lokale Quarantäne-Attribute wurden aus dem Staging entfernt; macOS kann dort weiterhin ein lokales Provenance-Attribut führen, das weder Git noch diese ZIP überträgt. Git-Blobs werden gegen die freigegebene Dateiliste geprüft; der öffentliche Stand beginnt mit einem neuen Root-Commit. Der Git-Autor verwendet ausschließlich den authentifizierten GitHub-Login und dessen ID-basierte GitHub-Noreply-Adresse. Globale private Git-Identitätswerte werden nicht übernommen.

Vor dem Push werden `git status`, der vollständige staged Diff, die Repository-Dateiliste, Secret-/Privacy-Ergebnisse und sämtliche erreichbaren Git-Objekte kontrolliert. Die Release-Notizen und Prüfsummendatei gehören ebenfalls zum geprüften Veröffentlichungsumfang. Automatische Musterprüfungen liefern keine universelle Garantie; die begrenzte Dateiliste und manuelle Kontrolle sind deshalb Teil des Verfahrens.

## Bewusst ausgeschlossen

Ausgeschlossen bleiben ältere und alternative Recovery-/Diagnoseskripte, Rohlogs, Terminal-Historien, vollständige Systemreports, Screenshots, Plist-Dumps, Account-/Geräteinformationen, persönliche Metadaten und die bestehende Forschungs-History. Ebenso ausgeschlossen sind Apple-Systemdateien, Apple-Binaries, Modelle und Assets. Lokale Audit-Artefakte und Laufzeitdiagnosen werden nicht veröffentlicht.

Die Recovery erzeugt bei späterer Nutzung eigene Desktop-Reports und Propagation-Logs. Diese können private Informationen enthalten und gehören auch nach einem erfolgreichen Lauf niemals ungeprüft in dieses Repository oder in öffentliche Issues.
