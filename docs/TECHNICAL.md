# Technical recovery flow

**Language:** English | [Deutsch](TECHNICAL.de.md)

[Back to the README](../README.md)

Switching the documentation language changes only the guide. The recovery's fixed final configuration remains German for macOS and Siri AI / Campo, with `en-US` for Siri.

This document describes `Siri-AI-EU-Recovery.command`. The successful activation results come from the local project: verification was performed on an Apple Silicon Mac running **macOS 27.0.1, build 26A434**, with `/System/Applications/Siri AI.app` present. This is a reported test configuration, rather than independent confirmation for every Mac, region or language combination.

The script accepts macOS `27.x` during preflight. This version check allows attempts on a wider range of versions; it does not establish compatibility with other versions or builds. On other builds, the script displays a notice and continues. Apple's internal preference keys, notifications, daemons and status values are not a stable public interface.

## What made the documented flow successful

In the documented test, changing `AppleLanguages` alone was insufficient. The successful sequence combined three steps:

1. Reloaded `cfprefsd` processes made the temporary English language configuration visible to preference readers.
2. After the language notifications, the existing `eligibilityd` instance remained alive for approximately **15 seconds**.
3. Only then was `eligibilityd` terminated and an instance with a new PID awaited; this instance received the notifications again.

The propagation phase is intended to give `assistantd`, `generativeexperiencesd` and CFPrefs time to process the language change. This explanation for the chosen order is inferred from the observations. The project does not prove a specific internal Apple implementation, or that exactly 15 seconds is sufficient or necessary under all conditions. A new PID confirms a process change, but does not by itself establish the contents of every internal cache.

## 1. Preflight and permissions

The script checks:

- `uname -m` must report `arm64`. An Apple Silicon Mac therefore also needs to run the script in a native environment.
- `sw_vers -productVersion` must start with `27.`.
- `/System/Applications/Siri AI.app` must exist as a directory. The script does not create or install this app.
- `sudo -v` must succeed. Administrator privileges are needed to read the protected eligibility plists and terminate system processes in a controlled manner.

Only after these checks is the finalization handler allowed to set the German configuration. If preflight stops early, the script does not write language preferences. However, local report and temporary files are created before preflight.

Run the `.command` file as the signed-in user, **not by running the entire script with `sudo`**. Individual privileged calls take place inside the script. This ensures that the ordinary `defaults` calls apply to the intended user.

## 2. Read the state and handle devices that are already eligible

The recovery reads selected keys from two existing snapshots:

```text
/private/var/db/eligibilityd/eligibility.plist
/private/var/db/os_eligibility/eligibility.plist
```

`PlistBuddy` is used exclusively with `Print`. There are no commands that directly modify eligibility answers. A missing snapshot is treated as a missing state; the recovery does not create a replacement containing predetermined answers.

All six checks must match at the same time for local success:

| Output label | Snapshot / domain / key | Target |
| --- | --- | ---: |
| `GREYMATTER` | `eligibilityd`, `OS_ELIGIBILITY_DOMAIN_GREYMATTER`, `os_eligibility_answer_t` | `4` |
| `AMERICIUM` | `eligibilityd`, `OS_ELIGIBILITY_DOMAIN_AMERICIUM`, `os_eligibility_answer_t` | `4` |
| `SIRI_MODE` | `os_eligibility`, `OS_ELIGIBILITY_DOMAIN_SIRI_MODE`, `os_eligibility_answer_t` | `4` |
| `MATCH` | `eligibilityd`, GREYMATTER, `status:OS_ELIGIBILITY_INPUT_DEVICE_AND_SIRI_LANGUAGE_MATCH` | `3` |
| `HAS_LINWOOD` | `eligibilityd`, AMERICIUM, `status:OS_ELIGIBILITY_INPUT_HAS_LINWOOD` | `3` |
| `LINWOOD_AVAILABILITY` | `eligibilityd`, AMERICIUM, `context:OS_ELIGIBILITY_CONTEXT_LINWOOD_AVAILABILITY` | `1` |

The two additional `DEVICE_LANGUAGE` values shown in the output are diagnostic; `eligible_now()` does not use them as success criteria. These numbers are described here as observed target values. Their names alone do not provide a reliable, complete interpretation of Apple's internal enums.

If all six target values are already present, the script skips the temporary English phase, the CFPrefs restart and the eligibility recalculation. It still applies the fixed final configuration described below, checks the state again and reloads the Siri user processes.

## 3. Set the temporary language configuration

If recalculation is needed, Siri AI is closed first. The script then sets:

```text
com.apple.assistant.backedup / Session Language = en-US
com.apple.siri.generativeassistantsettings / isEnabled = true
NSGlobalDomain / AppleLanguages = [en-US, de-DE]
```

During this phase, the global list contains **exactly** `en-US`, followed by `de-DE`. Siri remains in English. This ordering is part of the reproduced flow. The recovery does not offer a general choice of arbitrary language lists or other Siri languages.

## 4. Reload CFPrefs and check Foundation

`refresh_preference_daemons()` first terminates reachable `cfprefsd` processes with `killall`, then additionally with `sudo killall`. It waits **3 seconds** and displays the processes that are present again. The recovery does not directly modify system preference files or write a cache by hand.

If `/usr/bin/swift` is present and executable, the script runs a short Foundation test. It prints `Locale.preferredLanguages` and the preferred localization for the candidates `en`, `de`, `fr`, `es`, `it`. The output passes the check if either the language list starts with `en-US` or the preferred localization starts with `en`.

If the test fails, CFPrefs is reloaded again. There are at most **three Foundation attempts**. If they fail, the activation flow stops with exit code `2`; the finalization handler then attempts to set the German configuration.

If there is no executable `/usr/bin/swift`, the script skips this additional check. A successful recovery without this test therefore includes no direct Foundation verification. Conversely, an existing Swift launcher without a working toolchain can fail and cause the script to stop. The check does not comprehensively establish the language state of all processes that are already running.

## 5. Notifications and 15 seconds of propagation

The script starts a local unified log stream for `eligibilityd`, `assistantd`, `generativeexperiencesd` and `cfprefsd`, running for up to 60 seconds. It then posts the following with `notifyutil -p`:

```text
AppleLanguagePreferencesChangedNotification
AFLanguageCodeDidChangeDarwinNotification
```

It waits **15 seconds** without itself terminating the existing `eligibilityd` instance. This gap between the preference change and the process change is an essential part of the documented successful flow. The recovery cannot prevent the operating system from terminating a process during that time for other reasons.

## 6. Let a fresh instance calculate eligibility

`restart_eligibilityd()` finds the first PID reported by `pgrep -x eligibilityd` and, if one exists, sends it a termination signal using `sudo kill -TERM`. It then looks for a new, different PID in 0.25-second intervals for up to approximately **15 seconds**.

If a new PID is still missing, the script posts `AppleLanguagePreferencesChangedNotification` as the LaunchEvent used in the project and searches again for up to approximately 15 seconds. It does not install a LaunchDaemon or replace an Apple binary. If no new PID appears, the first attempt stops with exit code `3`.

After a successful process change, the sequence is:

1. Wait **2 seconds**.
2. Post both language notifications again.
3. Wait **8 seconds** for initialization.
4. Check for both snapshot files for up to approximately **10 seconds**: at most 20 checks, each separated by 0.5 seconds.
5. Read the selected status values and compare all six target values.

The wait checks whether the files exist; it does not check a timestamp or guarantee that all contents were rewritten. **Apple's `eligibilityd` is allowed to regenerate missing snapshots itself**. The script does not delete snapshots, set answers to `4` or write other target numbers into status fields.

If the six target values are not all reached after the first attempt, the script performs **exactly one additional controlled process change**, with the same sequence: `2 seconds → notifications → 8 seconds → snapshot wait`. The second attempt does not repeat the 15-second propagation phase.

If the second process change fails, the script exits with code `4`. If the target state remains incomplete after both attempts, it exits with code `5`. In that case, the recovery also writes selected local diagnostics to its report. Here too, no eligibility answers are manually replaced.

## 7. Fixed German final configuration

After a successful local eligibility check, `finalize_german()` sets:

```text
NSGlobalDomain / AppleLanguages = [de-DE, en-US, en-DE]
com.apple.assistant.backedup / Session Language = en-US
com.apple.siri.generativeassistantsettings / isEnabled = true
com.apple.campo / AppleLanguages = [de-DE]
```

This configures German as the primary global language, keeps Siri at `en-US`, and assigns German app localization to Siri AI / Campo. Other apps that are already running may need a later app restart before their displayed language changes.

Here, “restore” means **this fixed target configuration**. The script does not back up an arbitrary previous language list and automatically restore it. The path for devices that are already eligible also sets this final state. The published script is therefore unsuitable, without changes, for a different desired language profile.

After these preference writes, the script **deliberately posts no further explicit global language notification**. In the documented test, this preserved the eligibility state previously calculated under English. This does not guarantee that Apple or other processes cannot trigger a later recalculation.

The six eligibility values are checked again immediately after setting the German configuration. If they have fallen back, the script exits with code `6`; it does not post additional language notifications or open Siri AI on this exit path.

The finalization handler also attempts to apply the German configuration after errors following a successful preflight, and on `INT`, `TERM` and `HUP`. This is a best-effort restoration. Failed `defaults` writes, a forced `SIGKILL`, power loss or other interruptions can prevent it. The script does not check every individual write for success and runs with `set +e`; there is no absolute restoration guarantee.

## 8. Reload Siri user processes and wait for availability

After applying the German configuration and checking eligibility again, the script closes Siri AI once more and terminates the reachable user processes:

```text
intelligenceflowd
intelligencecontextd
siriactionsd
assistantd
Spotlight
```

Spotlight is also reloaded so that its interface can pick up the German localization afresh. After **4 seconds**, the existing Siri AI app is opened. These process restarts can interrupt ongoing Siri interactions.

The script then checks for up to **120 seconds** whether `com.apple.assistant.backedup / SiriAvailability` contains the text `isAvailable = 1;`. It displays selected availability fields along the way. This check is separate from local eligibility success.

If the eligibility check succeeded but `SiriAvailability` is still not ready after 120 seconds, the script reports successful local activation with availability still pending. It does **not assign a separate error code** for this situation. A normal exit alone therefore confirms neither a ready Siri AI interface nor a successful cloud request test. The final message and displayed status values must also be considered.

## Exit codes and exit paths

| Code | Meaning |
| ---: | --- |
| `1` | Preflight failed: architecture, macOS version, existing Siri AI app or administrator access. |
| `2` | The optional Foundation check, when actually run, did not confirm English even after three attempts. |
| `3` | No new PID was found during the first eligibility restart. |
| `4` | No new PID was found during the second eligibility restart. |
| `5` | The complete local eligibility target state was not reached after both attempts. |
| `6` | The target state fell back immediately after setting the German configuration. |
| `130` | The signal handler was triggered by `INT`, `TERM` or `HUP`. |

On normal completion, the script waits for the log stream, removes its temporary working directory and keeps the Terminal window open until Enter is pressed. The explicit error paths `2` through `6` leave the script earlier; the EXIT handler performs the best-effort final configuration and cleanup.

## Reboots and limits of the findings

Eligibility may fall back after a normal reboot. The recovery can then be run again. It is not a permanent activation across all reboots, system updates or changes made by Apple.

The observed relationship between language configuration, CFPrefs, propagation and a new `eligibilityd` process explains the chosen recovery sequence. The script has no control over server-side availability, account conditions, asset delivery or later internal reassessments. There is no promise that future macOS versions will use the same keys or flow.

## Scope of changes and private diagnostics

The recovery writes the specified user preferences, reads eligibility snapshots, posts local notifications, terminates the described processes and opens the existing Siri AI app. It explicitly does not modify:

- SIP or files under `/System`;
- WARP, Surge, DNS or VPN configuration;
- `networkserviceproxy` or `privatecloudcomputed`;
- Apple models, asset files or Apple binaries;
- eligibility answers through direct editing.

It is not a network or cloud proxy. The Apple app opened afterward can use network services as part of its normal operation.

The recovery creates a `Siri-AI-Post-Boot-<timestamp>.txt` report and a `Siri-AI-Post-Boot-<timestamp>-Propagation.log` on the Desktop. With `umask 077`, it restricts the ordinary permissions of newly created files to the executing user. **These files remain private diagnostics and do not belong in the public repository, releases or unreviewed GitHub issues.**

Reports can contain local user paths and other personal or device-related information. Unified logs can contain additional private data despite the process filter. The script does not anonymize reports; file permissions do not provide anonymization and do not prevent synchronization by an existing Desktop cloud backup. No raw logs, account dumps or device reports were incorporated into the public documentation.

This project is unofficial and does not originate from Apple. The repository's license applies to its own code and documentation; it does not bundle Apple software, models or system assets.
