# Publication scope and validation

**Language:** English | [Deutsch](VALIDATION.de.md)

Return to the [project overview](../README.md).

The public version was assembled from an explicit file list in a new, separate staging directory. The research directories and their Git history were excluded. No existing research file list was imported wholesale with `git add .`.

## Published files

- `README.md`
- `README.de.md`
- `LICENSE`
- `.gitignore`
- `assets/siri-ai-eu-social-preview.jpg`
- `START-HERE.txt`
- `START-HIER.txt`
- `Siri-AI-EU-Recovery.command`
- `Siri-AI-Diagnostics.command`
- `docs/TECHNICAL.md`
- `docs/TECHNICAL.de.md`
- `docs/VALIDATION.md`
- `docs/VALIDATION.de.md`
- `docs/DIAGNOSTICS.md`
- `docs/DIAGNOSTICS.de.md`

`assets/siri-ai-eu-social-preview.jpg` is the presentation banner shown at the top of both READMEs and intended as the repository social preview. It is a resized copy (1280×640, JPEG) of the project banner. Its text content consists only of generic, illustrative placeholder values (for example `macOS 27 (build 27Axxxx)`, `GREYMATTER`, `AMERICIUM`, `SIRI_MODE`); it contains no usernames, real build numbers, device/account identifiers, personal paths or other private data. Image metadata was reduced to standard JPEG/EXIF fields.

The release asset `Siri-AI-EU-Recovery-FINAL.zip` is distributed separately. The original v1.0.0 ZIP remains unchanged and contains only the `Siri-AI-EU-Recovery/` directory with `Siri-AI-EU-Recovery.command` and the German `START-HIER.txt`. Both files match their repository counterparts byte for byte. The English `START-HERE.txt` is available in the repository; it is not added to the original ZIP. The release's `SHA256SUMS` enables an integrity check:

```zsh
# In the directory containing both downloaded release assets:
shasum -a 256 -c SHA256SUMS
```

SHA-256 of the unchanged recovery file:

```text
6157720a53aae10fec8e4477f1ddb860fae8eb9d0eb4af4c37c425dfae2d4a8f
```

SHA-256 of the unchanged final ZIP:

```text
8e8542c3e5d6665ca1c6c5eb375730dfde9d43c69f5a32f1ea8551a9895cee01
```

## Syntax and plausibility

- `/bin/zsh -n Siri-AI-EU-Recovery.command` checks the complete shell syntax without executing the recovery.
- A complete static review checks the preflight, privileges, fixed preference targets, read-only eligibility access, notification sequence, 15-second propagation phase, new daemon PID and final configuration.
- A local check confirms the relevant code sections and their order, as well as the absence of an explicit global notification call after the restore.
- The embedded Swift/Foundation expression is type-checked separately without executing the recovery or changing preferences.
- The original, public script copy and ZIP contents are compared byte for byte; the ZIP CRC and member list are checked.

ShellCheck was not used; the script uses zsh. Preparing the publication did not execute the recovery again or change system settings. The functional result on macOS 27.0.1 / build 26A434 comes from the local project. Syntax and plausibility checks do not replace testing on other builds or Macs.

## Privacy and secret checks

All planned public text files, unpacked release contents and the complete public Git history are checked before publication. The checks combine Gitleaks with an additional search for personal paths, local user/Git identities, email addresses, IP addresses, device/account identifiers, private keys, token patterns and authentication data. An independent manual review supplements the automated checks.

The ZIP review also covers comments, extra fields, resource forks, unexpected members and trailing data. Git file contents and ZIP members contain no copied extended file attributes. Local quarantine attributes were removed from staging; macOS may retain a local provenance attribute there, which neither Git nor this ZIP transmits. Git blobs are checked against the approved file list. The initial publication started with a fresh root commit; later documentation commits pass the same privacy checks. The old research history remains excluded. Commit authors use only the authenticated GitHub login and its ID-based GitHub noreply address. Private global Git identity values are not copied.

Before a push, `git status`, the complete staged diff, the repository file list, secret/privacy results and all reachable Git objects are reviewed. Release notes and the checksum file are also included in the reviewed publication scope. Automated pattern checks provide no universal guarantee; the limited file list and manual review are therefore part of the procedure.

## Deliberately excluded

Older and alternative recovery/diagnostic scripts, raw logs, terminal histories, complete system reports, screenshots, plist dumps, account/device information, personal metadata and the existing research history remain excluded. Apple system files, Apple binaries, models and assets are also excluded. Local audit artifacts and runtime diagnostics are not published.

When used later, the recovery generates its own Desktop reports and propagation logs. These may contain private information and must never be added to this repository or public issues without review, even after a successful run.
