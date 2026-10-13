# Siri AI EU macOS Recovery

**Language:** English | [Deutsch](README.de.md)

A local recovery for Siri AI on Apple Silicon Macs running macOS 27.x in a language/region configuration that is normally ineligible. The procedure reproduced in this project keeps Siri on `en-US`, temporarily recalculates eligibility with English as the primary system language, and then sets macOS and the Siri AI interface to German.

The final `Siri-AI-EU-Recovery.command` is published unchanged from the verified project version. This repository contains only the script and documentation; personal diagnostics and research data are excluded.

**Unofficial community project, unaffiliated with Apple.** Internal services, keys, and notifications may change. There is no guarantee that this procedure will work on future macOS versions or different device/account configurations.

## Requirements and compatibility

| Requirement | Scope |
| --- | --- |
| Hardware | Apple Silicon; the script requires `arm64` |
| Operating system | macOS `27.x`; other major versions are rejected |
| Verified in the local project | **macOS 27.0.1, build 26A434** |
| System app | `/System/Applications/Siri AI.app` must already exist |
| Permissions | Signed-in macOS user with access to `sudo` |
| Final configuration | macOS in German, Siri on `en-US`, Siri AI / `com.apple.campo` in German |
| Foundation check | Working Swift toolchain if an executable `/usr/bin/swift` is present |

Preflight accepts other 27.x builds with a notice. This does **not** verify their compatibility. Intel Macs, other major versions, other language combinations, and different device/account configurations have not been confirmed compatible. The script installs neither the system app nor models and does not guarantee availability of Apple's cloud services.

The final language list is fixed: `de-DE, en-US, en-DE`. The script does not save and reconstruct an arbitrary previous language configuration. Record your current language settings if you want to return to them later.

## Quick start

Short instructions: [English](START-HERE.txt) | [Deutsch](START-HIER.txt).

Choosing a guide language does not change any system settings. The recovery's console messages remain in German; its fixed final configuration is macOS/Siri AI in German and Siri on `en-US`.

1. Download `Siri-AI-EU-Recovery-FINAL.zip` from [Releases](https://github.com/mattisklein/siri-ai-eu-macos-recovery/releases) and extract it into Downloads.
2. Read the script and these notes, finish any active Siri AI tasks, and run only one recovery instance at a time.
3. Open Terminal and run:

```zsh
chmod +x "$HOME/Downloads/Siri-AI-EU-Recovery/Siri-AI-EU-Recovery.command"
"$HOME/Downloads/Siri-AI-EU-Recovery/Siri-AI-EU-Recovery.command"
```

After `chmod`, you can also double-click the `.command` file in Finder. If the file is elsewhere, type `chmod +x ` with a trailing space, drag the file from Finder into Terminal, and press Enter. The script requests the administrator permissions it needs through `sudo`; no characters appear while you enter your password.

**Start the entire script as your normal signed-in user, without prefixing it with `sudo`.** User preferences and diagnostic destinations must belong to that user. Do not run parallel instances, background jobs, or an automatic recovery at every login.

Inside a cloned repository or an extracted source ZIP, use:

```zsh
chmod +x ./Siri-AI-EU-Recovery.command
./Siri-AI-EU-Recovery.command
```

macOS may apply security checks to downloaded scripts. Check their origin and contents and, if necessary, use the normal macOS approval in System Settings. This project does not require disabling Gatekeeper or SIP.

## Technical overview

The breakthrough was the combination of **fresh CFPrefs state, about 15 seconds of language propagation, and a subsequent fresh start of `eligibilityd`**. Merely changing `AppleLanguages` proved insufficient in this project.

The script sets Siri to `en-US`, enables Generative Assistant, and temporarily sets `AppleLanguages` to exactly `en-US, de-DE`. After a controlled reload of `cfprefsd`, it checks the English language state through Foundation when the toolchain is available. It sends `AppleLanguagePreferencesChangedNotification` and `AFLanguageCodeDidChangeDarwinNotification`, waits 15 seconds without itself terminating the existing `eligibilityd` instance, and only then starts a fresh instance. The new instance receives both notifications again and may regenerate missing snapshots itself.

The checked target state is:

| Value | Expected |
| --- | ---: |
| `GREYMATTER` | 4 |
| `AMERICIUM` | 4 |
| `SIRI_MODE` | 4 |
| `DEVICE_AND_SIRI_LANGUAGE_MATCH` (shown as `MATCH`) | 3 |
| `HAS_LINWOOD` | 3 |
| `LINWOOD_AVAILABILITY` | 1 |

The script then sets macOS to `de-DE, en-US, en-DE` and `com.apple.campo` to `de-DE`; Siri remains on `en-US`. **After this restore, the script deliberately sends no further global language notification.** This avoids explicitly triggering another eligibility calculation with German. It reloads Siri/IntelligenceFlow user processes and Spotlight, opens Siri AI, and checks `SiriAvailability` for up to 120 seconds.

If eligibility is already fully active, the English recalculation phase is skipped. See [docs/TECHNICAL.md](docs/TECHNICAL.md) for details, retries, and error codes.

## Reboots and limitations

Eligibility may revert after a normal reboot. Run the recovery again if this happens. There is no permanent patch and no guarantee that the state survives a reboot, later reevaluation, or macOS update.

Local eligibility and actual Siri/cloud availability are separate checks. Local success does not guarantee models, cloud responses, or availability of all Siri AI features. When you subsequently use Siri, your requests may be processed by Apple's services; the script does not change their privacy or network behavior.

## Troubleshooting

| Message / state | What to do |
| --- | --- |
| Apple Silicon, macOS 27.x, or the system app is missing | Respect the abort; do not copy in an Apple app or system files. |
| No administrator permissions | Check `sudo` access in your signed-in account. Do not start the entire recovery as root. |
| Foundation check fails (exit 2) | Check the Swift toolchain, for example with `xcrun --find swift`. A present `/usr/bin/swift` shim without a working toolchain can fail. Start only one new run after the abort. |
| No new `eligibilityd` PID (exit 3/4) | Let the run finish and inspect the local report. Do not terminate additional system services speculatively. |
| Snapshots are missing or target values are not reached (exit 5) | The daemon gets one limited second attempt. Then diagnose locally; never create the plists manually or set answers to 4. |
| Eligibility reverts during the German restore (exit 6) | The run ends without further language notifications; this state is not confirmed for the particular configuration. |
| Local recovery succeeds, but Siri is not ready | Keep the Mac online and awake. The script waits up to 120 seconds; the readiness check does not prove a successful cloud request. Do not restart PCC/network daemons. |
| Disabled again after reboot | Run the recovery again as your normal user. |
| Window closes early on an error | Start through Terminal and read the local report. Check the final message and error codes; exit 0 alone does not confirm a successful cloud request. |

After signals and errors following successful preflight, the script attempts to apply its fixed German final configuration. Failed writes, forced process termination, or power loss can prevent that attempt from succeeding. Check the macOS and Siri language settings manually afterwards. There is no instance lock; parallel runs can interfere with each other.

## Security and privacy

The recovery changes user preferences and restarts selected local processes. It does not change SIP, `/System`, WARP, Surge, DNS/VPN, `networkserviceproxy`, `privatecloudcomputed`, or Apple model/asset files. Eligibility answers are only read; Apple's `eligibilityd` generates missing snapshots under `/private/var/db/eligibilityd/` and `/private/var/db/os_eligibility/` itself.

Running the script creates local files on your Desktop:

```text
Siri-AI-Post-Boot-<timestamp>.txt
Siri-AI-Post-Boot-<timestamp>-Propagation.log
```

The report contains diagnostic output and, on failure, filtered system logs. The propagation log captures debug output from the involved services. **These files may contain private account, device, path, or runtime information. Never upload them to issues, comments, or public repositories without reviewing and sanitizing them.** The initial `umask 077` restricts newly created files but does not replace a content review. The recovery does not upload these files. On errors, the bounded log stream may continue until its timeout; files remain available for local diagnosis.

For error reports, the operating system version, build, affected step, and six anonymized target values usually suffice. Remove names, local usernames, personal paths, serial numbers, Apple ID/email data, IP addresses, tokens, cookies, and authentication data. Do not publish screenshots, complete system reports, or plist dumps.

The `.gitignore` uses an explicit file allowlist. New files must be deliberately allowed and reviewed before committing. [docs/VALIDATION.md](docs/VALIDATION.md) describes the publication scope and checks.

## License and disclaimer

The script and documentation are available under the [MIT license](LICENSE). Apple software, system files, binaries, models, and other Apple assets are not part of this repository and are not covered by its license.

Use at your own risk, without warranty. This is an unofficial project and does not come from Apple. The documented internal names and numbers describe the observed project state, not a guaranteed public Apple API. Future macOS versions may use a different internal procedure.
