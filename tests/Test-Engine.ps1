# Tests apply / status / undo on a throwaway registry key.
# Touches only HKCU\Software\VanjixDebloatTest (deleted at the end) and a temp folder.
# Needs no administrator rights.
# Run:  powershell -NoProfile -ExecutionPolicy Bypass -File tests\Test-Engine.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src\Engine.ps1')

$testKey = 'HKCU\Software\VanjixDebloatTest'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('VanjixDebloatTest-' + [guid]::NewGuid().ToString('N'))
$script:DebloatDataDir = $tmp
$script:DebloatBackup  = Join-Path $tmp 'backup.json'
$script:DebloatLogDir  = Join-Path $tmp 'logs'

$fail = 0
function Check($cond, $msg) {
    if ($cond) { Write-Host "PASS  $msg" -ForegroundColor Green }
    else { $script:fail++; Write-Host "FAIL  $msg" -ForegroundColor Red }
}

try {
    Remove-DebloatRegKey $testKey
    # Existing values that the tweak will change
    Write-DebloatRegValue -Path $testKey -Name 'Existing' -Value 5 -Type DWord
    Write-DebloatRegValue -Path $testKey -Name 'Text' -Value 'original' -Type String

    $script:DebloatTweaks = @(
        @{
            Id = 'Test.Registry'; Category = 'Privacy'; Name = 'Test registry'; Description = 'x'; Risk = 'Safe'; Preset = 'Minimal'
            Registry = @(
                @{ Path = $testKey; Name = 'Existing'; Value = 0 }
                @{ Path = $testKey; Name = 'Text'; Value = 'changed'; Type = 'String' }
                @{ Path = "$testKey\Sub"; Name = 'New'; Value = 1 }
                @{ Path = $testKey; Name = 'Dynamic'; Type = 'String'; Value = { 'computed-' + (1 + 1) } }
            )
        }
        @{
            Id = 'Test.Default'; Category = 'Privacy'; Name = 'Default fallback'; Description = 'x'; Risk = 'Safe'; Preset = $null
            Registry = @( @{ Path = $testKey; Name = 'WithDefault'; Value = 0; Default = 7 } )
        }
        @{
            Id = 'Test.Future'; Category = 'Privacy'; Name = 'Future build only'; Description = 'x'; Risk = 'Safe'; Preset = 'Minimal'
            MinBuild = 999999
            Registry = @( @{ Path = $testKey; Name = 'Never'; Value = 1 } )
        }
    )

    $t = Get-DebloatTweak 'Test.Registry'
    Check ((Get-DebloatTweakStatus $t).State -eq 'NotApplied') 'status is NotApplied before apply'

    Write-DebloatRegValue -Path $testKey -Name 'Existing' -Value 0 -Type DWord
    Check ((Get-DebloatTweakStatus $t).State -eq 'Partial') 'status is Partial when one value matches'
    Write-DebloatRegValue -Path $testKey -Name 'Existing' -Value 5 -Type DWord

    $backup = Get-DebloatBackup
    $r = Invoke-DebloatTweakApply -Tweak $t -Backup $backup
    Check $r.Success "apply succeeds ($($r.Message))"
    Check ((Get-DebloatTweakStatus $t).State -eq 'Applied') 'status is Applied after apply'
    Check ((Read-DebloatRegValue $testKey 'Dynamic').Value -eq 'computed-2') 'script block values are evaluated'
    Check (Test-Path $script:DebloatBackup) 'backup file written'

    # Applying again must not overwrite the saved originals
    $backup = Get-DebloatBackup
    $null = Invoke-DebloatTweakApply -Tweak $t -Backup $backup
    $saved = (Get-DebloatBackup)['Test.Registry'].Registry["$testKey|Existing"]
    Check ($saved.Value -eq 5) 'second apply keeps the original backup value'

    $backup = Get-DebloatBackup
    $r = Invoke-DebloatTweakUndo -Tweak $t -Backup $backup
    Check $r.Success "undo succeeds ($($r.Message))"
    $e = Read-DebloatRegValue $testKey 'Existing'
    Check ($e.Exists -and $e.Value -eq 5 -and $e.Kind -eq 'DWord') 'undo restores the original DWORD'
    Check ((Read-DebloatRegValue $testKey 'Text').Value -eq 'original') 'undo restores the original string'
    Check (-not (Read-DebloatRegValue "$testKey\Sub" 'New').Exists) 'undo removes a value that did not exist before'
    Check (-not (Read-DebloatRegValue $testKey 'Dynamic').Exists) 'undo removes the computed value'
    Check (-not (Get-DebloatBackup).ContainsKey('Test.Registry')) 'backup entry cleared after undo'

    # Undo without a backup uses the Default
    $d = Get-DebloatTweak 'Test.Default'
    Write-DebloatRegValue -Path $testKey -Name 'WithDefault' -Value 0 -Type DWord
    $r = Invoke-DebloatTweakUndo -Tweak $d -Backup @{}
    Check ((Read-DebloatRegValue $testKey 'WithDefault').Value -eq 7) 'undo without backup falls back to Default'

    # Build gating
    $f = Get-DebloatTweak 'Test.Future'
    Check ((Get-DebloatTweakStatus $f).State -eq 'NotApplicable') 'MinBuild marks an item NotApplicable'
    Check (@(Get-DebloatPresetIds Minimal) -notcontains 'Test.Future') 'presets skip items not for this Windows'
    Check (@(Get-DebloatPresetIds Minimal) -contains 'Test.Registry') 'presets include matching items'

    # Corrupt backup file is survived
    Set-Content -Path $script:DebloatBackup -Value '{ not json'
    $b = Get-DebloatBackup
    Check ($b -is [hashtable] -and $b.Count -eq 0) 'a broken backup file does not crash'
} finally {
    Remove-DebloatRegKey $testKey
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Check (-not (Test-DebloatRegKey $testKey)) 'test key cleaned up'
Write-Host ''
if ($fail) { Write-Host "$fail test(s) failed" -ForegroundColor Red; exit 1 }
Write-Host 'All engine tests passed' -ForegroundColor Green
