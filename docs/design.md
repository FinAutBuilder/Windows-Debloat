# Vanjix Debloat - design

Date: 2026-11-18

## Intent

Vanjix FPS Booster v30 mixed game boosting and Windows debloating. The game
booster now lives in its own GitHub repo. This repo is the debloater, split out
and rebuilt so strangers can download it from GitHub and trust it.

## Goals

- Remove Windows bloat: preinstalled apps, telemetry, ads, tips, Copilot/AI
  features, Bing in Start, widgets, unneeded services.
- Safe by default: nothing is selected until the user picks items or a preset.
- Every change can be undone. The original values are backed up before the
  first change and restored exactly on undo.
- Show before acting: every item shows its current state (Applied / Not
  applied / Partial, or Installed / Removed for apps) and a one-line reason.
- Readable: plain PowerShell text, no compiled .exe, so users can read every
  line and antivirus has nothing packed to flag.
- Opt-in Windows Update control, including a full block, under an Advanced
  section that no preset ever selects.

## Non-goals

- Gaming tweaks (power plans, CPU, GPU, network latency, mouse, HPET, timers).
  These stay in the game booster repo.
- No-recoil or anything that touches games. (v30's `universal_norecoil` is
  dropped: anti-cheat can ban for it.)
- Removing Microsoft Edge, Microsoft Store, Windows Security, WinGet, WebView,
  codecs, Calculator, Photos, Notepad, Terminal, Snipping Tool, or Xbox
  sign-in components. These break Windows or other apps.
- Hosts-file blocking of Microsoft domains. Defender flags it as
  HostsFileHijack, and v30's list blocked certificate checks (crl.microsoft.com).

## Anti-goals (failure even if it "works")

- A stranger runs "Recommended" and something they use daily breaks.
- A change that cannot be reverted, without saying so up front.
- The script itself gets flagged by antivirus.

## Approaches considered

| Approach | Trade-off | Decision |
|---|---|---|
| A. Python app reusing v30 | Most code reuse, but users need Python or a PyInstaller .exe, which already gets flagged by 14/72 engines | Rejected |
| B. PowerShell script with a WPF window | Nothing to install, readable, the norm for GitHub debloaters; the UI has to be rebuilt | **Chosen** |
| C. C# / .NET app | Full rewrite, still an unsigned .exe | Rejected |

## Design

### Data-driven tweak list

`src/Tweaks.ps1` holds every tweak as a hashtable:

- `Id`, `Category`, `Name`, `Description`
- `Risk`: `Safe`, `Moderate` or `Advanced`
- `Preset`: the lowest preset that includes it (`Minimal`, `Recommended`,
  `Everything`) or none. Advanced items never have a preset.
- `Warning`: shown in the confirmation before applying
- Parts, any combination of:
  - `Registry`: values to set (path, name, value, type, optional default)
  - `Services`: services and the startup type to set (plus the Windows default)
  - `Tasks`: scheduled tasks to disable
  - `App`: an Appx package to remove (with a Store ID for reinstalling)
  - `Check` / `Apply` / `Undo`: custom script blocks for anything else

### Engine (`src/Engine.ps1`)

- The engine derives check, apply and undo for registry, service, task and app
  parts, so most tweaks are pure data.
- Before the first change it records the original value in
  `%ProgramData%\VanjixDebloat\backup.json`. Undo restores the exact original,
  or deletes the value if it did not exist. With no backup, undo falls back to
  the Windows default given in the definition.
- Removed apps are reinstalled on undo with `winget` from the Microsoft Store
  when a Store ID is known. Apps Microsoft no longer offers are marked as
  permanent and the confirmation says so.
- A restore point is created before each apply batch (it can be turned off).
- Logs go to `%ProgramData%\VanjixDebloat\logs`.

### Interfaces

- GUI: a dark WPF window with categories, search, presets, per-item status,
  Apply / Undo selected, and a live log. Work runs in a background runspace so
  the window never freezes.
- CLI: `-List`, `-Preset`, `-Ids`, `-Apply`, `-Undo`, `-Config`,
  `-NoRestorePoint`, for power users and testing.
- `Run-Debloat.bat`: double-click launcher that elevates.
- `build.ps1`: merges everything into one `dist/Vanjix-Debloat.ps1` for
  GitHub Releases and the `irm ... | iex` one-liner.

### Windows Update (Advanced)

- Stop automatic updates (manual "Check for updates" still works) and no
  automatic restarts.
- Exclude driver updates.
- Stay on the current feature version.
- Full block: disables the update services and points Windows Update at a
  dead local server. Warned: no security patches, Defender and Store updates
  may fail. Undo turns it all back on.

### Constraints

- Must run on Windows PowerShell 5.1 (built into Windows 10/11). Source files
  are ASCII only, because 5.1 misreads UTF-8 files without a BOM.
- Needs Administrator for applying. `-List` works without it.

## Left to the builder (calls made during the build)

- Exact app list, service list and presets: curated from v30 for public safety.
- Store IDs for reinstalling are best-effort and should be verified on a test
  machine before release.
- License: MIT (common for tools like this; easy to change).
