<#
.SYNOPSIS
    Vanjix Debloat - remove Windows bloat safely, with undo for every change.

.DESCRIPTION
    Run with no parameters to open the window.
    Parameters run it from the command line instead.

.EXAMPLE
    .\Vanjix-Debloat.ps1
    Opens the window.

.EXAMPLE
    .\Vanjix-Debloat.ps1 -List
    Shows every item and its current state. Changes nothing.

.EXAMPLE
    .\Vanjix-Debloat.ps1 -Preset Recommended -Apply
    Applies the Recommended preset (asks before changing anything).

.EXAMPLE
    .\Vanjix-Debloat.ps1 -Ids Privacy.Telemetry,Taskbar.Widgets -Undo
    Undoes two items.

.EXAMPLE
    .\Vanjix-Debloat.ps1 -UndoAll
    Undoes everything Vanjix Debloat has changed on this PC.
#>
[CmdletBinding()]
param(
    [switch]$List,
    [string]$Preset,      # Minimal | Recommended | Everything (checked below; ValidateSet breaks "irm | iex")
    [string[]]$Ids,
    [string]$Config,
    [switch]$Apply,
    [switch]$Undo,
    [switch]$UndoAll,
    [switch]$NoRestorePoint,
    [switch]$NoExplorerRestart,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off
if ($Preset -and @('Minimal', 'Recommended', 'Everything') -notcontains $Preset) {
    Write-Host "Unknown preset '$Preset'. Use Minimal, Recommended or Everything." -ForegroundColor Red
    return
}

#region EMBEDDED-SOURCES  (build.ps1 replaces this region in the single-file release)
$DebloatSources = $null
#endregion EMBEDDED-SOURCES

# ---- Windows PowerShell 5.1 is required (Appx commands are unreliable in PowerShell 7) ----
if ($PSVersionTable.PSEdition -eq 'Core') {
    if ($PSCommandPath) {
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"") + ($MyInvocation.UnboundArguments)
        foreach ($k in $PSBoundParameters.Keys) {
            $v = $PSBoundParameters[$k]
            if ($v -is [switch]) { if ($v) { $argList += "-$k" } }
            elseif ($v -is [array]) { $argList += "-$k"; $argList += ($v -join ',') }
            else { $argList += "-$k"; $argList += "`"$v`"" }
        }
        Start-Process powershell.exe -ArgumentList $argList -Wait -NoNewWindow
        return
    }
    Write-Host 'Please run Vanjix Debloat in Windows PowerShell (powershell.exe), not PowerShell 7.' -ForegroundColor Red
    return
}

# ---- load the engine, tweak list and window ----
if (-not $DebloatSources) {
    $srcDir = Join-Path $PSScriptRoot 'src'
    $DebloatSources = @('Engine.ps1', 'Tweaks.ps1', 'Gui.ps1') | ForEach-Object {
        Get-Content -Path (Join-Path $srcDir $_) -Raw
    }
}
foreach ($src in $DebloatSources) { . ([scriptblock]::Create($src)) }

$cliMode = $List -or $Preset -or $Ids -or $Config -or $Apply -or $Undo -or $UndoAll

# ---- administrator (not needed for -List) ----
if (-not $List -and -not (Test-DebloatAdmin)) {
    if ($PSCommandPath) {
        Write-Host 'Vanjix Debloat needs administrator rights. Asking Windows for permission...' -ForegroundColor Yellow
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        foreach ($k in $PSBoundParameters.Keys) {
            $v = $PSBoundParameters[$k]
            if ($v -is [switch]) { if ($v) { $argList += "-$k" } }
            elseif ($v -is [array]) { $argList += "-$k"; $argList += ($v -join ',') }
            else { $argList += "-$k"; $argList += "`"$v`"" }
        }
        if ($cliMode) { $argList = @('-NoExit') + $argList }
        try { Start-Process powershell.exe -Verb RunAs -ArgumentList $argList }
        catch { Write-Host 'Administrator permission was not given. Nothing was changed.' -ForegroundColor Red }
        return
    }
    Write-Host 'Vanjix Debloat needs administrator rights.' -ForegroundColor Red
    Write-Host 'Right-click Start > "Terminal (Admin)" or "Windows PowerShell (Admin)", then run the command again.' -ForegroundColor Yellow
    return
}

# =============================================================================
# Window
# =============================================================================
if (-not $cliMode) {
    Show-DebloatGui -Sources $DebloatSources
    return
}

# =============================================================================
# Command line
# =============================================================================

function Write-DebloatRule { Write-Host ('-' * 78) -ForegroundColor DarkGray }

Write-Host ''
Write-Host "  VANJIX DEBLOAT v$script:DebloatVersion" -ForegroundColor Magenta
$wi = Get-DebloatWindowsInfo
Write-Host "  $($wi.ProductName) $($wi.DisplayVersion) (build $($wi.Build))" -ForegroundColor DarkGray
Write-Host ''

if ($List) {
    if (-not (Test-DebloatAdmin)) {
        Write-Host '  Not running as administrator: app status only covers your own account.' -ForegroundColor Yellow
        Write-Host ''
    }
    Update-DebloatAppCache
    $rows = foreach ($t in Get-DebloatTweaks) {
        $st = Get-DebloatTweakStatus $t
        $p = '-'; if ($t.Preset) { $p = $t.Preset }
        [pscustomobject]@{ Id = $t.Id; Category = $t.Category; Risk = $t.Risk; Preset = $p; Status = $st.Text; Name = $t.Name }
    }
    $rows | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Host
    return
}

# ---- build the selection ----
$selected = New-Object System.Collections.Generic.List[string]
if ($Preset) { foreach ($id in Get-DebloatPresetIds -Preset $Preset) { if (-not $selected.Contains($id)) { $selected.Add($id) } } }
if ($Config) { foreach ($id in Read-DebloatSelectionFile $Config) { if (-not $selected.Contains($id)) { $selected.Add($id) } } }
foreach ($id in @($Ids | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
    $id = $id.Trim()
    $null = Get-DebloatTweak $id     # throws on a typo
    if (-not $selected.Contains($id)) { $selected.Add($id) }
}
if ($UndoAll) {
    $Undo = $true
    foreach ($id in (Get-DebloatBackup).Keys) {
        if ((Get-DebloatTweaks | Where-Object { $_.Id -eq $id }) -and -not $selected.Contains($id)) { $selected.Add($id) }
    }
}

if ($Apply -and $Undo) { Write-Host 'Use -Apply or -Undo, not both.' -ForegroundColor Red; return }
if (-not $Apply -and -not $Undo) { Write-Host 'Add -Apply or -Undo (or use -List to just look).' -ForegroundColor Red; return }
if ($selected.Count -eq 0) { Write-Host 'Nothing selected. Use -Preset, -Ids or -Config.' -ForegroundColor Yellow; return }

$action = 'Apply'; if ($Undo) { $action = 'Undo' }
$tweaks = @($selected | ForEach-Object { Get-DebloatTweak $_ })

Write-Host "  $action these $($tweaks.Count) item(s):" -ForegroundColor Cyan
Write-DebloatRule
foreach ($t in $tweaks) {
    $color = switch ($t.Risk) { 'Safe' { 'Gray' } 'Moderate' { 'Yellow' } default { 'Red' } }
    Write-Host ("  [{0,-8}] {1}" -f $t.Risk, $t.Name) -ForegroundColor $color
    if ($action -eq 'Apply' -and $t.Warning) { Write-Host "             Note: $($t.Warning)" -ForegroundColor Yellow }
    if ($action -eq 'Apply' -and $t.ContainsKey('App') -and $t.App.Permanent) {
        Write-Host '             Cannot be reinstalled afterwards.' -ForegroundColor Yellow
    }
}
Write-DebloatRule

if (-not $Yes) {
    $answer = Read-Host '  Continue? (y/n)'
    if ($answer -notmatch '^(y|yes)$') { Write-Host '  Nothing was changed.'; return }
}

$doRestore = (-not $NoRestorePoint) -and ($action -eq 'Apply')
$results = Invoke-DebloatBatch -Ids $selected.ToArray() -Action $action -CreateRestorePoint $doRestore -RestartExplorer (-not $NoExplorerRestart)
if (@($results | Where-Object { -not $_.Success }).Count) { exit 1 }
