# =============================================================================
# Vanjix Debloat - engine
# Checks, applies and undoes the tweaks defined in Tweaks.ps1.
# Every original value is backed up before the first change, so undo restores
# exactly what was there before.
# Windows PowerShell 5.1 compatible. Keep this file ASCII only.
# =============================================================================

$script:DebloatVersion  = '1.0.0'
$script:DebloatDataDir  = Join-Path $env:ProgramData 'VanjixDebloat'
$script:DebloatBackup   = Join-Path $script:DebloatDataDir 'backup.json'
$script:DebloatLogDir   = Join-Path $script:DebloatDataDir 'logs'
$script:DebloatLogSink  = $null      # ConcurrentQueue used by the GUI, or $null
$script:AppxInstalled   = $null
$script:AppxProvisioned = $null
$script:PresetOrder     = @('Minimal', 'Recommended', 'Everything')

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

function Set-DebloatLogSink {
    param($Queue)
    $script:DebloatLogSink = $Queue
}

function Write-DebloatLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warn', 'Error', 'Header')][string]$Level = 'Info'
    )
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line  = "[$stamp] [$Level] $Message"

    if ($script:DebloatLogSink) {
        $script:DebloatLogSink.Enqueue([pscustomobject]@{ Type = 'log'; Level = $Level; Text = "[$stamp] $Message" })
    } else {
        $color = switch ($Level) {
            'Success' { 'Green' } 'Warn' { 'Yellow' } 'Error' { 'Red' } 'Header' { 'Magenta' } default { 'Gray' }
        }
        Write-Host "[$stamp] $Message" -ForegroundColor $color
    }

    try {
        if (-not (Test-Path $script:DebloatLogDir)) { New-Item -ItemType Directory -Path $script:DebloatLogDir -Force | Out-Null }
        $file = Join-Path $script:DebloatLogDir ('debloat-{0}.log' -f (Get-Date).ToString('yyyyMMdd'))
        Add-Content -Path $file -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch { }   # logging must never break a run (e.g. -List without admin)
}

function Send-DebloatEvent {
    param([Parameter(Mandatory)][string]$Type, [hashtable]$Data = @{})
    if ($script:DebloatLogSink) {
        $Data['Type'] = $Type
        $script:DebloatLogSink.Enqueue([pscustomobject]$Data)
    }
}

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------

function Test-DebloatAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DebloatWindowsInfo {
    if ($script:DebloatWinInfo) { return $script:DebloatWinInfo }
    $cv ='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int](Read-DebloatRegValue -Path $cv -Name 'CurrentBuildNumber').Value
    $display = (Read-DebloatRegValue -Path $cv -Name 'DisplayVersion').Value
    $edition = (Read-DebloatRegValue -Path $cv -Name 'EditionID').Value
    $script:DebloatWinInfo = [pscustomobject]@{
        Build          = $build
        IsWindows11    = ($build -ge 22000)
        DisplayVersion = $display
        Edition        = $edition
        ProductName    = $(if ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' })
    }
    return $script:DebloatWinInfo
}

# -----------------------------------------------------------------------------
# Registry helpers (.NET API: 64-bit view, supports the (Default) value)
# Paths look like 'HKLM\SOFTWARE\...' or 'HKCU\Software\...'
# -----------------------------------------------------------------------------

function Split-DebloatRegPath {
    param([Parameter(Mandatory)][string]$Path)
    $parts = $Path -split '\\', 2
    $hive = switch ($parts[0].ToUpper()) {
        'HKLM' { [Microsoft.Win32.RegistryHive]::LocalMachine }
        'HKEY_LOCAL_MACHINE' { [Microsoft.Win32.RegistryHive]::LocalMachine }
        'HKCU' { [Microsoft.Win32.RegistryHive]::CurrentUser }
        'HKEY_CURRENT_USER' { [Microsoft.Win32.RegistryHive]::CurrentUser }
        'HKCR' { [Microsoft.Win32.RegistryHive]::ClassesRoot }
        'HKU'  { [Microsoft.Win32.RegistryHive]::Users }
        default { throw "Unknown registry hive in '$Path'" }
    }
    $sub = ''
    if ($parts.Count -gt 1) { $sub = $parts[1] }
    return @($hive, $sub)
}

function Open-DebloatRegKey {
    param([Parameter(Mandatory)][string]$Path, [switch]$Write, [switch]$Create)
    $hive, $sub = Split-DebloatRegPath $Path
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry64)
    if ($Create) { return $base.CreateSubKey($sub, $true) }
    return $base.OpenSubKey($sub, [bool]$Write)
}

function Read-DebloatRegValue {
    # Returns @{ Exists; Value; Kind }
    param([Parameter(Mandatory)][string]$Path, [AllowEmptyString()][string]$Name = '')
    $result = @{ Exists = $false; Value = $null; Kind = $null }
    $key = $null
    try {
        $key = Open-DebloatRegKey -Path $Path
        if ($null -eq $key) { return $result }
        if ($key.GetValueNames() -notcontains $Name) { return $result }
        $result.Exists = $true
        $result.Value  = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $result.Kind   = $key.GetValueKind($Name).ToString()
    } catch {
        # unreadable keys are treated as missing
    } finally {
        if ($key) { $key.Close() }
    }
    return $result
}

function Write-DebloatRegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Name = '',
        [Parameter(Mandatory)]$Value,
        [string]$Type = 'DWord'
    )
    $kind = [Microsoft.Win32.RegistryValueKind]$Type
    $key = Open-DebloatRegKey -Path $Path -Create
    if ($null -eq $key) { throw "Could not open or create $Path" }
    try {
        switch ($Type) {
            'DWord'       { $Value = [int]$Value }
            'QWord'       { $Value = [long]$Value }
            'Binary'      { $Value = [byte[]]$Value }
            'MultiString' { $Value = [string[]]$Value }
            default       { $Value = [string]$Value }
        }
        $key.SetValue($Name, $Value, $kind)
    } finally {
        $key.Close()
    }
}

function Remove-DebloatRegValue {
    param([Parameter(Mandatory)][string]$Path, [AllowEmptyString()][string]$Name = '')
    $key = Open-DebloatRegKey -Path $Path -Write
    if ($null -eq $key) { return }
    try { $key.DeleteValue($Name, $false) } finally { $key.Close() }
}

function Remove-DebloatRegKey {
    param([Parameter(Mandatory)][string]$Path)
    $hive, $sub = Split-DebloatRegPath $Path
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry64)
    $base.DeleteSubKeyTree($sub, $false)
}

function Test-DebloatRegKey {
    param([Parameter(Mandatory)][string]$Path)
    $key = Open-DebloatRegKey -Path $Path
    if ($null -eq $key) { return $false }
    $key.Close()
    return $true
}

function Resolve-DebloatValue {
    # Values may be script blocks, evaluated at check/apply time (e.g. current Windows version)
    param($Value)
    if ($Value -is [scriptblock]) { return (& $Value) }
    return $Value
}

function Test-DebloatValueEqual {
    param($Current, $Wanted)
    if ($null -eq $Current) { return $false }
    if ($Current -is [array] -or $Wanted -is [array]) {
        return ((@($Current) -join "`n") -eq (@($Wanted) -join "`n"))
    }
    return ([string]$Current -eq [string]$Wanted)
}

# -----------------------------------------------------------------------------
# Backup store
# -----------------------------------------------------------------------------

function ConvertTo-DebloatHashtable {
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-DebloatHashtable $p.Value }
        return $h
    }
    if ($InputObject -is [array]) {
        return ,@($InputObject | ForEach-Object { ConvertTo-DebloatHashtable $_ })
    }
    return $InputObject
}

function Get-DebloatBackup {
    if (-not (Test-Path $script:DebloatBackup)) { return @{} }
    try {
        $raw = Get-Content -Path $script:DebloatBackup -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
        $h = ConvertTo-DebloatHashtable (ConvertFrom-Json $raw)
        if ($h -is [hashtable]) { return $h }
    } catch {
        Write-DebloatLog "Backup file could not be read, starting a new one: $($_.Exception.Message)" -Level Warn
        Copy-Item $script:DebloatBackup "$($script:DebloatBackup).broken" -Force -ErrorAction SilentlyContinue
    }
    return @{}
}

function Save-DebloatBackup {
    param([Parameter(Mandatory)][hashtable]$Backup)
    if (-not (Test-Path $script:DebloatDataDir)) { New-Item -ItemType Directory -Path $script:DebloatDataDir -Force | Out-Null }
    $json = ConvertTo-Json -InputObject $Backup -Depth 8
    $tmp = "$($script:DebloatBackup).tmp"
    Set-Content -Path $tmp -Value $json -Encoding UTF8
    Move-Item -Path $tmp -Destination $script:DebloatBackup -Force
}

function Get-DebloatBackupEntry {
    param([hashtable]$Backup, [string]$TweakId)
    if (-not $Backup.ContainsKey($TweakId) -or -not ($Backup[$TweakId] -is [hashtable])) {
        $Backup[$TweakId] = @{ Registry = @{}; Services = @{}; Tasks = @{}; Saved = (Get-Date).ToString('s') }
    }
    foreach ($part in 'Registry', 'Services', 'Tasks') {
        if (-not ($Backup[$TweakId][$part] -is [hashtable])) { $Backup[$TweakId][$part] = @{} }
    }
    return $Backup[$TweakId]
}

# -----------------------------------------------------------------------------
# Services
# Start values: 2 = Automatic, 3 = Manual, 4 = Disabled (+ DelayedAutostart = 1)
# -----------------------------------------------------------------------------

function Get-DebloatServiceStart {
    param([Parameter(Mandatory)][string]$Name)
    $path = "HKLM\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-DebloatRegKey $path)) { return $null }
    $start = Read-DebloatRegValue -Path $path -Name 'Start'
    if (-not $start.Exists) { return $null }
    $delayed = Read-DebloatRegValue -Path $path -Name 'DelayedAutostart'
    $d = 0
    if ($delayed.Exists) { $d = [int]$delayed.Value }
    return @{ Start = [int]$start.Value; Delayed = $d }
}

function ConvertTo-DebloatStartValue {
    param([Parameter(Mandatory)][string]$StartupType)
    switch ($StartupType) {
        'Disabled'         { return @{ Start = 4; Delayed = 0 } }
        'Manual'           { return @{ Start = 3; Delayed = 0 } }
        'Automatic'        { return @{ Start = 2; Delayed = 0 } }
        'AutomaticDelayed' { return @{ Start = 2; Delayed = 1 } }
        default            { throw "Unknown startup type '$StartupType'" }
    }
}

function Set-DebloatServiceStart {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][int]$Start, [int]$Delayed = 0)
    $scValue = switch ($Start) {
        4 { 'disabled' } 3 { 'demand' } 2 { if ($Delayed -eq 1) { 'delayed-auto' } else { 'auto' } } 0 { 'boot' } 1 { 'system' }
    }
    $null = & sc.exe config $Name start= $scValue 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Some services refuse sc.exe; try the registry directly.
        $path = "HKLM\SYSTEM\CurrentControlSet\Services\$Name"
        Write-DebloatRegValue -Path $path -Name 'Start' -Value $Start -Type DWord
        if ($Start -eq 2) { Write-DebloatRegValue -Path $path -Name 'DelayedAutostart' -Value $Delayed -Type DWord }
    }
    $now = Get-DebloatServiceStart $Name
    if ($null -eq $now -or $now.Start -ne $Start) { throw "Windows refused to change service '$Name' (it may be protected)" }
    if ($Start -eq 4) { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
}

# -----------------------------------------------------------------------------
# Scheduled tasks
# -----------------------------------------------------------------------------

function Get-DebloatTask {
    param([Parameter(Mandatory)][string]$FullName)
    $idx = $FullName.LastIndexOf('\')
    $taskPath = $FullName.Substring(0, $idx + 1)
    $taskName = $FullName.Substring($idx + 1)
    return Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Apps (Appx)
# -----------------------------------------------------------------------------

function Update-DebloatAppCache {
    $admin = Test-DebloatAdmin
    try {
        if ($admin) { $script:AppxInstalled = @(Get-AppxPackage -AllUsers -ErrorAction Stop | Select-Object -ExpandProperty Name) }
        else        { $script:AppxInstalled = @(Get-AppxPackage -ErrorAction Stop | Select-Object -ExpandProperty Name) }
    } catch {
        $script:AppxInstalled = @(Get-AppxPackage -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    }
    $script:AppxProvisioned = @()
    if ($admin) {
        try { $script:AppxProvisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Select-Object -ExpandProperty DisplayName) } catch { }
    }
}

function Test-DebloatAppPresent {
    param([Parameter(Mandatory)][string]$Package)
    if ($null -eq $script:AppxInstalled) { Update-DebloatAppCache }
    $installed   = @($script:AppxInstalled   | Where-Object { $_ -like $Package }).Count -gt 0
    $provisioned = @($script:AppxProvisioned | Where-Object { $_ -like $Package }).Count -gt 0
    return ($installed -or $provisioned)
}

function Remove-DebloatApp {
    param([Parameter(Mandatory)][string]$Package)
    $errors = @()
    $admin = Test-DebloatAdmin
    $pkgs = if ($admin) { @(Get-AppxPackage -AllUsers -Name $Package -ErrorAction SilentlyContinue) }
            else        { @(Get-AppxPackage -Name $Package -ErrorAction SilentlyContinue) }
    foreach ($p in $pkgs) {
        try {
            if ($admin) { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop }
            else        { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop }
        } catch { $errors += $_.Exception.Message }
    }
    if ($admin) {
        $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $Package })
        foreach ($p in $prov) {
            try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -AllUsers -ErrorAction Stop | Out-Null }
            catch {
                try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null }
                catch { $errors += $_.Exception.Message }
            }
        }
    }
    Update-DebloatAppCache
    if (Test-DebloatAppPresent $Package) {
        $msg = 'Windows would not remove it'
        if ($errors.Count) { $msg = $errors[0] }
        throw $msg
    }
}

function Install-DebloatStoreApp {
    param([Parameter(Mandatory)][string]$StoreId)
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget is not available. Reinstall it from the Microsoft Store (ID $StoreId)."
    }
    $out = & winget.exe install --id $StoreId --source msstore --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2>&1
    # -1978335189 = already installed
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        $tail = ($out | Select-Object -Last 2) -join ' '
        throw "winget could not reinstall it (exit $LASTEXITCODE). Try the Microsoft Store, ID $StoreId. $tail"
    }
    Update-DebloatAppCache
}

# -----------------------------------------------------------------------------
# Tweak definitions
# -----------------------------------------------------------------------------

function Get-DebloatTweaks {
    if (-not $script:DebloatTweaks) { throw 'Tweaks.ps1 is not loaded' }
    return $script:DebloatTweaks
}

function Get-DebloatTweak {
    param([Parameter(Mandatory)][string]$Id)
    $t = Get-DebloatTweaks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $t) { throw "Unknown tweak id '$Id'" }
    return $t
}

function Get-DebloatPresetIds {
    param([Parameter(Mandatory)][ValidateSet('Minimal', 'Recommended', 'Everything')][string]$Preset)
    $level = [array]::IndexOf($script:PresetOrder, $Preset)
    Get-DebloatTweaks | Where-Object {
        $_.Preset -and $_.Risk -ne 'Advanced' -and ([array]::IndexOf($script:PresetOrder, $_.Preset) -le $level) -and (Test-DebloatTweakApplicable $_)
    } | ForEach-Object { $_.Id }
}

function Test-DebloatTweakApplicable {
    param([Parameter(Mandatory)]$Tweak)
    if ($Tweak.ContainsKey('MinBuild')) {
        $info = Get-DebloatWindowsInfo
        if ($info.Build -lt $Tweak.MinBuild) { return $false }
    }
    return $true
}

# -----------------------------------------------------------------------------
# Status
# Returns @{ Id; State; Text; Detail }
# State: Applied | NotApplied | Partial | NotApplicable | Unknown
# -----------------------------------------------------------------------------

function Get-DebloatTweakStatus {
    param([Parameter(Mandatory)]$Tweak)
    $id = $Tweak.Id
    try {
        if (-not (Test-DebloatTweakApplicable $Tweak)) {
            return @{ Id = $id; State = 'NotApplicable'; Text = 'Not for this Windows'; Detail = '' }
        }

        if ($Tweak.ContainsKey('App')) {
            if (Test-DebloatAppPresent $Tweak.App.Package) {
                return @{ Id = $id; State = 'NotApplied'; Text = 'Installed'; Detail = '' }
            }
            return @{ Id = $id; State = 'Applied'; Text = 'Not installed'; Detail = '' }
        }

        $total = 0; $done = 0; $missing = @()

        if ($Tweak.ContainsKey('Check')) {
            $total++
            if (& $Tweak.Check) { $done++ } else { $missing += 'custom check' }
        }
        foreach ($r in @($Tweak.Registry)) {
            if (-not $r) { continue }
            $total++
            $cur = Read-DebloatRegValue -Path $r.Path -Name $r.Name
            if ($cur.Exists -and (Test-DebloatValueEqual $cur.Value (Resolve-DebloatValue $r.Value))) { $done++ }
            else { $missing += "$($r.Path)\$($r.Name)" }
        }
        foreach ($s in @($Tweak.Services)) {
            if (-not $s) { continue }
            $cur = Get-DebloatServiceStart $s.Name
            if ($null -eq $cur) { continue }        # service not on this PC
            $total++
            $want = ConvertTo-DebloatStartValue $s.Start
            if ($cur.Start -eq $want.Start) { $done++ } else { $missing += "service $($s.Name)" }
        }
        foreach ($t in @($Tweak.Tasks)) {
            if (-not $t) { continue }
            $task = Get-DebloatTask $t
            if ($null -eq $task) { continue }       # task not on this PC
            $total++
            if ($task.State -eq 'Disabled') { $done++ } else { $missing += "task $t" }
        }

        $appliedText = 'Applied'; $notAppliedText = 'Not applied'
        if ($Tweak.ContainsKey('AppliedText'))    { $appliedText = $Tweak.AppliedText }
        if ($Tweak.ContainsKey('NotAppliedText')) { $notAppliedText = $Tweak.NotAppliedText }
        if ($total -eq 0)       { return @{ Id = $id; State = 'Applied'; Text = 'Nothing to change'; Detail = 'None of the parts exist on this PC' } }
        if ($done -eq $total)   { return @{ Id = $id; State = 'Applied'; Text = $appliedText; Detail = '' } }
        if ($done -eq 0)        { return @{ Id = $id; State = 'NotApplied'; Text = $notAppliedText; Detail = '' } }
        return @{ Id = $id; State = 'Partial'; Text = "Partial ($done/$total)"; Detail = ($missing -join '; ') }
    } catch {
        return @{ Id = $id; State = 'Unknown'; Text = 'Unknown'; Detail = $_.Exception.Message }
    }
}

# -----------------------------------------------------------------------------
# Apply / undo one tweak
# Returns @{ Id; Success; Message }
# -----------------------------------------------------------------------------

function Invoke-DebloatTweakApply {
    param([Parameter(Mandatory)]$Tweak, [Parameter(Mandatory)][hashtable]$Backup)
    $id = $Tweak.Id
    $problems = @()
    $entry = Get-DebloatBackupEntry -Backup $Backup -TweakId $id

    if ($Tweak.ContainsKey('App')) {
        if (-not (Test-DebloatAppPresent $Tweak.App.Package)) { return @{ Id = $id; Success = $true; Message = 'Already removed' } }
        Remove-DebloatApp $Tweak.App.Package
        return @{ Id = $id; Success = $true; Message = 'Removed' }
    }

    foreach ($r in @($Tweak.Registry)) {
        if (-not $r) { continue }
        try {
            $key = "$($r.Path)|$($r.Name)"
            if (-not $entry.Registry.ContainsKey($key)) {
                $cur = Read-DebloatRegValue -Path $r.Path -Name $r.Name
                $saved = @{ Existed = $cur.Exists; Kind = $cur.Kind; Value = $cur.Value }
                if ($cur.Value -is [byte[]]) { $saved.Value = [int[]]$cur.Value }
                $entry.Registry[$key] = $saved
            }
            $type = 'DWord'
            if ($r.ContainsKey('Type')) { $type = $r.Type }
            Write-DebloatRegValue -Path $r.Path -Name $r.Name -Value (Resolve-DebloatValue $r.Value) -Type $type
        } catch { $problems += "$($r.Path)\$($r.Name): $($_.Exception.Message)" }
    }
    Save-DebloatBackup $Backup

    foreach ($s in @($Tweak.Services)) {
        if (-not $s) { continue }
        try {
            $cur = Get-DebloatServiceStart $s.Name
            if ($null -eq $cur) { continue }
            if (-not $entry.Services.ContainsKey($s.Name)) { $entry.Services[$s.Name] = $cur }
            $want = ConvertTo-DebloatStartValue $s.Start
            if ($cur.Start -ne $want.Start) { Set-DebloatServiceStart -Name $s.Name -Start $want.Start -Delayed $want.Delayed }
        } catch { $problems += "service $($s.Name): $($_.Exception.Message)" }
    }
    Save-DebloatBackup $Backup

    foreach ($t in @($Tweak.Tasks)) {
        if (-not $t) { continue }
        try {
            $task = Get-DebloatTask $t
            if ($null -eq $task) { continue }
            if (-not $entry.Tasks.ContainsKey($t)) { $entry.Tasks[$t] = [string]$task.State }
            if ($task.State -ne 'Disabled') { $task | Disable-ScheduledTask -ErrorAction Stop | Out-Null }
        } catch { $problems += "task ${t}: $($_.Exception.Message)" }
    }
    Save-DebloatBackup $Backup

    if ($Tweak.ContainsKey('Apply')) {
        try { & $Tweak.Apply } catch { $problems += $_.Exception.Message }
    }

    if ($problems.Count) { return @{ Id = $id; Success = $false; Message = ($problems -join ' | ') } }
    return @{ Id = $id; Success = $true; Message = 'Applied' }
}

function Invoke-DebloatTweakUndo {
    param([Parameter(Mandatory)]$Tweak, [Parameter(Mandatory)][hashtable]$Backup)
    $id = $Tweak.Id
    $problems = @()
    $entry = $null
    if ($Backup.ContainsKey($id) -and $Backup[$id] -is [hashtable]) { $entry = $Backup[$id] }

    if ($Tweak.ContainsKey('App')) {
        if (Test-DebloatAppPresent $Tweak.App.Package) { return @{ Id = $id; Success = $true; Message = 'Already installed' } }
        if ($Tweak.App.Permanent) {
            return @{ Id = $id; Success = $false; Message = 'Microsoft no longer offers this app, so it cannot be reinstalled' }
        }
        if (-not $Tweak.App.StoreId) {
            return @{ Id = $id; Success = $false; Message = 'Reinstall it from the Microsoft Store or the maker''s website' }
        }
        Install-DebloatStoreApp $Tweak.App.StoreId
        return @{ Id = $id; Success = $true; Message = 'Reinstalled from the Microsoft Store' }
    }

    if ($Tweak.ContainsKey('Undo')) {
        try { & $Tweak.Undo } catch { $problems += $_.Exception.Message }
    }

    foreach ($r in @($Tweak.Registry)) {
        if (-not $r) { continue }
        $key = "$($r.Path)|$($r.Name)"
        try {
            if ($entry -and $entry.Registry -is [hashtable] -and $entry.Registry.ContainsKey($key)) {
                $saved = $entry.Registry[$key]
                if ($saved.Existed) {
                    $v = $saved.Value
                    if ($saved.Kind -eq 'Binary') { $v = [byte[]]@($saved.Value) }
                    Write-DebloatRegValue -Path $r.Path -Name $r.Name -Value $v -Type $saved.Kind
                } else {
                    Remove-DebloatRegValue -Path $r.Path -Name $r.Name
                }
            } elseif ($r.ContainsKey('Default')) {
                if ($null -eq $r.Default) { Remove-DebloatRegValue -Path $r.Path -Name $r.Name }
                else {
                    $type = 'DWord'; if ($r.ContainsKey('Type')) { $type = $r.Type }
                    Write-DebloatRegValue -Path $r.Path -Name $r.Name -Value $r.Default -Type $type
                }
            } else {
                Remove-DebloatRegValue -Path $r.Path -Name $r.Name
            }
        } catch { $problems += "$($r.Path)\$($r.Name): $($_.Exception.Message)" }
    }

    foreach ($s in @($Tweak.Services)) {
        if (-not $s) { continue }
        try {
            if ($null -eq (Get-DebloatServiceStart $s.Name)) { continue }
            if ($entry -and $entry.Services -is [hashtable] -and $entry.Services.ContainsKey($s.Name)) {
                $o = $entry.Services[$s.Name]
                Set-DebloatServiceStart -Name $s.Name -Start ([int]$o.Start) -Delayed ([int]$o.Delayed)
            } else {
                $d = ConvertTo-DebloatStartValue $s.Default
                Set-DebloatServiceStart -Name $s.Name -Start $d.Start -Delayed $d.Delayed
            }
        } catch { $problems += "service $($s.Name): $($_.Exception.Message)" }
    }

    foreach ($t in @($Tweak.Tasks)) {
        if (-not $t) { continue }
        try {
            $task = Get-DebloatTask $t
            if ($null -eq $task) { continue }
            $wasDisabled = $false
            if ($entry -and $entry.Tasks -is [hashtable] -and $entry.Tasks.ContainsKey($t)) { $wasDisabled = ($entry.Tasks[$t] -eq 'Disabled') }
            if (-not $wasDisabled -and $task.State -eq 'Disabled') { $task | Enable-ScheduledTask -ErrorAction Stop | Out-Null }
        } catch { $problems += "task ${t}: $($_.Exception.Message)" }
    }

    if ($problems.Count) { return @{ Id = $id; Success = $false; Message = ($problems -join ' | ') } }
    if ($Backup.ContainsKey($id)) { $Backup.Remove($id); Save-DebloatBackup $Backup }
    return @{ Id = $id; Success = $true; Message = 'Restored' }
}

# -----------------------------------------------------------------------------
# Restore point, Explorer restart
# -----------------------------------------------------------------------------

function New-DebloatRestorePoint {
    # Returns $true when a restore point was created
    $freqPath = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $oldFreq = Read-DebloatRegValue -Path $freqPath -Name 'SystemRestorePointCreationFrequency'
    try {
        # Windows allows one restore point per 24 hours unless this is lowered for the call.
        Write-DebloatRegValue -Path $freqPath -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord
        try {
            Checkpoint-Computer -Description 'Before Vanjix Debloat' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        } catch {
            Write-DebloatLog 'System Restore is off for the system drive. Turning it on to create a restore point...' -Level Warn
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
            Checkpoint-Computer -Description 'Before Vanjix Debloat' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        }
        return $true
    } catch {
        Write-DebloatLog "Could not create a restore point: $($_.Exception.Message)" -Level Error
        return $false
    } finally {
        if ($oldFreq.Exists) { Write-DebloatRegValue -Path $freqPath -Name 'SystemRestorePointCreationFrequency' -Value $oldFreq.Value -Type $oldFreq.Kind }
        else { Remove-DebloatRegValue -Path $freqPath -Name 'SystemRestorePointCreationFrequency' }
    }
}

function Restart-DebloatExplorer {
    Write-DebloatLog 'Restarting Explorer so taskbar and Explorer changes show up...'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

# -----------------------------------------------------------------------------
# Batch runner (used by both the GUI and the CLI)
# -----------------------------------------------------------------------------

function Invoke-DebloatBatch {
    param(
        [Parameter(Mandatory)][string[]]$Ids,
        [Parameter(Mandatory)][ValidateSet('Apply', 'Undo')][string]$Action,
        [bool]$CreateRestorePoint = $true,
        [bool]$RestartExplorer = $true
    )
    $tweaks = @($Ids | ForEach-Object { Get-DebloatTweak $_ })
    $total = $tweaks.Count
    Write-DebloatLog "$Action $total item(s)" -Level Header

    if ($CreateRestorePoint) {
        Write-DebloatLog 'Creating a restore point (this can take a minute)...'
        Send-DebloatEvent -Type 'progress' -Data @{ Done = 0; Total = $total; Text = 'Creating restore point...' }
        if (New-DebloatRestorePoint) { Write-DebloatLog 'Restore point created' -Level Success }
        else {
            Write-DebloatLog 'Stopped: no restore point. Untick "Create a restore point" (or use -NoRestorePoint) to continue without one.' -Level Error
            return @()
        }
    }

    Update-DebloatAppCache
    $backup = Get-DebloatBackup
    $results = @()
    $needExplorer = $false; $needReboot = $false
    $i = 0
    foreach ($t in $tweaks) {
        $i++
        Send-DebloatEvent -Type 'progress' -Data @{ Done = ($i - 1); Total = $total; Text = $t.Name }
        try {
            if (-not (Test-DebloatTweakApplicable $t)) {
                $r = @{ Id = $t.Id; Success = $true; Message = 'Skipped: not for this Windows version' }
            } elseif ($Action -eq 'Apply') {
                $r = Invoke-DebloatTweakApply -Tweak $t -Backup $backup
            } else {
                $r = Invoke-DebloatTweakUndo -Tweak $t -Backup $backup
            }
        } catch {
            $r = @{ Id = $t.Id; Success = $false; Message = $_.Exception.Message }
        }
        if ($r.Success) {
            Write-DebloatLog "$($t.Name): $($r.Message)" -Level Success
            if ($t.RestartExplorer) { $needExplorer = $true }
            if ($t.RebootRequired)  { $needReboot = $true }
        } else {
            Write-DebloatLog "$($t.Name): $($r.Message)" -Level Error
        }
        $results += $r
        Send-DebloatEvent -Type 'status' -Data @{ Status = (Get-DebloatTweakStatus $t) }
    }
    Save-DebloatBackup $backup
    Send-DebloatEvent -Type 'progress' -Data @{ Done = $total; Total = $total; Text = 'Done' }

    $ok = @($results | Where-Object { $_.Success }).Count
    $bad = $total - $ok
    $level = 'Success'; if ($bad) { $level = 'Warn' }
    Write-DebloatLog "Finished: $ok succeeded, $bad failed" -Level $level

    if ($needExplorer -and $RestartExplorer) { Restart-DebloatExplorer }
    elseif ($needExplorer) { Write-DebloatLog 'Some changes show up after Explorer restarts or you sign out.' -Level Warn }
    if ($needReboot) { Write-DebloatLog 'Some changes take full effect after a restart.' -Level Warn }
    return $results
}

function Get-DebloatAllStatus {
    Update-DebloatAppCache
    foreach ($t in Get-DebloatTweaks) { Get-DebloatTweakStatus $t }
}
