# Vanjix Debloat

Remove Windows 10 and 11 bloat **safely**: preinstalled junk apps, telemetry, ads, tips, Copilot, Bing in Start, Widgets and more. Every change can be undone.

- **Nothing changes until you press Apply.** Nothing is selected by default.
- **Undo for everything.** Before it changes a setting, it saves the original value. Undo puts back exactly what was there before.
- **Shows before it acts.** Every item shows its current state on your PC (Applied / Not applied / Installed / Not installed).
- **Restore point first.** A System Restore point is created before every Apply.
- **Plain, readable PowerShell.** No .exe and no downloads in the background. Read every line before you run it.
- **Windows Update control.** Stop automatic updates, or block them completely. These are opt-in, under *Advanced*.

> Looking for FPS / gaming tweaks? Those are in the separate **GAME Booster** repo. This tool only removes bloat.

---

## How to run

### Option 1: download (easiest)

1. Download the latest ZIP from [Releases](https://github.com/FinAutBuilder/Windows-Debloat/releases) and extract it.
2. Double-click **`Run-Debloat.bat`**.
3. Click **Yes** when Windows asks for administrator permission.

### Option 2: one command

Open **Terminal (Admin)** or **Windows PowerShell (Admin)** (right-click the Start button) and run:

```powershell
irm https://github.com/FinAutBuilder/Windows-Debloat/releases/latest/download/Vanjix-Debloat.ps1 | iex
```

Before running it, you can open that link in your browser and read the whole script.

---

## Using it

1. Wait a few seconds while it checks your PC. Each item shows its current state.
2. Pick a **preset** or tick items yourself:

| Preset | What it picks |
|---|---|
| **Minimal** | Privacy, ads and tips only. Nothing is uninstalled. |
| **Recommended** | Minimal, plus junk apps nobody needs (Bing News, Solitaire, Candy Crush and so on), Copilot, Bing in Start search, Widgets. |
| **Everything** | Recommended, plus apps some people do use (Clock, Camera, Phone Link, Outlook, Teams and so on) and extra services. |

   Presets only pick items that are not applied yet. They **never** pick *Advanced* items or apps like Media Player, Sticky Notes, the Xbox app or OneDrive. Tick those yourself if you want them gone.

3. Press **Apply selected**. You get a summary with any warnings before anything happens.
4. Changed your mind? Tick the items and press **Undo selected**.

**Save selection** / **Load selection** store your picks in a small JSON file, so you can use the same setup on every PC.

---

## What it never touches

These break Windows or other apps, so they are not on the list at all:

Microsoft Store, Windows Security, Microsoft Edge, WinGet / App Installer, WebView2, Calculator, Photos, Notepad, Paint, Snipping Tool, Terminal, video and image codecs, and the Xbox sign-in components that games need.

It also doesn't edit your `hosts` file. Blocking Microsoft servers there gets flagged by Microsoft Defender, and it can break certificate checks.

---

## Windows Update (Advanced)

Many people have had crashes from recent updates and want to decide when updates install. These items are under **Windows Update** and are never picked by a preset:

| Item | What happens |
|---|---|
| **Stop automatic updates** | Windows stops installing updates and restarting by itself. You can still install updates in *Settings > Windows Update* when you choose. |
| **Stop driver updates** | Windows Update stops replacing your GPU and other drivers. |
| **Stay on your current Windows version** | Blocks the big yearly upgrade. Monthly security updates still come. |
| **Fully block Windows Update** | Turns off the update services and points Windows Update at a server that doesn't exist. Nothing updates. |

**Warning:** a PC without updates misses security fixes. If you fully block updates, Microsoft Defender definitions and Microsoft Store updates may also stop. Check for updates yourself every so often. To turn updates back on, tick the item and press **Undo selected**.

---

## Undo and backups

- Original values are saved in `C:\ProgramData\VanjixDebloat\backup.json` before the first change.
- Logs are in `C:\ProgramData\VanjixDebloat\logs\`.
- **Removed apps** are reinstalled from the Microsoft Store with `winget` when you undo them. Microsoft has retired some old apps (Skype, People, Cortana, Mail and Calendar and others). Those **can't** be reinstalled, and the confirmation tells you before you remove them.
- If something goes badly wrong, use the restore point. Search Start for *Create a restore point*, then *System Restore*.

**"Some settings are managed by your organization"**: you may see this in Settings or Edge afterwards. It's normal. Several items use Windows policy settings, which is the official way to turn these features off. Undo removes them again.

---

## Command line

```powershell
.\Vanjix-Debloat.ps1 -List                                    # show every item and its state (changes nothing)
.\Vanjix-Debloat.ps1 -Preset Recommended -Apply               # apply a preset (asks first)
.\Vanjix-Debloat.ps1 -Ids Privacy.Telemetry,AI.Recall -Apply  # apply chosen items
.\Vanjix-Debloat.ps1 -Config my-pc.json -Apply                # apply a saved selection
.\Vanjix-Debloat.ps1 -Ids Taskbar.Widgets -Undo               # undo items
.\Vanjix-Debloat.ps1 -UndoAll                                 # undo everything this tool changed
```

Extra switches: `-Yes` (don't ask), `-NoRestorePoint`, `-NoExplorerRestart`.

---

## Antivirus

This is a plain-text PowerShell script, not a packed .exe, so most antivirus programs leave it alone. A debloater changes system settings by design, so a cautious scanner may still warn about it. You can read every line before running it. To check that your download matches the release, compare its hash with `SHA256.txt` from the release:

```powershell
Get-FileHash .\Vanjix-Debloat.ps1 -Algorithm SHA256
```

---

## For contributors

```
Vanjix-Debloat.ps1   launcher: admin check, command line, opens the window
src/Engine.ps1       check / apply / undo / backup logic
src/Tweaks.ps1       every item, as data (start here to add or change items)
src/Gui.ps1          the window (WPF)
tests/               definition checks and engine tests (safe to run)
build.ps1            makes dist/Vanjix-Debloat.ps1, the single file for releases
```

- Adding an item usually means adding one entry to `src/Tweaks.ps1`. The engine works out check, apply and undo for registry values, services, scheduled tasks and apps.
- Keep files **ASCII only**. Windows PowerShell 5.1 misreads UTF-8 files that have no BOM.
- Run the tests before a pull request:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Test-Definitions.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Test-Engine.ps1
```

### Making a release

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

Upload `dist/Vanjix-Debloat.ps1`, `dist/SHA256.txt` and a ZIP of the repo (with `Run-Debloat.bat`) to a new GitHub Release.

---

## Requirements

Windows 10 or 11, Windows PowerShell 5.1 (built into Windows), administrator rights to apply changes.

## License

MIT. See [LICENSE](LICENSE). Use at your own risk. Always keep backups of important files.
