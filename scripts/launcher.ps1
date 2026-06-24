#Requires -Version 5.1
<#
.SYNOPSIS
    Public launcher with optional LAN mode for the Windows script distribution project.

.DESCRIPTION
    Intended public entry point:

        irm https://get.tand.us/launcher | iex

    Advanced usage when passing parameters through Invoke-Expression:

        $script = irm https://get.tand.us/launcher
        & ([scriptblock]::Create($script)) -Lan
        & ([scriptblock]::Create($script)) -Lan -LanBaseUrl 'http://SERVER-IP:8085'

    The launcher does not require files from this repo to exist locally.
#>

param(
    [string]$LanBaseUrl,
    [switch]$Lan,
    [switch]$Public,
    [switch]$NoSave,
    [switch]$DebugLan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:PublicBaseUrl = 'https://get.tand.us'
$script:LanManifestMarker = 'TAND-LAN-LAUNCHER-v1'
$script:ConfigPath = Join-Path -Path $env:APPDATA -ChildPath 'TAND\WindowsUtil\config.json'
$script:DefaultLanBaseUrls = @(
    'http://scripts.home.arpa:8085',
    'http://windows-util-scripts.home.arpa:8085',
    'http://windows-util-scripts.local:8085'
)
$script:LanDebug = New-Object System.Collections.Generic.List[object]
$script:LanState = [pscustomobject]@{
    Status    = 'Manual URL needed'
    BaseUrl   = $null
    Source    = $null
    Manifest  = $null
    LastError = $null
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ''
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Write-WarningMessage {
    param([Parameter(Mandatory)][string]$Message)
    Write-Warning $Message
}

function Normalize-LanBaseUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }

    return $Url.Trim().TrimEnd('/')
}

function Get-ConfigLanBaseUrl {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        return $null
    }

    try {
        $config = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains 'LanBaseUrl') {
            return Normalize-LanBaseUrl -Url ([string]$config.LanBaseUrl)
        }
    } catch {
        $script:LanDebug.Add([pscustomobject]@{
            Source = 'config'
            Url    = $script:ConfigPath
            Result = "invalid config: $($_.Exception.Message)"
        })
    }

    return $null
}

function Save-LanBaseUrl {
    param([Parameter(Mandatory)][string]$Url)

    $configDir = Split-Path -Parent $script:ConfigPath
    if (-not (Test-Path -LiteralPath $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    [pscustomobject]@{ LanBaseUrl = $Url } |
        ConvertTo-Json -Depth 3 |
        Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
}

function Get-LanManifest {
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$Source
    )

    $normalized = Normalize-LanBaseUrl -Url $BaseUrl
    if (-not $normalized) {
        return $null
    }

    $manifestUrl = "$normalized/lan-manifest.json"
    try {
        $manifest = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing -TimeoutSec 2
        $properties = @($manifest.PSObject.Properties.Name)
        $hasMarker = $properties -contains 'marker'
        $hasTools = $properties -contains 'tools'
        $valid = ($hasMarker -and $manifest.marker -eq $script:LanManifestMarker) -or $hasTools

        if ($valid) {
            $script:LanDebug.Add([pscustomobject]@{
                Source = $Source
                Url    = $manifestUrl
                Result = 'ok'
            })
            return [pscustomobject]@{
                BaseUrl  = $normalized
                Source   = $Source
                Manifest = $manifest
            }
        }

        $script:LanDebug.Add([pscustomobject]@{
            Source = $Source
            Url    = $manifestUrl
            Result = 'invalid manifest'
        })
    } catch {
        $script:LanDebug.Add([pscustomobject]@{
            Source = $Source
            Url    = $manifestUrl
            Result = $_.Exception.Message
        })
    }

    return $null
}

function Resolve-LanBaseUrl {
    param([string]$PreferredLanBaseUrl)

    $candidates = New-Object System.Collections.Generic.List[object]

    $preferred = Normalize-LanBaseUrl -Url $PreferredLanBaseUrl
    if ($preferred) {
        $candidates.Add([pscustomobject]@{ Source = 'parameter'; Url = $preferred })
    }

    $envUrl = Normalize-LanBaseUrl -Url $env:TAND_LAN_BASE_URL
    if ($envUrl) {
        $candidates.Add([pscustomobject]@{ Source = 'environment'; Url = $envUrl })
    }

    $configUrl = Get-ConfigLanBaseUrl
    if ($configUrl) {
        $candidates.Add([pscustomobject]@{ Source = 'saved config'; Url = $configUrl })
    }

    foreach ($url in $script:DefaultLanBaseUrls) {
        $candidates.Add([pscustomobject]@{ Source = 'default'; Url = $url })
    }

    foreach ($candidate in $candidates) {
        $result = Get-LanManifest -BaseUrl $candidate.Url -Source $candidate.Source
        if ($result) {
            return $result
        }
    }

    return $null
}

function Test-LanMode {
    param([string]$PreferredLanBaseUrl)

    $script:LanDebug.Clear()
    $configUrl = Get-ConfigLanBaseUrl
    $resolved = Resolve-LanBaseUrl -PreferredLanBaseUrl $PreferredLanBaseUrl

    if ($resolved) {
        $script:LanState = [pscustomobject]@{
            Status    = "Detected at $($resolved.BaseUrl)"
            BaseUrl   = $resolved.BaseUrl
            Source    = $resolved.Source
            Manifest  = $resolved.Manifest
            LastError = $null
        }
        return $true
    }

    $status = if ($configUrl) { 'Configured but unavailable' } else { 'Manual URL needed' }
    $script:LanState = [pscustomobject]@{
        Status    = $status
        BaseUrl   = $configUrl
        Source    = if ($configUrl) { 'saved config' } else { $null }
        Manifest  = $null
        LastError = $null
    }
    return $false
}

function Invoke-RemoteScript {
    param([Parameter(Mandatory)][string]$Url)

    $scriptText = Invoke-RestMethod -Uri $Url -UseBasicParsing
    Invoke-Expression $scriptText
}

function Invoke-PublicInstall {
    Invoke-RemoteScript -Url "$script:PublicBaseUrl/install"
}

function Invoke-PublicDev {
    Invoke-RemoteScript -Url "$script:PublicBaseUrl/dev"
}

function Invoke-PublicUninstall {
    Invoke-RemoteScript -Url "$script:PublicBaseUrl/uninstall"
}

function Invoke-LanScript {
    param([Parameter(Mandatory)][string]$Path)

    if (-not $script:LanState.Manifest -or -not $script:LanState.BaseUrl) {
        Write-WarningMessage 'LAN mode is not available.'
        return
    }

    Invoke-RemoteScript -Url "$($script:LanState.BaseUrl)$Path"
}

function Invoke-LanTool {
    param([Parameter(Mandatory)][string]$ToolId)

    if (-not $script:LanState.Manifest) {
        Write-WarningMessage 'LAN mode is not available.'
        return
    }

    $tools = @()
    if ($script:LanState.Manifest.PSObject.Properties.Name -contains 'tools') {
        $tools = @($script:LanState.Manifest.tools)
    }

    $tool = $tools | Where-Object { $_.id -eq $ToolId } | Select-Object -First 1
    if (-not $tool) {
        Write-WarningMessage "LAN tool not found: $ToolId"
        return
    }

    if (($tool.PSObject.Properties.Name -contains 'scriptUrl') -and $tool.scriptUrl) {
        Invoke-RemoteScript -Url $tool.scriptUrl
    } else {
        Write-WarningMessage "LAN tool '$ToolId' has no scriptUrl."
    }
}

function Show-LanDebug {
    Write-Section 'LAN Diagnostics / Debug'
    Write-Host "Selected LAN base URL: $($script:LanState.BaseUrl)"
    Write-Host "LAN status: $($script:LanState.Status)"
    Write-Host "LAN source: $($script:LanState.Source)"
    Write-Host ''
    Write-Host 'Candidate tests:'
    if ($script:LanDebug.Count -eq 0) {
        Write-Host ' - none'
    } else {
        foreach ($entry in $script:LanDebug) {
            Write-Host " - [$($entry.Source)] $($entry.Url) -> $($entry.Result)"
        }
    }
}

function Prompt-ManualLanBaseUrl {
    Write-Section 'LAN Mode'
    Write-Host 'LAN mode was not auto-detected.'
    Write-Host 'You can enter the LAN base URL manually.'
    Write-Host 'Example: http://SERVER-IP:8085'
    Write-Host ''

    $manualUrl = Normalize-LanBaseUrl -Url (Read-Host 'Enter LAN base URL or leave blank to cancel')
    if (-not $manualUrl) {
        return $false
    }

    $result = Get-LanManifest -BaseUrl $manualUrl -Source 'manual'
    if (-not $result) {
        Write-WarningMessage "Could not validate $manualUrl/lan-manifest.json."
        return $false
    }

    $script:LanState = [pscustomobject]@{
        Status    = "Detected at $($result.BaseUrl)"
        BaseUrl   = $result.BaseUrl
        Source    = 'manual'
        Manifest  = $result.Manifest
        LastError = $null
    }

    if (-not $NoSave) {
        $answer = Read-Host 'Save this LAN URL for future launches? [y/N]'
        if ($answer -match '^(y|yes)$') {
            Save-LanBaseUrl -Url $result.BaseUrl
            Write-Host "Saved LAN URL to $script:ConfigPath" -ForegroundColor Green
        }
    }

    return $true
}

function Ensure-LanMode {
    if ($script:LanState.Manifest) {
        return $true
    }

    [void](Test-LanMode -PreferredLanBaseUrl $LanBaseUrl)
    if ($script:LanState.Manifest) {
        return $true
    }

    return (Prompt-ManualLanBaseUrl)
}

function Show-LanMenu {
    if (-not (Ensure-LanMode)) {
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    do {
        Clear-Host
        Write-Host 'Windows Script Distribution Launcher - LAN Mode' -ForegroundColor Cyan
        Write-Host "LAN: Detected at $($script:LanState.BaseUrl)" -ForegroundColor Green
        Write-Host ''
        Write-Host '1. Install'
        Write-Host '2. Dev / Test'
        Write-Host '3. Uninstall'
        Write-Host '4. Run LAN diagnostics'
        Write-Host '5. Open local script index'
        Write-Host 'D. Diagnostics / Debug'
        Write-Host '0. Back to Main Menu'
        Write-Host ''

        $choice = Read-Host 'Select an option'
        if ([string]::IsNullOrWhiteSpace($choice) -and [Console]::IsInputRedirected) {
            return
        }
        switch ($choice) {
            '1' { Invoke-LanScript -Path '/install.ps1'; Read-Host 'Press Enter to continue' | Out-Null }
            '2' { Invoke-LanScript -Path '/dev.ps1'; Read-Host 'Press Enter to continue' | Out-Null }
            '3' { Invoke-LanScript -Path '/uninstall.ps1'; Read-Host 'Press Enter to continue' | Out-Null }
            '4' { Invoke-LanTool -ToolId 'lan-diagnostics'; Read-Host 'Press Enter to continue' | Out-Null }
            '5' {
                $indexUrl = "$($script:LanState.BaseUrl)/"
                try { Start-Process $indexUrl } catch { Write-Host "Open this URL in a browser: $indexUrl" }
                Read-Host 'Press Enter to continue' | Out-Null
            }
            { $_ -match '^(d|D)$' } { Show-LanDebug; Read-Host 'Press Enter to continue' | Out-Null }
            '0' { return }
            default { Write-WarningMessage 'Unknown option.'; Read-Host 'Press Enter to continue' | Out-Null }
        }
    } while ($true)
}

function Show-MainMenu {
    do {
        Clear-Host
        Write-Host 'Windows Script Distribution Launcher' -ForegroundColor Cyan
        Write-Host "LAN: $($script:LanState.Status)"
        Write-Host ''
        Write-Host '1. Public Install'
        Write-Host '2. Public Dev / Test'
        Write-Host '3. Public Uninstall'
        Write-Host '9. LAN Mode'
        Write-Host 'D. Diagnostics / Debug'
        Write-Host '0. Exit'
        Write-Host ''

        $choice = Read-Host 'Select an option'
        if ([string]::IsNullOrWhiteSpace($choice) -and [Console]::IsInputRedirected) {
            return
        }
        switch ($choice) {
            '1' { Invoke-PublicInstall; Read-Host 'Press Enter to continue' | Out-Null }
            '2' { Invoke-PublicDev; Read-Host 'Press Enter to continue' | Out-Null }
            '3' { Invoke-PublicUninstall; Read-Host 'Press Enter to continue' | Out-Null }
            '9' { Show-LanMenu }
            { $_ -match '^(d|D)$' } { Show-LanDebug; Read-Host 'Press Enter to continue' | Out-Null }
            '0' { return }
            default { Write-WarningMessage 'Unknown option.'; Read-Host 'Press Enter to continue' | Out-Null }
        }
    } while ($true)
}

[void](Test-LanMode -PreferredLanBaseUrl $LanBaseUrl)

if ($DebugLan) {
    Show-LanDebug
}

if ($Lan -and -not $Public) {
    Show-LanMenu
} else {
    Show-MainMenu
}
