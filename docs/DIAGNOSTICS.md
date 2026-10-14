# Siri AI Diagnostics

**Language:** English | [Deutsch](DIAGNOSTICS.de.md)

Return to the [project overview](../README.md).

`Siri-AI-Diagnostics.command` is a companion, diagnostics-only script for macOS 27.x. It does not modify Siri, language, or eligibility settings and does not restart services.

## What it checks

The script reports, among other things:

- macOS version, build, and architecture
- presence of `/System/Applications/Siri AI.app`
- global `AppleLanguages`
- Siri `Session Language`
- Siri AI / Campo localization
- `Generative Assistant isEnabled`
- Foundation language perception
- the known eligibility target values from `eligibilityd` and `os_eligibility`
- `SiriAvailability`, orchestration mode, and restriction/unavailability reasons
- relevant process state for `eligibilityd`, `assistantd`, `intelligenceflowd`, `intelligencecontextd`, `siriactionsd`, and `generativeexperiencesd`

## Running it

```zsh
chmod +x ./Siri-AI-Diagnostics.command
./Siri-AI-Diagnostics.command
```

Optionally save the same output to a local Desktop report:

```zsh
./Siri-AI-Diagnostics.command --save
```

The report may contain device, local path, or runtime information and should always be reviewed and sanitized before publication.

## Read-only eligibility access

The eligibility snapshots are stored under:

```text
/private/var/db/eligibilityd/eligibility.plist
/private/var/db/os_eligibility/eligibility.plist
```

Reading their contents may require `sudo`. The diagnostic script only copies them into a private temporary directory for read-only parsing, evaluates the copies with `plutil` or `PlistBuddy`, and removes them on exit. It does not write to the original snapshots or to the copies.

The script uses no `defaults write` commands, sends no language notifications, and does not stop or restart Siri/eligibility daemons.

## Interpretation

The strongest local state is:

- all six eligibility values observed by the recovery project match their target values,
- `SiriAvailability` contains `isAvailable = 1`,
- no local restriction or unavailability reasons are reported.

This still does not prove that a specific cloud/PCC request succeeded or that every Siri AI feature is server-side available.

If the eligibility values cannot be read while `isAvailable = 1` is present, the diagnostic reports an incomplete verification instead of treating that condition as proof of failed eligibility.
