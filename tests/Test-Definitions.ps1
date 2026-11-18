# Checks every tweak definition for mistakes. Changes nothing on the PC.
# Run:  powershell -NoProfile -ExecutionPolicy Bypass -File tests\Test-Definitions.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
foreach ($f in 'Engine.ps1', 'Tweaks.ps1') { . (Join-Path $root "src\$f") }

$fail = 0
function Fail($msg) { $script:fail++; Write-Host "FAIL  $msg" -ForegroundColor Red }

# ASCII only (Windows PowerShell 5.1 reads BOM-less files as ANSI)
Get-ChildItem $root -Recurse -Include *.ps1, *.bat | Where-Object { $_.FullName -notmatch '\\dist\\' } | ForEach-Object {
    $bad = @([IO.File]::ReadAllBytes($_.FullName) | Where-Object { $_ -gt 127 }).Count
    if ($bad) { Fail "$($_.Name) has $bad non-ASCII bytes" }
}

$tweaks = Get-DebloatTweaks
$ids = @{}
foreach ($t in $tweaks) {
    $where = $t.Id
    foreach ($k in 'Id', 'Category', 'Name', 'Description', 'Risk') { if (-not $t[$k]) { Fail "$where is missing $k" } }
    if ($ids.ContainsKey($t.Id)) { Fail "duplicate id $($t.Id)" }
    $ids[$t.Id] = $true
    if ($script:DebloatCategories -notcontains $t.Category) { Fail "$where has unknown category '$($t.Category)'" }
    if ('Safe', 'Moderate', 'Advanced' -notcontains $t.Risk) { Fail "$where has unknown risk '$($t.Risk)'" }
    if ($t.Preset -and $script:PresetOrder -notcontains $t.Preset) { Fail "$where has unknown preset '$($t.Preset)'" }
    if ($t.Risk -eq 'Advanced' -and $t.Preset) { Fail "$where is Advanced but has a preset" }
    if ($t.Category -eq 'Windows Update' -and $t.Risk -ne 'Advanced') { Fail "$where is a Windows Update item but not Advanced" }

    $parts = @('Registry', 'Services', 'Tasks', 'App', 'Check') | Where-Object { $t.ContainsKey($_) }
    if (-not $parts) { Fail "$where has nothing to do" }
    if ($t.ContainsKey('Apply') -and -not $t.ContainsKey('Undo')) { Fail "$where has a custom Apply but no Undo" }
    if ($t.ContainsKey('App') -and -not $t.App.Package) { Fail "$where App has no Package" }

    foreach ($r in @($t.Registry)) {
        if (-not $r) { continue }
        if ($r.Path -notmatch '^(HKLM|HKCU)\\') { Fail "$where registry path must start with HKLM\ or HKCU\: $($r.Path)" }
        if (-not $r.ContainsKey('Name')) { Fail "$where registry entry has no Name" }
        if (-not $r.ContainsKey('Value')) { Fail "$where registry entry has no Value" }
        if ($r.ContainsKey('Type') -and 'DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary' -notcontains $r.Type) {
            Fail "$where has unknown registry type $($r.Type)"
        }
    }
    foreach ($s in @($t.Services)) {
        if (-not $s) { continue }
        foreach ($k in 'Name', 'Start', 'Default') { if (-not $s[$k]) { Fail "$where service entry is missing $k" } }
        foreach ($k in 'Start', 'Default') { if ($s[$k]) { try { $null = ConvertTo-DebloatStartValue $s[$k] } catch { Fail "$where service $($s.Name): $_" } } }
    }
    foreach ($task in @($t.Tasks)) {
        if ($task -and $task -notmatch '^\\') { Fail "$where task path must start with \: $task" }
    }
}

# Never-remove list: these break Windows or other apps.
$protected = 'Microsoft.WindowsStore', 'Microsoft.Windows.SecHealthUI', 'Microsoft.DesktopAppInstaller', 'Microsoft.Winget*',
             'Microsoft.WindowsCalculator', 'Microsoft.Windows.Photos', 'Microsoft.WindowsNotepad', 'Microsoft.WindowsTerminal',
             'Microsoft.ScreenSketch', 'Microsoft.Paint', 'Microsoft.XboxIdentityProvider', 'Microsoft.Xbox.TCUI',
             'Microsoft.MicrosoftEdge*', 'Microsoft.Win32WebViewHost', 'Microsoft.VCLibs*', 'Microsoft.UI.Xaml*',
             'Microsoft.*VideoExtension*', 'Microsoft.*ImageExtension*', 'Microsoft.WebMediaExtensions'
foreach ($t in $tweaks | Where-Object { $_.ContainsKey('App') }) {
    foreach ($p in $protected) {
        if ($t.App.Package -like $p -or $p -like $t.App.Package) { Fail "$($t.Id) would remove protected package $p" }
    }
}

# Presets must nest: Minimal inside Recommended inside Everything
$min = @(Get-DebloatPresetIds Minimal); $rec = @(Get-DebloatPresetIds Recommended); $all = @(Get-DebloatPresetIds Everything)
foreach ($i in $min) { if ($rec -notcontains $i) { Fail "Minimal item $i is not in Recommended" } }
foreach ($i in $rec) { if ($all -notcontains $i) { Fail "Recommended item $i is not in Everything" } }
if (@($min | Where-Object { $_ -like 'App.*' }).Count) { Fail 'Minimal must not uninstall apps' }

Write-Host ''
Write-Host ("{0} tweaks checked. Presets: Minimal {1}, Recommended {2}, Everything {3} (on this PC)." -f $tweaks.Count, $min.Count, $rec.Count, $all.Count)
if ($fail) { Write-Host "$fail problem(s) found" -ForegroundColor Red; exit 1 }
Write-Host 'All definition checks passed' -ForegroundColor Green
