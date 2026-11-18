# =============================================================================
# Vanjix Debloat - tweak definitions
#
# Every item the tool can change lives here, as data. The engine (Engine.ps1)
# works out how to check, apply and undo each part:
#
#   Registry = @( @{ Path; Name; Value; Type = 'DWord'|'String'|...; Default } )
#   Services = @( @{ Name; Start = 'Disabled'|'Manual'|...; Default = <Windows default> } )
#   Tasks    = @( '\Path\To\Task' )
#   App      = @{ Package; StoreId; Permanent }
#   Check / Apply / Undo = { custom script blocks }
#
# Risk:   Safe | Moderate | Advanced   (Advanced is never in a preset)
# Preset: lowest preset that includes it: Minimal < Recommended < Everything
#         ($null = only when picked by hand)
#
# Keep this file ASCII only (Windows PowerShell 5.1 reads it as ANSI).
# =============================================================================

function New-DebloatAppTweak {
    param(
        [Parameter(Mandatory)][string]$Package,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [string]$Risk = 'Safe',
        $Preset = 'Recommended',
        [string]$StoreId = '',
        [switch]$Permanent,
        [string]$Warning = ''
    )
    $id = 'App.' + (($Package -replace '[^A-Za-z0-9]', '') -replace '^Microsoft', '')
    $t = @{
        Id          = $id
        Category    = 'Apps'
        Name        = "Remove $Name"
        Description = $Description
        Risk        = $Risk
        Preset      = $Preset
        App         = @{ Package = $Package; StoreId = $StoreId; Permanent = [bool]$Permanent }
    }
    if ($Warning) { $t.Warning = $Warning }
    return $t
}

$CDM  = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$ADV  = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$WUP  = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

$script:DebloatCategories = @(
    'Apps', 'Privacy', 'Ads & Tips', 'AI & Copilot', 'Start & Search',
    'Taskbar', 'Explorer', 'Services', 'Gaming', 'Windows Update'
)

$script:DebloatTweaks = @(

    # =========================================================================
    # APPS
    # =========================================================================
    (New-DebloatAppTweak 'Microsoft.BingNews'      'Microsoft News'   'News feed app. News is still on the web.' -StoreId '9WZDNCRFHVFW')
    (New-DebloatAppTweak 'Microsoft.BingWeather'   'Weather'          'MSN Weather app.' -StoreId '9WZDNCRFJ3Q2')
    (New-DebloatAppTweak 'Microsoft.BingFinance'   'Money'            'Retired MSN Money app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.BingSports'    'Sports'           'Retired MSN Sports app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.BingSearch'    'Bing Search'      'Bing search app that ships with newer Windows builds.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.GetHelp'       'Get Help'         'Microsoft support chat app.' -StoreId '9PKDZBMV1H3T')
    (New-DebloatAppTweak 'Microsoft.Getstarted'    'Tips'             'The Windows "Tips" app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.MicrosoftSolitaireCollection' 'Solitaire Collection' 'Card games with ads.' -StoreId '9WZDNCRFHWD2')
    (New-DebloatAppTweak 'Microsoft.3DBuilder'     '3D Builder'       'Old 3D printing app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.Microsoft3DViewer' '3D Viewer'    'Old 3D model viewer.' -StoreId '9NBLGGH42THS')
    (New-DebloatAppTweak 'Microsoft.Print3D'       'Print 3D'         'Old 3D printing app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.MSPaint'       'Paint 3D'         'Paint 3D (the normal Paint app is not touched).' -StoreId '9NBLGGH5FV99')
    (New-DebloatAppTweak 'Microsoft.MixedReality.Portal' 'Mixed Reality Portal' 'For Windows Mixed Reality headsets, which Microsoft discontinued.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.OneConnect'    'Mobile Plans'     'Mobile data plan app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.People'        'People'           'Old contacts app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.SkypeApp'      'Skype'            'Skype was shut down by Microsoft in 2025.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.Wallet'        'Wallet'           'Old payments app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.Messaging'     'Messaging'        'Old SMS app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.NetworkSpeedTest' 'Network Speed Test' 'Old speed test app.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.WindowsFeedbackHub' 'Feedback Hub' 'Sends feedback to Microsoft.' -StoreId '9NBLGGH4R32N')
    (New-DebloatAppTweak 'Microsoft.WindowsMaps'   'Maps'             'Windows Maps app.' -StoreId '9WZDNCRDTBVB')
    (New-DebloatAppTweak 'Microsoft.MicrosoftOfficeHub' 'Microsoft 365 hub' 'Launcher that advertises Microsoft 365. Installed Office apps are not touched.' -StoreId '9WZDNCRD29V9')
    (New-DebloatAppTweak 'Clipchamp.Clipchamp'     'Clipchamp'        'Video editor.' -StoreId '9P1J8S7CCWWT')
    (New-DebloatAppTweak 'Microsoft.PowerAutomateDesktop' 'Power Automate' 'Desktop automation tool.' -StoreId '9NFTCH6J7FHV')
    (New-DebloatAppTweak 'Microsoft.ZuneVideo'     'Movies & TV'      'Old video store and player.' -StoreId '9WZDNCRFJ3P2')
    (New-DebloatAppTweak 'Microsoft.549981C3F5F10' 'Cortana'          'Cortana app. Microsoft retired Cortana.' -Permanent)
    (New-DebloatAppTweak 'microsoft.windowscommunicationsapps' 'Mail and Calendar (old)' 'Retired Mail and Calendar apps. They stopped syncing at the end of 2024.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.Windows.DevHome' 'Dev Home'       'Developer dashboard that Microsoft retired.' -Permanent)
    (New-DebloatAppTweak 'Microsoft.Copilot'       'Copilot app'      'The Copilot AI app.' -StoreId '9NHT9RB2F4HD')

    (New-DebloatAppTweak 'king.com.*'              'Candy Crush and other King games' 'Sponsored games preinstalled on some PCs.' -Preset 'Recommended')
    (New-DebloatAppTweak 'SpotifyAB.SpotifyMusic'  'Spotify'          'Only if it came preinstalled and you do not use it.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9NCBCSZSJRSB')
    (New-DebloatAppTweak '*Disney*'                'Disney+'          'Sponsored app.' -Risk 'Moderate' -Preset 'Everything')
    (New-DebloatAppTweak 'BytedancePte.Ltd.TikTok' 'TikTok'           'Sponsored app.' -Risk 'Moderate' -Preset 'Everything')
    (New-DebloatAppTweak 'Facebook.*'              'Facebook, Instagram and Messenger' 'Sponsored apps.' -Risk 'Moderate' -Preset 'Everything')
    (New-DebloatAppTweak 'AmazonVideo.PrimeVideo'  'Prime Video'      'Sponsored app.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9P6RC76MSMMJ')
    (New-DebloatAppTweak '4DF9E0F8.Netflix'        'Netflix'          'Sponsored app.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9WZDNCRFJ3TJ')

    (New-DebloatAppTweak 'Microsoft.Todos'         'Microsoft To Do'  'To-do list app. Keep it if you use it.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9NBLGGH5R558')
    (New-DebloatAppTweak 'Microsoft.MicrosoftJournal' 'Journal'       'Pen note-taking app.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9N318R854RHH')
    (New-DebloatAppTweak 'Microsoft.Office.OneNote' 'OneNote for Windows 10' 'Old OneNote app (OneNote from Office is not touched).' -Risk 'Moderate' -Preset 'Everything' -StoreId '9WZDNCRFHVJL')
    (New-DebloatAppTweak 'Microsoft.OutlookForWindows' 'Outlook (new)' 'The new Outlook app. Keep it if you use it for mail.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9NRX63209R7B')
    (New-DebloatAppTweak 'MSTeams'                 'Microsoft Teams'  'Teams app. Keep it if you use Teams for work or school.' -Risk 'Moderate' -Preset 'Everything')
    (New-DebloatAppTweak 'MicrosoftTeams'          'Teams (personal, old)' 'Old personal Teams chat app.' -Risk 'Moderate' -Preset 'Everything' -Permanent)
    (New-DebloatAppTweak 'Microsoft.WindowsAlarms' 'Clock'            'Alarms, timer and stopwatch app.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9WZDNCRFJ3PR')
    (New-DebloatAppTweak 'Microsoft.WindowsCamera' 'Camera'           'Camera app. Other apps can still use your webcam.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9WZDNCRFJBBG')
    (New-DebloatAppTweak 'Microsoft.WindowsSoundRecorder' 'Sound Recorder' 'Voice recording app.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9WZDNCRFHWKN')
    (New-DebloatAppTweak 'Microsoft.YourPhone'     'Phone Link'       'Connects your phone to the PC.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9NMPJ99VJBWV')
    (New-DebloatAppTweak 'MicrosoftCorporationII.QuickAssist' 'Quick Assist' 'Remote help tool. Often abused by tech-support scammers.' -Risk 'Moderate' -Preset 'Everything' -StoreId '9P7BP5VNWKX5')

    (New-DebloatAppTweak 'Microsoft.ZuneMusic'     'Media Player'     'Default player for music and video files.' -Risk 'Moderate' -Preset $null -StoreId '9WZDNCRFJ3PT' -Warning 'Media Player is the default app for music and video files.')
    (New-DebloatAppTweak 'Microsoft.MicrosoftStickyNotes' 'Sticky Notes' 'Notes app.' -Risk 'Moderate' -Preset $null -StoreId '9NBLGGH4QGHW')
    (New-DebloatAppTweak 'Microsoft.GamingApp'     'Xbox app'         'Needed for PC Game Pass games.' -Risk 'Moderate' -Preset $null -StoreId '9MV0B5HZVK9Z' -Warning 'PC Game Pass games need the Xbox app.')
    (New-DebloatAppTweak 'Microsoft.XboxGamingOverlay' 'Game Bar'     'Win+G overlay for capture and performance widgets.' -Risk 'Moderate' -Preset $null -StoreId '9NZKPSTSNW4P')

    @{
        Id = 'App.OneDrive'; Category = 'Apps'; Name = 'Uninstall OneDrive'
        Description = 'Removes the OneDrive sync app. Files already on this PC stay where they are.'
        Risk = 'Moderate'; Preset = $null
        Warning = 'If your Desktop, Documents or Pictures are backed up to OneDrive, turn that off in OneDrive settings first. The tool refuses to continue while they are.'
        AppliedText = 'Not installed'; NotAppliedText = 'Installed'
        Check = {
            $paths = @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
                "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
                "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
            )
            -not ($paths | Where-Object { Test-Path $_ })
        }
        Apply = {
            $shell = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
            foreach ($f in 'Desktop', 'Personal', 'My Pictures') {
                $v = (Read-DebloatRegValue -Path $shell -Name $f).Value
                if ($v -and $v -match 'OneDrive') {
                    throw "Your $f folder is backed up to OneDrive ($v). Turn off folder backup in OneDrive settings first."
                }
            }
            Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
            $done = $false
            if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
                $null = & winget.exe uninstall --id Microsoft.OneDrive --exact --silent --accept-source-agreements --disable-interactivity 2>&1
                $done = ($LASTEXITCODE -eq 0)
            }
            if (-not $done) {
                $setup = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") +
                         @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\OneDrive\*\OneDriveSetup.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) |
                         Where-Object { Test-Path $_ } | Select-Object -First 1
                if (-not $setup) { throw 'Could not find the OneDrive uninstaller' }
                Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait
            }
        }
        Undo = {
            if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
                $null = & winget.exe install --id Microsoft.OneDrive --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
                if ($LASTEXITCODE -eq 0) { return }
            }
            $setup = "$env:SystemRoot\System32\OneDriveSetup.exe"
            if (-not (Test-Path $setup)) { $setup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" }
            if (-not (Test-Path $setup)) { throw 'Reinstall OneDrive from https://www.microsoft.com/microsoft-365/onedrive/download' }
            Start-Process -FilePath $setup -Wait
        }
    }

    # =========================================================================
    # PRIVACY
    # =========================================================================
    @{
        Id = 'Privacy.Telemetry'; Category = 'Privacy'; Name = 'Turn off telemetry'
        Description = 'Sends Microsoft only the minimum diagnostic data and stops the tracking service and data collection tasks.'
        Risk = 'Safe'; Preset = 'Minimal'; RebootRequired = $true
        Registry = @(
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
            @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0 }
        )
        Services = @(
            @{ Name = 'DiagTrack';        Start = 'Disabled'; Default = 'Automatic' }
            @{ Name = 'dmwappushservice'; Start = 'Disabled'; Default = 'Manual' }
        )
        Tasks = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
            '\Microsoft\Windows\Autochk\Proxy'
            '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
        )
    }
    @{
        Id = 'Privacy.ActivityHistory'; Category = 'Privacy'; Name = 'Turn off activity history'
        Description = 'Stops Windows from recording and uploading the apps and files you use.'
        Risk = 'Safe'; Preset = 'Minimal'
        Registry = @(
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0 }
        )
    }
    @{
        Id = 'Privacy.AdvertisingId'; Category = 'Privacy'; Name = 'Turn off advertising ID'
        Description = 'Stops apps from using an ID to show you personalised ads.'
        Risk = 'Safe'; Preset = 'Minimal'
        Registry = @(
            @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1 }
        )
    }
    @{
        Id = 'Privacy.Feedback'; Category = 'Privacy'; Name = 'Stop feedback requests'
        Description = 'Stops Windows from popping up "How likely are you to recommend..." surveys.'
        Risk = 'Safe'; Preset = 'Minimal'
        Registry = @(
            @{ Path = 'HKCU\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1 }
        )
    }
    @{
        Id = 'Privacy.DeliveryOptimization'; Category = 'Privacy'; Name = 'Stop sharing updates with other PCs'
        Description = 'Stops your PC uploading Windows updates to other people over the internet. Updates still download normally.'
        Risk = 'Safe'; Preset = 'Recommended'
        Registry = @(
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0 }
        )
    }
    @{
        Id = 'Privacy.InkingTyping'; Category = 'Privacy'; Name = 'Turn off inking and typing personalisation'
        Description = 'Stops Windows collecting your typing and handwriting to build a personal dictionary.'
        Risk = 'Safe'; Preset = 'Everything'
        Registry = @(
            @{ Path = 'HKCU\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Value = 1 }
            @{ Path = 'HKCU\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Value = 1 }
            @{ Path = 'HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore'; Name = 'HarvestContacts'; Value = 0 }
            @{ Path = 'HKCU\Software\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Value = 0 }
        )
    }
    @{
        Id = 'Privacy.LanguageList'; Category = 'Privacy'; Name = 'Hide your language list from websites'
        Description = 'Websites can no longer read your list of installed languages.'
        Risk = 'Safe'; Preset = 'Everything'
        Registry = @(
            @{ Path = 'HKCU\Control Panel\International\User Profile'; Name = 'HttpAcceptLanguageOptOut'; Value = 1 }
        )
    }
    @{
        Id = 'Privacy.ErrorReporting'; Category = 'Privacy'; Name = 'Turn off error reporting'
        Description = 'Stops sending crash reports to Microsoft.'
        Risk = 'Safe'; Preset = 'Everything'
        Registry = @(
            @{ Path = 'HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1 }
        )
        Services = @( @{ Name = 'WerSvc'; Start = 'Disabled'; Default = 'Manual' } )
    }

    # =========================================================================
    # ADS & TIPS
    # =========================================================================
    @{
        Id = 'Ads.Suggestions'; Category = 'Ads & Tips'; Name = 'Turn off tips and suggestions'
        Description = 'Removes suggested content in Start, Settings and notifications.'
        Risk = 'Safe'; Preset = 'Minimal'
        Registry = @(
            @{ Path = $CDM; Name = 'SubscribedContent-338388Enabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SubscribedContent-338389Enabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SubscribedContent-338393Enabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SubscribedContent-353694Enabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SubscribedContent-353696Enabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SystemPaneSuggestionsEnabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SoftLandingEnabled'; Value = 0 }
        )
    }
    @{
        Id = 'Ads.AutoInstallApps'; Category = 'Ads & Tips'; Name = 'Stop auto-installing suggested apps'
        Description = 'Stops Windows from quietly installing promoted apps and games like Candy Crush.'
        Risk = 'Safe'; Preset = 'Minimal'
        Registry = @(
            @{ Path = $CDM; Name = 'SilentInstalledAppsEnabled'; Value = 0 }
            @{ Path = $CDM; Name = 'PreInstalledAppsEnabled'; Value = 0 }
            @{ Path = $CDM; Name = 'OemPreInstalledAppsEnabled'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1 }
        )
    }
    @{
        Id = 'Ads.SetupNag'; Category = 'Ads & Tips'; Name = 'Stop "finish setting up your device" screens'
        Description = 'Stops the full-screen offers for Microsoft 365, OneDrive and Game Pass after updates.'
        Risk = 'Safe'; Preset = 'Minimal'
        Registry = @(
            @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SubscribedContent-310093Enabled'; Value = 0 }
        )
    }
    @{
        Id = 'Ads.LockScreenTips'; Category = 'Ads & Tips'; Name = 'Remove tips and ads on the lock screen'
        Description = 'Removes "fun facts", tips and promotions from the lock screen.'
        Risk = 'Safe'; Preset = 'Recommended'
        Registry = @(
            @{ Path = $CDM; Name = 'RotatingLockScreenOverlayEnabled'; Value = 0 }
            @{ Path = $CDM; Name = 'SubscribedContent-338387Enabled'; Value = 0 }
        )
    }
    @{
        Id = 'Ads.ExplorerAds'; Category = 'Ads & Tips'; Name = 'Remove ads in File Explorer'
        Description = 'Stops OneDrive and Microsoft 365 promotions inside File Explorer.'
        Risk = 'Safe'; Preset = 'Recommended'; RestartExplorer = $true
        Registry = @( @{ Path = $ADV; Name = 'ShowSyncProviderNotifications'; Value = 0 } )
    }
    @{
        Id = 'Ads.Spotlight'; Category = 'Ads & Tips'; Name = 'Turn off Windows Spotlight on the lock screen'
        Description = 'Stops the rotating Bing pictures on the lock screen. You can pick your own picture instead.'
        Risk = 'Safe'; Preset = 'Everything'
        Registry = @( @{ Path = $CDM; Name = 'RotatingLockScreenEnabled'; Value = 0 } )
    }

    # =========================================================================
    # AI & COPILOT
    # =========================================================================
    @{
        Id = 'AI.Copilot'; Category = 'AI & Copilot'; Name = 'Turn off Windows Copilot'
        Description = 'Turns off Copilot in Windows and hides its taskbar button.'
        Risk = 'Safe'; Preset = 'Recommended'; RestartExplorer = $true; MinBuild = 22000
        Registry = @(
            @{ Path = 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
            @{ Path = $ADV; Name = 'ShowCopilotButton'; Value = 0 }
        )
    }
    @{
        Id = 'AI.Recall'; Category = 'AI & Copilot'; Name = 'Turn off Recall'
        Description = 'Stops Windows taking and analysing screenshots of everything you do (Copilot+ PCs).'
        Risk = 'Safe'; Preset = 'Recommended'; MinBuild = 26100
        Registry = @(
            @{ Path = 'HKCU\Software\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'AllowRecallEnablement'; Value = 0 }
        )
    }
    @{
        Id = 'AI.ClickToDo'; Category = 'AI & Copilot'; Name = 'Turn off Click to Do'
        Description = 'Turns off the AI actions overlay for text and images on screen (Copilot+ PCs).'
        Risk = 'Safe'; Preset = 'Everything'; MinBuild = 26100
        Registry = @(
            @{ Path = 'HKCU\Software\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Value = 1 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Value = 1 }
        )
    }
    @{
        Id = 'AI.EdgeSidebar'; Category = 'AI & Copilot'; Name = 'Turn off the Copilot sidebar in Edge'
        Description = 'Hides the Copilot sidebar in Microsoft Edge.'
        Risk = 'Safe'; Preset = 'Everything'
        Warning = 'Edge will say it is "managed by your organization". That is normal for this setting.'
        Registry = @( @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Edge'; Name = 'HubsSidebarEnabled'; Value = 0 } )
    }

    # =========================================================================
    # START & SEARCH
    # =========================================================================
    @{
        Id = 'Search.WebResults'; Category = 'Start & Search'; Name = 'Remove Bing web results from Start search'
        Description = 'Start search only finds things on your PC, without sending what you type to Bing.'
        Risk = 'Safe'; Preset = 'Recommended'; RestartExplorer = $true
        Registry = @(
            @{ Path = 'HKCU\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1 }
            @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0 }
        )
    }
    @{
        Id = 'Search.Highlights'; Category = 'Start & Search'; Name = 'Turn off search highlights'
        Description = 'Removes the trending searches and daily pictures in the search box.'
        Risk = 'Safe'; Preset = 'Recommended'
        Registry = @(
            @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDynamicSearchBoxEnabled'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'EnableDynamicContentInWSB'; Value = 0 }
        )
    }
    @{
        Id = 'Start.Recommendations'; Category = 'Start & Search'; Name = 'Remove app promotions in Start'
        Description = 'Removes recommended apps and Microsoft account nags from the Start menu.'
        Risk = 'Safe'; Preset = 'Recommended'; RestartExplorer = $true; MinBuild = 22000
        Registry = @(
            @{ Path = $ADV; Name = 'Start_IrisRecommendations'; Value = 0 }
            @{ Path = $ADV; Name = 'Start_AccountNotifications'; Value = 0 }
        )
    }

    # =========================================================================
    # TASKBAR
    # =========================================================================
    @{
        Id = 'Taskbar.Widgets'; Category = 'Taskbar'; Name = 'Turn off Widgets and News'
        Description = 'Removes the Widgets and News and Interests panel and its weather button.'
        Risk = 'Safe'; Preset = 'Recommended'; RestartExplorer = $true
        Registry = @(
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'; Name = 'EnableFeeds'; Value = 0 }
        )
    }
    @{
        Id = 'Taskbar.EndTask'; Category = 'Taskbar'; Name = 'Add "End task" to taskbar right-click'
        Description = 'Right-click an app on the taskbar to force-close it.'
        Risk = 'Safe'; Preset = 'Everything'; MinBuild = 22631
        Registry = @( @{ Path = "$ADV\TaskbarDeveloperSettings"; Name = 'TaskbarEndTask'; Value = 1 } )
    }
    @{
        Id = 'Taskbar.TaskView'; Category = 'Taskbar'; Name = 'Hide the Task View button'
        Description = 'Win+Tab still works.'
        Risk = 'Safe'; Preset = $null; RestartExplorer = $true
        Registry = @( @{ Path = $ADV; Name = 'ShowTaskViewButton'; Value = 0; Default = 1 } )
    }
    @{
        Id = 'Taskbar.SearchIcon'; Category = 'Taskbar'; Name = 'Show search as an icon'
        Description = 'Replaces the wide search box with a small icon.'
        Risk = 'Safe'; Preset = $null; RestartExplorer = $true
        Registry = @( @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 1 } )
    }
    @{
        Id = 'Taskbar.AlignLeft'; Category = 'Taskbar'; Name = 'Move taskbar icons to the left'
        Description = 'Puts the Start button back in the corner, like Windows 10.'
        Risk = 'Safe'; Preset = $null; RestartExplorer = $true; MinBuild = 22000
        Registry = @( @{ Path = $ADV; Name = 'TaskbarAl'; Value = 0; Default = 1 } )
    }

    # =========================================================================
    # EXPLORER
    # =========================================================================
    @{
        Id = 'Explorer.FileExtensions'; Category = 'Explorer'; Name = 'Show file extensions'
        Description = 'Shows .exe, .pdf and so on. Makes fake files like "invoice.pdf.exe" easy to spot.'
        Risk = 'Safe'; Preset = 'Everything'; RestartExplorer = $true
        Registry = @( @{ Path = $ADV; Name = 'HideFileExt'; Value = 0; Default = 1 } )
    }
    @{
        Id = 'Explorer.HiddenFiles'; Category = 'Explorer'; Name = 'Show hidden files'
        Description = 'Shows hidden files and folders such as AppData.'
        Risk = 'Safe'; Preset = $null; RestartExplorer = $true
        Registry = @( @{ Path = $ADV; Name = 'Hidden'; Value = 1; Default = 2 } )
    }
    @{
        Id = 'Explorer.OpenThisPC'; Category = 'Explorer'; Name = 'Open File Explorer to This PC'
        Description = 'File Explorer opens on your drives instead of Home.'
        Risk = 'Safe'; Preset = $null
        Registry = @( @{ Path = $ADV; Name = 'LaunchTo'; Value = 1 } )
    }
    @{
        Id = 'Explorer.HideGallery'; Category = 'Explorer'; Name = 'Hide Gallery in File Explorer'
        Description = 'Removes Gallery from the File Explorer sidebar.'
        Risk = 'Safe'; Preset = $null; RestartExplorer = $true; MinBuild = 22621
        Registry = @( @{ Path = 'HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; Name = 'System.IsPinnedToNameSpaceTree'; Value = 0 } )
    }
    @{
        Id = 'Explorer.ClassicMenu'; Category = 'Explorer'; Name = 'Use the classic right-click menu'
        Description = 'Shows the full right-click menu without "Show more options".'
        Risk = 'Safe'; Preset = $null; RestartExplorer = $true; MinBuild = 22000
        Registry = @( @{ Path = 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; Name = ''; Value = ''; Type = 'String' } )
        Undo = { Remove-DebloatRegKey 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' }
    }

    # =========================================================================
    # SERVICES
    # =========================================================================
    @{
        Id = 'Services.Unused'; Category = 'Services'; Name = 'Turn off rarely used services'
        Description = 'Retail demo mode, fax, Windows Insider and media sharing services.'
        Risk = 'Safe'; Preset = 'Everything'
        Warning = 'Windows Insider builds stop working while the Insider service is off.'
        Services = @(
            @{ Name = 'RetailDemo';    Start = 'Disabled'; Default = 'Manual' }
            @{ Name = 'Fax';           Start = 'Disabled'; Default = 'Manual' }
            @{ Name = 'wisvc';         Start = 'Disabled'; Default = 'Manual' }
            @{ Name = 'WMPNetworkSvc'; Start = 'Disabled'; Default = 'Manual' }
        )
    }
    @{
        Id = 'Services.LinkTracking'; Category = 'Services'; Name = 'Turn off link tracking'
        Description = 'Keeps shortcuts to files on network drives updated. Home PCs rarely need it.'
        Risk = 'Safe'; Preset = 'Everything'
        Services = @( @{ Name = 'TrkWks'; Start = 'Disabled'; Default = 'Automatic' } )
    }
    @{
        Id = 'Services.SysMain'; Category = 'Services'; Name = 'Turn off SysMain (Superfetch)'
        Description = 'Preloads apps you use often. Turning it off can lower disk use on old hard drives, but apps may open slower.'
        Risk = 'Moderate'; Preset = $null
        Services = @( @{ Name = 'SysMain'; Start = 'Disabled'; Default = 'Automatic' } )
    }

    # =========================================================================
    # GAMING
    # =========================================================================
    @{
        Id = 'Gaming.GameDVR'; Category = 'Gaming'; Name = 'Turn off background game recording'
        Description = 'Stops Game Bar recording gameplay in the background.'
        Risk = 'Safe'; Preset = 'Everything'
        Registry = @(
            @{ Path = 'HKCU\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; Default = 1 }
            @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0 }
            @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Value = 0 }
        )
    }
    @{
        Id = 'Gaming.XboxServices'; Category = 'Gaming'; Name = 'Turn off Xbox Live services'
        Description = 'Only if you never play Xbox or Game Pass games on this PC.'
        Risk = 'Moderate'; Preset = $null
        Warning = 'Game Pass and Xbox games will not sign in or sync saves until you undo this.'
        Services = @(
            @{ Name = 'XblAuthManager'; Start = 'Disabled'; Default = 'Manual' }
            @{ Name = 'XblGameSave';    Start = 'Disabled'; Default = 'Manual' }
            @{ Name = 'XboxNetApiSvc';  Start = 'Disabled'; Default = 'Manual' }
        )
    }

    # =========================================================================
    # WINDOWS UPDATE  (Advanced - never in a preset)
    # =========================================================================
    @{
        Id = 'Update.NoAutoUpdate'; Category = 'Windows Update'; Name = 'Stop automatic updates'
        Description = 'Windows stops installing updates and restarting on its own. You can still install updates in Settings > Windows Update.'
        Risk = 'Advanced'; Preset = $null; RebootRequired = $true
        Warning = 'You must check for updates yourself, or your PC will miss security fixes.'
        Registry = @(
            @{ Path = "$WUP\AU"; Name = 'NoAutoUpdate'; Value = 1 }
            @{ Path = "$WUP\AU"; Name = 'AUOptions'; Value = 2 }
            @{ Path = "$WUP\AU"; Name = 'NoAutoRebootWithLoggedOnUsers'; Value = 1 }
        )
    }
    @{
        Id = 'Update.NoDrivers'; Category = 'Windows Update'; Name = 'Stop driver updates through Windows Update'
        Description = 'Windows Update stops replacing your graphics and other drivers. Get drivers from the maker instead.'
        Risk = 'Advanced'; Preset = $null
        Registry = @( @{ Path = $WUP; Name = 'ExcludeWUDriversInQualityUpdate'; Value = 1 } )
    }
    @{
        Id = 'Update.StayOnVersion'; Category = 'Windows Update'; Name = 'Stay on your current Windows version'
        Description = 'Blocks big yearly feature upgrades. Monthly security updates still install.'
        Risk = 'Advanced'; Preset = $null
        Warning = 'Each Windows version stops getting security updates when Microsoft ends its support. Undo this before then.'
        Registry = @(
            @{ Path = $WUP; Name = 'TargetReleaseVersion'; Value = 1 }
            @{ Path = $WUP; Name = 'ProductVersion'; Type = 'String'; Value = { (Get-DebloatWindowsInfo).ProductName } }
            @{ Path = $WUP; Name = 'TargetReleaseVersionInfo'; Type = 'String'; Value = { (Get-DebloatWindowsInfo).DisplayVersion } }
        )
    }
    @{
        Id = 'Update.FullBlock'; Category = 'Windows Update'; Name = 'Fully block Windows Update'
        Description = 'Turns off the update services and points Windows Update at a server that does not exist. Nothing updates until you undo it.'
        Risk = 'Advanced'; Preset = $null; RebootRequired = $true
        Warning = 'No security updates at all. Microsoft Defender virus definitions and Microsoft Store updates may also fail. Undo this item to turn updates back on.'
        Registry = @(
            @{ Path = $WUP; Name = 'WUServer'; Type = 'String'; Value = 'http://127.0.0.1:8531' }
            @{ Path = $WUP; Name = 'WUStatusServer'; Type = 'String'; Value = 'http://127.0.0.1:8531' }
            @{ Path = $WUP; Name = 'DoNotConnectToWindowsUpdateInternetLocations'; Value = 1 }
            @{ Path = "$WUP\AU"; Name = 'UseWUServer'; Value = 1 }
        )
        Services = @(
            @{ Name = 'wuauserv'; Start = 'Disabled'; Default = 'Manual' }
            @{ Name = 'UsoSvc';   Start = 'Disabled'; Default = 'AutomaticDelayed' }
        )
    }
)
