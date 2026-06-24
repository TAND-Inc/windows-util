#Requires -Version 5.1
<#
.SYNOPSIS
    Shared WPF menu engine for Windows script distribution.

.DESCRIPTION
    This file is safe to execute from downloaded script text. It does not rely on
    PSScriptRoot and can run in WAN or LAN mode by loading a manifest URL.
#>

param(
    [ValidateSet("WAN", "LAN")]
    [string]$Mode = "WAN",

    [string]$ManifestUrl,
    [string]$BaseUrl,
    [string]$LanBaseUrl,
    [string]$WanBaseUrl = "https://get.tand.us",
    [switch]$OfflinePreferred
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
try { Add-Type -AssemblyName Microsoft.VisualBasic } catch { }

$script:Mode = $Mode
$script:WanBaseUrl = $WanBaseUrl.TrimEnd("/")
$script:LanBaseUrl = if ($LanBaseUrl) { $LanBaseUrl.TrimEnd("/") } else { $null }
$script:BaseUrl = if ($BaseUrl) { $BaseUrl.TrimEnd("/") } elseif ($Mode -eq "LAN" -and $LanBaseUrl) { $LanBaseUrl.TrimEnd("/") } else { $script:WanBaseUrl }
$script:ManifestUrl = $ManifestUrl
$script:WingetAvailable = $false
$script:WingetTried = $false
$script:Applied = @()
$script:ConfigPath = Join-Path -Path $env:APPDATA -ChildPath "TAND\WindowsUtil\config.json"
$script:LanCandidates = @(
    "https://get.home.us",
    "http://get.home.us:8085",
    "http://scripts.home.arpa:8085",
    "http://windows-util-scripts.home.arpa:8085"
)

function New-Brush {
    param([string]$Hex)
    [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($Hex))
}

function Show-Info {
    param([string]$Message, [string]$Title = "Windows Setup Toolkit")
    [System.Windows.MessageBox]::Show($Message, $Title, "OK", "Information") | Out-Null
}

function Show-Warn {
    param([string]$Message, [string]$Title = "Windows Setup Toolkit")
    [System.Windows.MessageBox]::Show($Message, $Title, "OK", "Warning") | Out-Null
}

function Normalize-BaseUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    return $Url.Trim().TrimEnd("/")
}

function Get-ConfigLanBaseUrl {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) { return $null }
    try {
        $config = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains "LanBaseUrl") {
            return Normalize-BaseUrl -Url ([string]$config.LanBaseUrl)
        }
    } catch { }
    return $null
}

function Save-LanBaseUrl {
    param([Parameter(Mandatory)][string]$Url)
    $dir = Split-Path -Parent $script:ConfigPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [pscustomobject]@{ LanBaseUrl = $Url } |
        ConvertTo-Json -Depth 3 |
        Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
}

function Get-ManifestUrl {
    param([string]$Mode, [string]$BaseUrl, [string]$ManifestUrl)
    if ($ManifestUrl) { return $ManifestUrl }
    if ($Mode -eq "LAN") { return "$BaseUrl/lan-manifest.json" }
    return "$BaseUrl/config/wan-apps.json"
}

function Get-Manifest {
    param([Parameter(Mandatory)][string]$Url)
    try {
        $manifest = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 15
        if (-not ($manifest.PSObject.Properties.Name -contains "items") -or -not $manifest.items) {
            throw "Manifest at $Url did not contain an items array."
        }
        return $manifest
    } catch {
        throw "Failed to load manifest from $Url`n$_"
    }
}

function Test-ManifestEndpoint {
    param([Parameter(Mandatory)][string]$BaseUrl)
    $normalized = Normalize-BaseUrl -Url $BaseUrl
    if (-not $normalized) { return $null }

    $url = "$normalized/lan-manifest.json"
    try {
        $manifest = Invoke-RestMethod -Uri $url -UseBasicParsing -TimeoutSec 2
        if (($manifest.PSObject.Properties.Name -contains "items") -and $manifest.items) {
            return [pscustomobject]@{ BaseUrl = $normalized; ManifestUrl = $url; Manifest = $manifest }
        }
    } catch { }
    return $null
}

function Resolve-LanBaseUrl {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @($script:LanBaseUrl, $env:TAND_LAN_BASE_URL, (Get-ConfigLanBaseUrl))) {
        $normalized = Normalize-BaseUrl -Url $candidate
        if ($normalized -and -not $candidates.Contains($normalized)) { $candidates.Add($normalized) }
    }
    foreach ($candidate in $script:LanCandidates) {
        if (-not $candidates.Contains($candidate)) { $candidates.Add($candidate) }
    }

    foreach ($candidate in $candidates) {
        $result = Test-ManifestEndpoint -BaseUrl $candidate
        if ($result) { return $result }
    }
    return $null
}

function Prompt-LanBaseUrl {
    $prompt = "LAN was not auto-detected.`nEnter LAN base URL, for example http://SERVER-IP:8085"
    if ("Microsoft.VisualBasic.Interaction" -as [type]) {
        $entered = [Microsoft.VisualBasic.Interaction]::InputBox($prompt, "Switch to LAN", "")
    } else {
        $entered = Read-Host "Enter LAN base URL or leave blank to cancel"
    }
    $entered = Normalize-BaseUrl -Url $entered
    if (-not $entered) { return $null }

    $result = Test-ManifestEndpoint -BaseUrl $entered
    if (-not $result) {
        Show-Warn "Could not validate $entered/lan-manifest.json."
        return $null
    }

    $save = [System.Windows.MessageBox]::Show("Save this LAN URL for future launches?", "Switch to LAN", "YesNo", "Question")
    if ($save -eq "Yes") { Save-LanBaseUrl -Url $result.BaseUrl }
    return $result
}

function Resolve-ItemScriptUrl {
    param($Spec, [string]$BaseUrl)
    $payload = [string]$Spec.payload
    if ($payload -match "^https?://") { return $payload }
    if ($payload -match "^[A-Za-z]:\\") { return $payload }
    $payload = $payload.TrimStart("/")
    if ($payload -match "^(scripts|installers)/") { return "$BaseUrl/$payload" }
    return "$BaseUrl/scripts/$payload"
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-InstalledPrograms {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($path in $paths) {
        try {
            Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.DisplayName) {
                    $list.Add([pscustomobject]@{ Name = [string]$_.DisplayName; Version = [string]$_.DisplayVersion })
                }
            }
        } catch { }
    }
    return $list
}

function Test-ItemApplied {
    param($Check)
    foreach ($c in @($Check)) {
        switch ($c.type) {
            "registry" {
                try { $val = (Get-ItemProperty -Path $c.path -Name $c.name -ErrorAction Stop).$($c.name) }
                catch { return $false }
                if ([string]$val -ne [string]$c.value) { return $false }
            }
            "powerplan" {
                $active = (powercfg /getactivescheme 2>$null | Out-String)
                if ($active -notmatch [regex]::Escape($c.guid)) { return $false }
            }
            default { return $false }
        }
    }
    return $true
}

function Get-ItemStatus {
    param($Item, $Installed, $AppliedIds)
    if (($Item.PSObject.Properties.Name -contains "check") -and $Item.check) {
        if (Test-ItemApplied -Check $Item.check) {
            return [pscustomobject]@{ State = "applied"; Label = "Applied" }
        }
    }
    if ($AppliedIds -contains $Item.id) {
        return [pscustomobject]@{ State = "applied"; Label = "Applied this run" }
    }
    if (@("winget", "choco", "download") -contains $Item.method) {
        $needle = if (($Item.PSObject.Properties.Name -contains "detect") -and $Item.detect) { $Item.detect } else { $Item.name }
        $hit = $Installed | Where-Object { $_.Name -like "*$needle*" } | Select-Object -First 1
        if ($hit) {
            $ver = if ($hit.Version) { $hit.Version } else { "unknown" }
            return [pscustomobject]@{ State = "installed"; Label = "Installed - Version: $ver" }
        }
    }
    return $null
}

function Get-WingetStatus {
    $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            $ver = (winget --version) 2>$null
            if ($ver) { return "winget is installed ($ver)." }
        } catch { }
        return "winget is installed."
    }
    return "winget is NOT installed. Click Install winget, or it will be bootstrapped when a winget item runs."
}

function Install-Winget {
    $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    Write-Host "winget not found; attempting to bootstrap it..." -ForegroundColor Yellow
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
        if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    } catch { }

    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers -ErrorAction Stop | Out-Null
        Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
        Repair-WinGetPackageManager -Force -Latest -ErrorAction Stop
    } catch {
        Write-Warning "winget bootstrap failed: $_"
    }

    $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

function Invoke-Install {
    param($Spec, [string]$BaseUrl)
    switch ($Spec.method) {
        "winget" {
            if (-not $script:WingetAvailable) { throw "winget is not available on this system." }
            winget install --id $Spec.payload --exact --silent --accept-package-agreements --accept-source-agreements --source winget
            if (@(0, -1978335189, -1978335212) -notcontains $LASTEXITCODE) { throw "winget exited with code $LASTEXITCODE." }
        }
        "choco" {
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                Set-ExecutionPolicy Bypass -Scope Process -Force
                Invoke-Expression ((New-Object Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))
            }
            choco install $Spec.payload -y
            if ($LASTEXITCODE -ne 0) { throw "choco exited with code $LASTEXITCODE." }
        }
        "script" {
            $url = Resolve-ItemScriptUrl -Spec $Spec -BaseUrl $BaseUrl
            $fileName = if ($Spec.payload) { [IO.Path]::GetFileName(([string]$Spec.payload -split "\?")[0]) } else { "script.ps1" }
            if (-not $fileName) { $fileName = "script.ps1" }
            $tmp = Join-Path $env:TEMP $fileName
            Invoke-RestMethod -Uri $url -OutFile $tmp -UseBasicParsing
            & $tmp
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
        "download" {
            $url = $Spec.url
            if (-not $url) { throw "download item has no url." }
            $file = if ($Spec.file) { $Spec.file } else { [IO.Path]::GetFileName(($url -split "\?")[0]) }
            if (-not $file) { $file = "installer.tmp" }
            $tmp = Join-Path $env:TEMP $file
            Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
            $arguments = [string]$Spec.args
            try {
                if ($file -match "\.msi$") {
                    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList ("/i `"$tmp`" $arguments").Trim() -Wait -PassThru
                } else {
                    $sp = @{ FilePath = $tmp; Wait = $true; PassThru = $true }
                    if ($arguments) { $sp.ArgumentList = $arguments }
                    $p = Start-Process @sp
                }
                if (@(0, 3010) -notcontains $p.ExitCode) { throw "installer exited with code $($p.ExitCode)." }
            } finally {
                Remove-Item $tmp -ErrorAction SilentlyContinue
            }
        }
        "irm" {
            $url = $Spec.payload
            if (-not $url) { throw "irm item has no payload URL." }
            $ans = Read-Host "Run external script from $url ? [y/N]"
            if ($ans -match "^(y|yes)$") {
                Invoke-Expression (Invoke-RestMethod -Uri $url -UseBasicParsing)
            }
        }
        default { throw "Unknown method '$($Spec.method)'." }
    }
}

function Invoke-ToolkitItem {
    param($Item, [string]$BaseUrl)
    Write-Host "==> $($Item.name)" -ForegroundColor Cyan
    try {
        Invoke-Install -Spec $Item -BaseUrl $BaseUrl
        Write-Host "    done." -ForegroundColor Green
        $script:Applied += $Item.id
    } catch {
        $primaryErr = $_
        $hasFallback = ($Item.PSObject.Properties.Name -contains "fallback") -and $Item.fallback
        if ($hasFallback) {
            Write-Warning "    primary ($($Item.method)) failed: $primaryErr"
            try {
                Invoke-Install -Spec $Item.fallback -BaseUrl $BaseUrl
                Write-Host "    done (via fallback)." -ForegroundColor Green
                $script:Applied += $Item.id
            } catch {
                Write-Warning "    FALLBACK FAILED: $_"
            }
        } else {
            Write-Warning "    FAILED: $primaryErr"
        }
    }
}

function Show-ToolkitMenu {
    param($Manifest, $AppliedIds, [string]$Mode, [string]$BaseUrl)
    $installed = Get-InstalledPrograms
    $switchLabel = if ($Mode -eq "WAN") { "Switch to LAN" } else { "Switch to WAN" }
    $modeTitle = "Windows Setup Toolkit - $Mode Mode"
    $modeLine = "$Mode mode source: $BaseUrl"

    $Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$modeTitle" Height="740" Width="640"
        WindowStartupLocation="CenterScreen" Background="#1E1E2E"
        FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,10">
      <TextBlock Text="$modeTitle" FontSize="22" FontWeight="Bold" Foreground="#CDD6F4"/>
      <TextBlock Text="$modeLine" FontSize="12" Foreground="#A6ADC8" Margin="0,2,0,0" TextWrapping="Wrap"/>
    </StackPanel>

    <Border Grid.Row="1" BorderBrush="#45475A" BorderThickness="1" CornerRadius="6"
            Background="#181825" Padding="10" Margin="0,0,0,10">
      <DockPanel LastChildFill="True">
        <Button x:Name="WingetInstallBtn" Content="Install winget" Width="120" Height="30"
                DockPanel.Dock="Right" Background="#F38BA8" Foreground="#1E1E2E"
                FontWeight="Bold" BorderThickness="0" Visibility="Collapsed"/>
        <TextBlock x:Name="WingetStatus" Text="Checking winget..." VerticalAlignment="Center"
                   Margin="0,0,12,0" Foreground="#A6ADC8" TextWrapping="Wrap"/>
      </DockPanel>
    </Border>

    <Border Grid.Row="2" BorderBrush="#45475A" BorderThickness="1" CornerRadius="6" Background="#181825">
      <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="10">
        <StackPanel x:Name="ItemsPanel"/>
      </ScrollViewer>
    </Border>

    <DockPanel Grid.Row="3" Margin="0,12,0,0" LastChildFill="False">
      <Button x:Name="SelectAllBtn"   Content="Select All"  Width="90"  Height="32" DockPanel.Dock="Left"/>
      <Button x:Name="SelectNoneBtn"  Content="Clear"       Width="70"  Height="32" Margin="8,0,0,0" DockPanel.Dock="Left"/>
      <Button x:Name="RecommendedBtn" Content="Recommended" Width="110" Height="32" Margin="8,0,0,0" DockPanel.Dock="Left"/>
      <Button x:Name="SwitchModeBtn"  Content="$switchLabel" Width="110" Height="32" Margin="8,0,0,0" DockPanel.Dock="Left"/>
      <Button x:Name="RunBtn"   Content="Run Selected" Width="130" Height="32" DockPanel.Dock="Right"
              Background="#89B4FA" Foreground="#1E1E2E" FontWeight="Bold" BorderThickness="0"/>
      <Button x:Name="CloseBtn" Content="Close" Width="80" Height="32" Margin="0,0,8,0" DockPanel.Dock="Right"/>
    </DockPanel>
  </Grid>
</Window>
"@

    $reader = [System.Xml.XmlNodeReader]::new([xml]$Xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $panel = $window.FindName("ItemsPanel")
    $checkboxes = New-Object System.Collections.Generic.List[object]

    foreach ($group in ($Manifest.items | Group-Object category)) {
        $header = New-Object Windows.Controls.TextBlock
        $header.Text = $group.Name
        $header.FontWeight = "Bold"
        $header.FontSize = 14
        $header.Foreground = New-Brush "#F9E2AF"
        $header.Margin = "0,10,0,4"
        $panel.AddChild($header)

        foreach ($item in $group.Group) {
            $status = Get-ItemStatus -Item $item -Installed $installed -AppliedIds $AppliedIds
            $cb = New-Object Windows.Controls.CheckBox
            if ($status) {
                $cb.Content = "$($item.name)  ($($status.Label))"
                $cb.Foreground = if ($status.State -eq "installed") { New-Brush "#A6E3A1" } else { New-Brush "#94E2D5" }
            } else {
                $cb.Content = $item.name
                $cb.Foreground = New-Brush "#CDD6F4"
            }
            $cb.ToolTip = $item.description
            $cb.IsChecked = $false
            $cb.Margin = "6,3,0,3"
            $cb.Tag = $item
            $panel.AddChild($cb)
            $checkboxes.Add($cb)
        }
    }

    $statusBlock = $window.FindName("WingetStatus")
    $wgInstall = $window.FindName("WingetInstallBtn")
    $wgStatus = Get-WingetStatus
    $statusBlock.Text = $wgStatus
    if ($wgStatus -like "*NOT installed*") {
        $statusBlock.Foreground = New-Brush "#F38BA8"
        $wgInstall.Visibility = "Visible"
    } else {
        $statusBlock.Foreground = New-Brush "#A6E3A1"
        $wgInstall.Visibility = "Collapsed"
    }

    $window.FindName("SelectAllBtn").Add_Click({ foreach ($c in $checkboxes) { $c.IsChecked = $true } })
    $window.FindName("SelectNoneBtn").Add_Click({ foreach ($c in $checkboxes) { $c.IsChecked = $false } })
    $window.FindName("RecommendedBtn").Add_Click({ foreach ($c in $checkboxes) { $c.IsChecked = [bool]$c.Tag.default } })

    $script:MenuAction = "close"
    $script:MenuSelected = @()
    $wgInstall.Add_Click({
        $script:MenuAction = "installwinget"
        $window.Close()
    })
    $window.FindName("SwitchModeBtn").Add_Click({
        $script:MenuAction = "switch"
        $window.Close()
    })
    $window.FindName("RunBtn").Add_Click({
        $script:MenuSelected = @($checkboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
        $script:MenuAction = "run"
        $window.Close()
    })
    $window.FindName("CloseBtn").Add_Click({
        $script:MenuAction = "close"
        $window.Close()
    })

    $null = $window.ShowDialog()
    [pscustomobject]@{ Action = $script:MenuAction; Selected = $script:MenuSelected }
}

function Switch-ToWan {
    try {
        $manifestUrl = Get-ManifestUrl -Mode "WAN" -BaseUrl $script:WanBaseUrl -ManifestUrl $null
        $manifest = Get-Manifest -Url $manifestUrl
        $script:Mode = "WAN"
        $script:BaseUrl = $script:WanBaseUrl
        $script:ManifestUrl = $manifestUrl
        return $manifest
    } catch {
        Show-Warn "WAN mode is unavailable.`n$_"
        return $null
    }
}

function Switch-ToLan {
    $resolved = Resolve-LanBaseUrl
    if (-not $resolved) { $resolved = Prompt-LanBaseUrl }
    if (-not $resolved) { return $null }
    $script:Mode = "LAN"
    $script:LanBaseUrl = $resolved.BaseUrl
    $script:BaseUrl = $resolved.BaseUrl
    $script:ManifestUrl = $resolved.ManifestUrl
    return $resolved.Manifest
}

function Start-WindowsUtilMenu {
    if (-not (Test-Admin)) {
        Show-Warn "Not running as Administrator. Most installs and HKLM tweaks may fail."
    }

    $currentManifestUrl = Get-ManifestUrl -Mode $script:Mode -BaseUrl $script:BaseUrl -ManifestUrl $script:ManifestUrl
    $manifest = Get-Manifest -Url $currentManifestUrl
    $script:ManifestUrl = $currentManifestUrl

    do {
        $menu = Show-ToolkitMenu -Manifest $manifest -AppliedIds $script:Applied -Mode $script:Mode -BaseUrl $script:BaseUrl
        switch ($menu.Action) {
            "close" { return }
            "switch" {
                $next = if ($script:Mode -eq "WAN") { Switch-ToLan } else { Switch-ToWan }
                if ($next) { $manifest = $next }
            }
            "installwinget" {
                if (-not $script:WingetAvailable) {
                    $script:WingetTried = $true
                    $script:WingetAvailable = Install-Winget
                }
            }
            "run" {
                if (-not $menu.Selected -or $menu.Selected.Count -eq 0) {
                    Write-Host "Nothing selected." -ForegroundColor Yellow
                    continue
                }
                if ($menu.Selected | Where-Object { $_.method -eq "winget" }) {
                    if (-not $script:WingetAvailable -and -not $script:WingetTried) {
                        $script:WingetTried = $true
                        $script:WingetAvailable = Install-Winget
                    }
                }
                foreach ($item in $menu.Selected) {
                    Invoke-ToolkitItem -Item $item -BaseUrl $script:BaseUrl
                }
                Show-Info "Batch complete. Reopening the menu."
            }
        }
    } while ($true)
}

Start-WindowsUtilMenu
