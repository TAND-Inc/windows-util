#Requires -Version 5.1
<#
.SYNOPSIS
    LAN-aware public launcher for the Windows script distribution project.

.DESCRIPTION
    Intended public entry point:

        irm https://get.tand.us/launcher | iex

    The launcher always shows public script options. It also probes internal LAN
    manifest URLs with short timeouts; when a trusted marker is present, it shows
    LAN-only convenience tools. Access control still belongs to the LAN Caddy
    server and firewall rules, not to this menu.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:PublicBaseUrl = 'https://get.tand.us'
$script:LanManifestMarker = 'TAND-LAN-LAUNCHER-v1'
$script:LanManifestUrls = @(
    'http://scripts.home.arpa:8085/lan-manifest.json',
    'http://get-lan.tand.us:8085/lan-manifest.json'
)
$script:LanState = [pscustomobject]@{
    Available = $false
    Url       = $null
    Manifest  = $null
}

function Import-CommonHelpers {
    $rootVariable = Get-Variable -Name PSScriptRoot -ErrorAction SilentlyContinue
    if ($rootVariable -and -not [string]::IsNullOrWhiteSpace([string]$rootVariable.Value)) {
        $commonPath = Join-Path -Path $rootVariable.Value -ChildPath 'lib\common.ps1'
        if (Test-Path -LiteralPath $commonPath) {
            . $commonPath
        }
    }
}

function Add-CommonFallbacks {
    if (-not (Get-Command Write-Section -ErrorAction SilentlyContinue)) {
        function global:Write-Section {
            param([Parameter(Mandatory)][string]$Message)
            Write-Host ''
            Write-Host "== $Message ==" -ForegroundColor Cyan
        }
    }

    if (-not (Get-Command Write-Success -ErrorAction SilentlyContinue)) {
        function global:Write-Success {
            param([Parameter(Mandatory)][string]$Message)
            Write-Host "[OK] $Message" -ForegroundColor Green
        }
    }

    if (-not (Get-Command Write-WarningMessage -ErrorAction SilentlyContinue)) {
        function global:Write-WarningMessage {
            param([Parameter(Mandatory)][string]$Message)
            Write-Warning $Message
        }
    }
}

function Get-LanManifest {
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    try {
        $manifest = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 2
        $hasMarker = $manifest.PSObject.Properties.Name -contains 'marker'
        if ($hasMarker -and $manifest.marker -eq $script:LanManifestMarker) {
            return [pscustomobject]@{
                Url      = $Url
                Manifest = $manifest
            }
        }
    } catch {
        return $null
    }

    return $null
}

function Test-LanAvailable {
    foreach ($url in $script:LanManifestUrls) {
        $result = Get-LanManifest -Url $url
        if ($result) {
            $script:LanState = [pscustomobject]@{
                Available = $true
                Url       = $result.Url
                Manifest  = $result.Manifest
            }
            return $true
        }
    }

    $script:LanState = [pscustomobject]@{
        Available = $false
        Url       = $null
        Manifest  = $null
    }
    return $false
}

function Invoke-RemoteScript {
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

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

function Write-LanDiagnostics {
    param(
        [Parameter(Mandatory)]
        $LanState
    )

    Write-Section 'LAN Diagnostics'
    Write-Host "Hostname: $env:COMPUTERNAME"
    Write-Host "Current user: $env:USERDOMAIN\$env:USERNAME"
    Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Host "OS version: $([System.Environment]::OSVersion.VersionString)"
    Write-Host "LAN manifest URL: $($LanState.Url)"

    Write-Host ''
    Write-Host 'Available LAN tools:'
    if ($LanState.Manifest.PSObject.Properties.Name -contains 'tools') {
        foreach ($tool in @($LanState.Manifest.tools)) {
            Write-Host " - $($tool.name) [$($tool.id)]"
        }
    } else {
        Write-Host ' - none listed'
    }
}

function Invoke-LanTool {
    param(
        [Parameter(Mandatory)]
        [string]$ToolId
    )

    if (-not $script:LanState.Available) {
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

    switch ($ToolId) {
        'lan-diagnostics' {
            Write-LanDiagnostics -LanState $script:LanState
            if (($tool.PSObject.Properties.Name -contains 'scriptUrl') -and $tool.scriptUrl) {
                Write-Section 'LAN Diagnostics Script'
                Invoke-RemoteScript -Url $tool.scriptUrl
            }
        }
        'local-index' {
            if (($tool.PSObject.Properties.Name -contains 'scriptUrl') -and $tool.scriptUrl) {
                Write-Section 'Local Script Index'
                Write-Host "Opening: $($tool.scriptUrl)"
                try {
                    Start-Process $tool.scriptUrl
                } catch {
                    Write-Host "Open this URL in a browser: $($tool.scriptUrl)"
                }
            }
        }
        default {
            if (($tool.PSObject.Properties.Name -contains 'scriptUrl') -and $tool.scriptUrl) {
                Invoke-RemoteScript -Url $tool.scriptUrl
            } else {
                Write-WarningMessage "LAN tool '$ToolId' has no scriptUrl."
            }
        }
    }
}

function Show-LanMenu {
    do {
        Write-Section 'LAN Tools'
        Write-Host '1. Run LAN diagnostics'
        Write-Host '2. Open local script index'
        Write-Host '0. Back'

        $choice = Read-Host 'Select an option'
        switch ($choice) {
            '1' { Invoke-LanTool -ToolId 'lan-diagnostics' }
            '2' { Invoke-LanTool -ToolId 'local-index' }
            '0' { return }
            default { Write-WarningMessage 'Unknown option.' }
        }
    } while ($true)
}

function Show-MainMenu {
    do {
        Clear-Host
        Write-Host 'Windows Script Distribution Launcher' -ForegroundColor Cyan
        if ($script:LanState.Available) {
            Write-Host 'LAN Mode: Available' -ForegroundColor Green
            Write-Host "LAN Manifest: $($script:LanState.Url)"
        } else {
            Write-Host 'LAN Mode: Not detected' -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host '1. Install'
        Write-Host '2. Dev / Test'
        Write-Host '3. Uninstall'
        if ($script:LanState.Available) {
            Write-Host '9. LAN Tools'
        }
        Write-Host '0. Exit'
        Write-Host ''

        $choice = Read-Host 'Select an option'
        switch ($choice) {
            '1' { Invoke-PublicInstall; Read-Host 'Press Enter to continue' | Out-Null }
            '2' { Invoke-PublicDev; Read-Host 'Press Enter to continue' | Out-Null }
            '3' { Invoke-PublicUninstall; Read-Host 'Press Enter to continue' | Out-Null }
            '9' {
                if ($script:LanState.Available) {
                    Show-LanMenu
                } else {
                    Write-WarningMessage 'LAN Tools are not available.'
                    Read-Host 'Press Enter to continue' | Out-Null
                }
            }
            '0' { return }
            default {
                Write-WarningMessage 'Unknown option.'
                Read-Host 'Press Enter to continue' | Out-Null
            }
        }
    } while ($true)
}

Import-CommonHelpers
Add-CommonFallbacks

[void](Test-LanAvailable)
Show-MainMenu
