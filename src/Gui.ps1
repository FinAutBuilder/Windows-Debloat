# =============================================================================
# Vanjix Debloat - WPF window
# All work runs in a background runspace; the window reads its progress from a
# queue on a timer, so it never freezes.
# Keep this file ASCII only.
# =============================================================================

function Show-DebloatGui {
    param([Parameter(Mandatory)][string[]]$Sources)

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    # Double-quoted here-string on purpose: build.ps1 embeds this file in a single-quoted one.
    # The XAML must therefore never contain a dollar sign or a backtick.
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Vanjix Debloat" Width="1180" Height="780" MinWidth="900" MinHeight="600"
        WindowStartupLocation="CenterScreen" Background="#0B0B10" Foreground="#E6E6F0"
        FontFamily="Segoe UI" FontSize="13">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#E6E6F0"/>
      <Setter Property="Background" Value="#1C1C28"/>
      <Setter Property="BorderBrush" Value="#2E2E40"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="BorderBrush" Value="#8B5CF6"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="b" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#7C3AED"/>
      <Setter Property="BorderBrush" Value="#7C3AED"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E6E6F0"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#14141C"/>
      <Setter Property="Foreground" Value="#E6E6F0"/>
      <Setter Property="BorderBrush" Value="#2E2E40"/>
      <Setter Property="CaretBrush" Value="#E6E6F0"/>
      <Setter Property="Padding" Value="8,6"/>
    </Style>
    <Style TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="#C9C9D6"/>
      <Setter Property="Padding" Value="12,5"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="{TemplateBinding Padding}" Margin="0,1">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1A1A26"/></Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="b" Property="Background" Value="#2A1F4A"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="LogItem" TargetType="ListBoxItem">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <ContentPresenter Margin="10,1"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="150"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <DockPanel Grid.Row="0" Margin="0,0,0,14">
      <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
        <TextBlock Text="VANJIX" FontSize="26" FontWeight="Bold" Foreground="#8B5CF6"/>
        <TextBlock Text=" DEBLOAT" FontSize="26" FontWeight="Bold" Foreground="#E6E6F0"/>
        <TextBlock x:Name="VersionText" Margin="12,0,0,3" VerticalAlignment="Bottom" Foreground="#6B6B80"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
        <TextBlock x:Name="WindowsText" Foreground="#9A9AAE" VerticalAlignment="Center" Margin="0,0,14,0"/>
        <Border x:Name="AdminBadge" CornerRadius="10" Padding="10,3" Background="#14532D">
          <TextBlock x:Name="AdminText" Text="Administrator" Foreground="#BBF7D0" FontSize="12"/>
        </Border>
      </StackPanel>
    </DockPanel>

    <!-- Toolbar -->
    <DockPanel Grid.Row="1" Margin="0,0,0,12">
      <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
        <TextBlock Text="Presets:" VerticalAlignment="Center" Foreground="#9A9AAE" Margin="0,0,10,0"/>
        <Button x:Name="PresetMinimal" Content="Minimal" ToolTip="Privacy, ads and tips only. Nothing is uninstalled."/>
        <Button x:Name="PresetRecommended" Content="Recommended" ToolTip="Minimal plus preinstalled junk apps, Copilot, Bing in Start and Widgets."/>
        <Button x:Name="PresetEverything" Content="Everything" ToolTip="Recommended plus apps some people use. Never includes Advanced items."/>
        <Button x:Name="ClearSelection" Content="Clear"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Grid Width="240">
          <TextBox x:Name="SearchBox"/>
          <TextBlock x:Name="SearchHint" Text="Search..." Foreground="#5A5A6E" Margin="11,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
        </Grid>
        <Button x:Name="RefreshButton" Content="Refresh status" Margin="8,0,0,0"/>
      </StackPanel>
    </DockPanel>

    <!-- Body -->
    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="200"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border Grid.Column="0" Background="#101018" CornerRadius="8" Padding="6" Margin="0,0,12,0">
        <ListBox x:Name="CategoryList" Background="Transparent" BorderThickness="0"/>
      </Border>
      <Border Grid.Column="1" Background="#101018" CornerRadius="8">
        <DockPanel>
          <Border x:Name="AdvancedBanner" DockPanel.Dock="Top" Background="#3B1212" CornerRadius="8,8,0,0" Padding="14,10" Visibility="Collapsed">
            <TextBlock TextWrapping="Wrap" Foreground="#FECACA">
              <Bold>Advanced:</Bold> these settings change how Windows updates itself. Presets never pick them. Without updates your PC misses security fixes, so check for updates yourself and undo these when you want updates back.
            </TextBlock>
          </Border>
          <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="6">
            <StackPanel x:Name="ItemPanel"/>
          </ScrollViewer>
        </DockPanel>
      </Border>
    </Grid>

    <!-- Log -->
    <Border Grid.Row="3" Background="#08080C" BorderBrush="#1E1E2A" BorderThickness="1" CornerRadius="8" Margin="0,12,0,0">
      <ListBox x:Name="LogList" Background="Transparent" BorderThickness="0" FontFamily="Consolas" FontSize="12" Padding="0,6"
               ItemContainerStyle="{StaticResource LogItem}"
               ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
    </Border>

    <!-- Footer -->
    <DockPanel Grid.Row="4" Margin="0,12,0,0">
      <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
        <CheckBox x:Name="RestorePointCheck" Content="Create a restore point first" IsChecked="True" Margin="0,0,16,0"/>
        <CheckBox x:Name="ExplorerCheck" Content="Restart Explorer when needed" IsChecked="True" Margin="0,0,16,0"/>
        <Button x:Name="SaveButton" Content="Save selection"/>
        <Button x:Name="LoadButton" Content="Load selection"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
        <TextBlock x:Name="ProgressText" Foreground="#9A9AAE" VerticalAlignment="Center" Margin="0,0,10,0"/>
        <ProgressBar x:Name="Progress" Width="160" Height="8" Margin="0,0,14,0" Background="#1C1C28" Foreground="#8B5CF6" BorderThickness="0"/>
        <TextBlock x:Name="SelectedText" Foreground="#9A9AAE" VerticalAlignment="Center" Margin="0,0,12,0"/>
        <Button x:Name="UndoButton" Content="Undo selected"/>
        <Button x:Name="ApplyButton" Content="Apply selected" Style="{StaticResource Primary}" Margin="0"/>
      </StackPanel>
    </DockPanel>
  </Grid>
</Window>
"@

    $win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
    $ui = @{}
    foreach ($n in 'VersionText', 'WindowsText', 'AdminBadge', 'AdminText', 'PresetMinimal', 'PresetRecommended',
                   'PresetEverything', 'ClearSelection', 'SearchBox', 'SearchHint', 'RefreshButton', 'CategoryList', 'AdvancedBanner',
                   'ItemPanel', 'LogList', 'RestorePointCheck', 'ExplorerCheck', 'SaveButton', 'LoadButton',
                   'ProgressText', 'Progress', 'SelectedText', 'UndoButton', 'ApplyButton') {
        $ui[$n] = $win.FindName($n)
    }

    $script:Gui = @{
        Window   = $win
        Ui       = $ui
        Rows     = [ordered]@{}
        Status   = @{}
        Queue    = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
        Sources  = $Sources
        Job      = $null
        Busy     = $false
        Category = 'All'
    }

    $bc = New-Object System.Windows.Media.BrushConverter
    $script:Gui.Brush = @{}
    foreach ($pair in @(
        @('Safe', '#22C55E'), @('Moderate', '#F59E0B'), @('Advanced', '#EF4444'),
        @('Applied', '#4ADE80'), @('NotApplied', '#9A9AAE'), @('Partial', '#FBBF24'),
        @('Unknown', '#6B6B80'), @('NotApplicable', '#4B4B5C'),
        @('Info', '#9A9AAE'), @('Success', '#4ADE80'), @('Warn', '#FBBF24'), @('Error', '#F87171'), @('Header', '#A78BFA'),
        @('Muted', '#8A8A9E'), @('Text', '#E6E6F0'), @('Row', '#14141E'), @('RowHover', '#1A1A28'))) {
        $script:Gui.Brush[$pair[0]] = $bc.ConvertFromString($pair[1])
    }

    # ---- header -------------------------------------------------------------
    $info = Get-DebloatWindowsInfo
    $ui.VersionText.Text = "v$script:DebloatVersion"
    $ui.WindowsText.Text = "$($info.ProductName) $($info.DisplayVersion) (build $($info.Build))"
    if (-not (Test-DebloatAdmin)) {
        $ui.AdminBadge.Background = $bc.ConvertFromString('#3B1212')
        $ui.AdminText.Text = 'Not administrator - view only'
        $ui.AdminText.Foreground = $bc.ConvertFromString('#FECACA')
    }

    # ---- item rows ----------------------------------------------------------
    foreach ($t in Get-DebloatTweaks) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = $script:Gui.Brush.Row
        $row.CornerRadius = '6'
        $row.Margin = '0,0,0,4'
        $row.Padding = '10,8'

        $grid = New-Object System.Windows.Controls.Grid
        foreach ($w in 32, -1, 96, 150) {
            $cd = New-Object System.Windows.Controls.ColumnDefinition
            if ($w -lt 0) { $cd.Width = New-Object System.Windows.GridLength(1, 'Star') } else { $cd.Width = New-Object System.Windows.GridLength($w) }
            $grid.ColumnDefinitions.Add($cd)
        }

        $check = New-Object System.Windows.Controls.CheckBox
        $check.Tag = $t.Id
        $check.VerticalAlignment = 'Center'
        [System.Windows.Controls.Grid]::SetColumn($check, 0)

        $text = New-Object System.Windows.Controls.StackPanel
        $title = New-Object System.Windows.Controls.TextBlock
        $title.Text = $t.Name
        $title.FontWeight = 'SemiBold'
        $title.Foreground = $script:Gui.Brush.Text
        $desc = New-Object System.Windows.Controls.TextBlock
        $desc.Text = $t.Description
        $desc.TextWrapping = 'Wrap'
        $desc.Foreground = $script:Gui.Brush.Muted
        $desc.FontSize = 12
        $desc.Margin = '0,2,12,0'
        [void]$text.Children.Add($title)
        [void]$text.Children.Add($desc)
        if ($t.Warning) {
            $warn = New-Object System.Windows.Controls.TextBlock
            $warn.Text = "Note: $($t.Warning)"
            $warn.TextWrapping = 'Wrap'
            $warn.Foreground = $script:Gui.Brush.Warn
            $warn.FontSize = 12
            $warn.Margin = '0,2,12,0'
            [void]$text.Children.Add($warn)
        }
        [System.Windows.Controls.Grid]::SetColumn($text, 1)

        $risk = New-Object System.Windows.Controls.TextBlock
        $risk.Text = $t.Risk
        $risk.Foreground = $script:Gui.Brush[$t.Risk]
        $risk.VerticalAlignment = 'Center'
        $risk.FontSize = 12
        [System.Windows.Controls.Grid]::SetColumn($risk, 2)

        $status = New-Object System.Windows.Controls.TextBlock
        $status.Text = 'Checking...'
        $status.Foreground = $script:Gui.Brush.Unknown
        $status.VerticalAlignment = 'Center'
        $status.TextAlignment = 'Right'
        [System.Windows.Controls.Grid]::SetColumn($status, 3)

        foreach ($c in $check, $text, $risk, $status) { [void]$grid.Children.Add($c) }
        $row.Child = $grid
        $row.Tag = $t.Id
        $row.Add_MouseLeftButtonUp({
            param($s, $e)
            if ($e.OriginalSource -is [System.Windows.Controls.CheckBox]) { return }
            $r = $script:Gui.Rows[[string]$s.Tag]
            if ($r.Check.IsEnabled) { $r.Check.IsChecked = -not $r.Check.IsChecked; Update-DebloatGuiCount }
        })
        $check.Add_Click({ Update-DebloatGuiCount })

        [void]$ui.ItemPanel.Children.Add($row)
        $script:Gui.Rows[$t.Id] = @{
            Tweak  = $t
            Row    = $row
            Check  = $check
            Status = $status
            Search = ("$($t.Name) $($t.Description) $($t.Category)").ToLower()
        }
    }

    # ---- categories ---------------------------------------------------------
    [void]$ui.CategoryList.Items.Add('All')
    foreach ($c in $script:DebloatCategories) { [void]$ui.CategoryList.Items.Add($c) }
    [void]$ui.CategoryList.Items.Add('Selected')
    $ui.CategoryList.SelectedIndex = 0
    $ui.CategoryList.Add_SelectionChanged({
        $script:Gui.Category = [string]$script:Gui.Ui.CategoryList.SelectedItem
        Update-DebloatGuiFilter
    })
    $ui.SearchBox.Add_TextChanged({
        if ($script:Gui.Ui.SearchBox.Text) { $script:Gui.Ui.SearchHint.Visibility = 'Collapsed' }
        else { $script:Gui.Ui.SearchHint.Visibility = 'Visible' }
        Update-DebloatGuiFilter
    })

    # ---- buttons ------------------------------------------------------------
    $ui.PresetMinimal.Add_Click({ Select-DebloatGuiPreset 'Minimal' })
    $ui.PresetRecommended.Add_Click({ Select-DebloatGuiPreset 'Recommended' })
    $ui.PresetEverything.Add_Click({ Select-DebloatGuiPreset 'Everything' })
    $ui.ClearSelection.Add_Click({
        foreach ($r in $script:Gui.Rows.Values) { $r.Check.IsChecked = $false }
        Update-DebloatGuiCount
    })
    $ui.RefreshButton.Add_Click({ Start-DebloatGuiJob -Mode 'Status' })
    $ui.ApplyButton.Add_Click({ Invoke-DebloatGuiAction -Action 'Apply' })
    $ui.UndoButton.Add_Click({ Invoke-DebloatGuiAction -Action 'Undo' })
    $ui.SaveButton.Add_Click({ Save-DebloatGuiSelection })
    $ui.LoadButton.Add_Click({ Import-DebloatGuiSelection })

    if (-not (Test-DebloatAdmin)) {
        $ui.ApplyButton.IsEnabled = $false
        $ui.UndoButton.IsEnabled = $false
    }

    # ---- queue pump ---------------------------------------------------------
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(120)
    $timer.Add_Tick({ Receive-DebloatGuiEvents })
    $timer.Start()

    $win.Add_Closing({
        param($s, $e)
        if ($script:Gui.Busy) {
            $answer = [System.Windows.MessageBox]::Show('Changes are still being made. Closing now can leave an item half done. Close anyway?', 'Vanjix Debloat', 'YesNo', 'Warning')
            if ($answer -ne 'Yes') { $e.Cancel = $true }
        }
    })

    Add-DebloatGuiLog -Level 'Header' -Text "Vanjix Debloat v$script:DebloatVersion - nothing is changed until you press Apply."
    Add-DebloatGuiLog -Level 'Info' -Text "Backups and logs: $script:DebloatDataDir"
    Update-DebloatGuiCount
    $win.Add_ContentRendered({ Start-DebloatGuiJob -Mode 'Status' })
    [void]$win.ShowDialog()
    $timer.Stop()
}

# -----------------------------------------------------------------------------
# GUI helpers (all run on the UI thread)
# -----------------------------------------------------------------------------

function Add-DebloatGuiLog {
    param([string]$Level = 'Info', [string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.TextWrapping = 'Wrap'
    $tb.Foreground = $script:Gui.Brush[$Level]
    if (-not $tb.Foreground) { $tb.Foreground = $script:Gui.Brush.Info }
    $list = $script:Gui.Ui.LogList
    [void]$list.Items.Add($tb)
    while ($list.Items.Count -gt 1000) { $list.Items.RemoveAt(0) }
    $list.ScrollIntoView($tb)
}

function Update-DebloatGuiCount {
    $n = @($script:Gui.Rows.Values | Where-Object { $_.Check.IsChecked }).Count
    $script:Gui.Ui.SelectedText.Text = "$n selected"
    if ($script:Gui.Category -eq 'Selected') { Update-DebloatGuiFilter }
}

function Update-DebloatGuiFilter {
    $cat = $script:Gui.Category
    $q = $script:Gui.Ui.SearchBox.Text
    if ($q) { $q = $q.Trim().ToLower() }
    foreach ($r in $script:Gui.Rows.Values) {
        $show = $true
        if ($cat -eq 'Selected') { $show = [bool]$r.Check.IsChecked }
        elseif ($cat -ne 'All' -and $r.Tweak.Category -ne $cat) { $show = $false }
        if ($show -and $q -and -not $r.Search.Contains($q)) { $show = $false }
        if ($show) { $r.Row.Visibility = 'Visible' } else { $r.Row.Visibility = 'Collapsed' }
    }
    if ($cat -eq 'Windows Update') { $script:Gui.Ui.AdvancedBanner.Visibility = 'Visible' }
    else { $script:Gui.Ui.AdvancedBanner.Visibility = 'Collapsed' }
}

function Select-DebloatGuiPreset {
    param([string]$Preset)
    $ids = @(Get-DebloatPresetIds -Preset $Preset)
    $count = 0
    foreach ($r in $script:Gui.Rows.Values) {
        $want = $ids -contains $r.Tweak.Id
        $st = $script:Gui.Status[$r.Tweak.Id]
        # Skip what is already done, so the selection shows what will actually change.
        if ($want -and $st -and ($st.State -eq 'Applied' -or $st.State -eq 'NotApplicable')) { $want = $false }
        $r.Check.IsChecked = $want
        if ($want) { $count++ }
    }
    Add-DebloatGuiLog -Level 'Info' -Text "Preset ${Preset}: selected $count item(s) that are not applied yet."
    Update-DebloatGuiCount
}

function Set-DebloatGuiStatus {
    param($Status)
    $script:Gui.Status[$Status.Id] = $Status
    $r = $script:Gui.Rows[$Status.Id]
    if (-not $r) { return }
    $r.Status.Text = $Status.Text
    $r.Status.Foreground = $script:Gui.Brush[$Status.State]
    if ($Status.Detail) { $r.Status.ToolTip = $Status.Detail } else { $r.Status.ToolTip = $null }
    $r.Check.IsEnabled = ($Status.State -ne 'NotApplicable')
    if ($Status.State -eq 'NotApplicable') { $r.Check.IsChecked = $false; $r.Row.Opacity = 0.5 } else { $r.Row.Opacity = 1 }
}

function Set-DebloatGuiBusy {
    param([bool]$Busy)
    $script:Gui.Busy = $Busy
    $ui = $script:Gui.Ui
    $admin = Test-DebloatAdmin
    foreach ($b in 'PresetMinimal', 'PresetRecommended', 'PresetEverything', 'ClearSelection', 'RefreshButton', 'LoadButton') {
        $ui[$b].IsEnabled = -not $Busy
    }
    $ui.ApplyButton.IsEnabled = (-not $Busy) -and $admin
    $ui.UndoButton.IsEnabled = (-not $Busy) -and $admin
    if (-not $Busy) { $ui.ProgressText.Text = '' }
}

function Receive-DebloatGuiEvents {
    $evt = $null
    $n = 0
    while ($n -lt 300 -and $script:Gui.Queue.TryDequeue([ref]$evt)) {
        $n++
        switch ($evt.Type) {
            'log'      { Add-DebloatGuiLog -Level $evt.Level -Text $evt.Text }
            'status'   { Set-DebloatGuiStatus $evt.Status }
            'progress' {
                $p = $script:Gui.Ui.Progress
                $p.Maximum = [Math]::Max(1, $evt.Total)
                $p.Value = $evt.Done
                $script:Gui.Ui.ProgressText.Text = $evt.Text
            }
            'done' {
                if ($script:Gui.Job) {
                    try { $script:Gui.Job.PowerShell.EndInvoke($script:Gui.Job.Handle) | Out-Null } catch { }
                    $script:Gui.Job.PowerShell.Runspace.Close()
                    $script:Gui.Job.PowerShell.Dispose()
                    $script:Gui.Job = $null
                }
                Set-DebloatGuiBusy $false
                $script:Gui.Ui.Progress.Value = 0
                if ($evt.Mode -ne 'Status') {
                    foreach ($r in $script:Gui.Rows.Values) { $r.Check.IsChecked = $false }
                    Update-DebloatGuiCount
                }
            }
        }
    }
}

function Start-DebloatGuiJob {
    param([string]$Mode, [string[]]$Ids = @(), [bool]$RestorePoint = $true, [bool]$RestartExplorer = $true)
    if ($script:Gui.Busy) { return }
    Set-DebloatGuiBusy $true
    if ($Mode -eq 'Status') { $script:Gui.Ui.ProgressText.Text = 'Checking current state...' }

    $worker = {
        param($Sources, $Queue, $Mode, $Ids, $RestorePoint, $RestartExplorer)
        try {
            foreach ($s in $Sources) { . ([scriptblock]::Create($s)) }
            Set-DebloatLogSink $Queue
            if ($Mode -eq 'Status') {
                Update-DebloatAppCache
                foreach ($t in Get-DebloatTweaks) {
                    $Queue.Enqueue([pscustomobject]@{ Type = 'status'; Status = (Get-DebloatTweakStatus $t) })
                }
            } else {
                Invoke-DebloatBatch -Ids $Ids -Action $Mode -CreateRestorePoint $RestorePoint -RestartExplorer $RestartExplorer | Out-Null
            }
        } catch {
            $Queue.Enqueue([pscustomobject]@{ Type = 'log'; Level = 'Error'; Text = "Unexpected error: $($_.Exception.Message)" })
        } finally {
            $Queue.Enqueue([pscustomobject]@{ Type = 'done'; Mode = $Mode })
        }
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($worker).AddArgument($script:Gui.Sources).AddArgument($script:Gui.Queue).AddArgument($Mode).AddArgument($Ids).AddArgument($RestorePoint).AddArgument($RestartExplorer)
    $script:Gui.Job = @{ PowerShell = $ps; Handle = $ps.BeginInvoke() }
}

function Invoke-DebloatGuiAction {
    param([ValidateSet('Apply', 'Undo')][string]$Action)
    $picked = @($script:Gui.Rows.Values | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Tweak })
    if ($picked.Count -eq 0) {
        [void][System.Windows.MessageBox]::Show('Tick the items you want first, or pick a preset.', 'Vanjix Debloat', 'OK', 'Information')
        return
    }

    if ($Action -eq 'Undo') {
        # Only undo what is actually changed, so values you set yourself are left alone.
        $skip = @($picked | Where-Object { $st = $script:Gui.Status[$_.Id]; $st -and $st.State -eq 'NotApplied' })
        $picked = @($picked | Where-Object { $skip -notcontains $_ })
        if ($skip.Count) { Add-DebloatGuiLog -Level 'Info' -Text "Skipping $($skip.Count) item(s) that are not applied." }
        if ($picked.Count -eq 0) { return }
        $lines = @("Undo $($picked.Count) item(s)?", '', 'Each one goes back to how it was before Vanjix Debloat changed it.')
        $reinstall = @($picked | Where-Object { $_.ContainsKey('App') })
        if ($reinstall.Count) { $lines += '', "$($reinstall.Count) app(s) will be reinstalled from the Microsoft Store where possible." }
        $answer = [System.Windows.MessageBox]::Show(($lines -join "`n"), 'Vanjix Debloat - Undo', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        Start-DebloatGuiJob -Mode 'Undo' -Ids @($picked | ForEach-Object { $_.Id }) -RestorePoint $false -RestartExplorer ([bool]$script:Gui.Ui.ExplorerCheck.IsChecked)
        return
    }

    $lines = @("Apply $($picked.Count) change(s)?", '')
    $advanced = @($picked | Where-Object { $_.Risk -eq 'Advanced' })
    if ($advanced.Count) {
        $lines += 'ADVANCED - Windows Update:'
        foreach ($t in $advanced) { $lines += "  - $($t.Name)" }
        $lines += ''
    }
    $warned = @($picked | Where-Object { $_.Warning })
    if ($warned.Count) {
        $lines += 'Please read:'
        foreach ($t in $warned) { $lines += "  - $($t.Name): $($t.Warning)" }
        $lines += ''
    }
    $permanent = @($picked | Where-Object { $_.ContainsKey('App') -and $_.App.Permanent })
    if ($permanent.Count) {
        $lines += 'These apps cannot be reinstalled afterwards (Microsoft no longer offers them):'
        $lines += '  ' + (($permanent | ForEach-Object { $_.Name -replace '^Remove ', '' }) -join ', ')
        $lines += ''
    }
    if ($script:Gui.Ui.RestorePointCheck.IsChecked) { $lines += 'A restore point is created first.' }
    else { $lines += 'No restore point will be created.' }
    $lines += 'Everything else can be undone with "Undo selected".'

    $icon = 'Question'; if ($advanced.Count -or $warned.Count) { $icon = 'Warning' }
    $answer = [System.Windows.MessageBox]::Show(($lines -join "`n"), 'Vanjix Debloat - Apply', 'YesNo', $icon)
    if ($answer -ne 'Yes') { return }

    Start-DebloatGuiJob -Mode 'Apply' -Ids @($picked | ForEach-Object { $_.Id }) `
        -RestorePoint ([bool]$script:Gui.Ui.RestorePointCheck.IsChecked) -RestartExplorer ([bool]$script:Gui.Ui.ExplorerCheck.IsChecked)
}

function Save-DebloatGuiSelection {
    $ids = @($script:Gui.Rows.Values | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Tweak.Id })
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = 'Vanjix Debloat selection (*.json)|*.json'
    $dlg.FileName = 'vanjix-debloat-selection.json'
    if ($dlg.ShowDialog()) {
        $json = ConvertTo-Json -InputObject @{ Version = $script:DebloatVersion; Ids = $ids } -Depth 3
        Set-Content -Path $dlg.FileName -Value $json -Encoding UTF8
        Add-DebloatGuiLog -Level 'Success' -Text "Saved $($ids.Count) item(s) to $($dlg.FileName)"
    }
}

function Import-DebloatGuiSelection {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Vanjix Debloat selection (*.json)|*.json'
    if (-not $dlg.ShowDialog()) { return }
    try {
        $ids = @(Read-DebloatSelectionFile $dlg.FileName)
        $unknown = 0
        foreach ($r in $script:Gui.Rows.Values) { $r.Check.IsChecked = ($ids -contains $r.Tweak.Id) -and $r.Check.IsEnabled }
        foreach ($id in $ids) { if (-not $script:Gui.Rows.Contains($id)) { $unknown++ } }
        Add-DebloatGuiLog -Level 'Success' -Text "Loaded $($ids.Count - $unknown) item(s) from $($dlg.FileName)"
        if ($unknown) { Add-DebloatGuiLog -Level 'Warn' -Text "$unknown item(s) in the file are not in this version and were skipped." }
        Update-DebloatGuiCount
    } catch {
        Add-DebloatGuiLog -Level 'Error' -Text "Could not read that file: $($_.Exception.Message)"
    }
}

function Read-DebloatSelectionFile {
    param([Parameter(Mandatory)][string]$Path)
    $data = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $data.Ids) { throw 'The file has no "Ids" list' }
    return @($data.Ids | ForEach-Object { [string]$_ })
}
