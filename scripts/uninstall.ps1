#Requires -Version 5.1
<#
.SYNOPSIS
    Placeholder uninstall entry point for the Windows script distribution project.

.DESCRIPTION
    This script asks for confirmation, prints the actions that a future
    uninstaller might perform, and exits without removing anything.

.EXAMPLE
    .\uninstall.ps1

.EXAMPLE
    irm https://get.tand.us/uninstall | iex
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
        function global:Write-Section { param([string]$Message) Write-Host ""; Write-Host "== $Message ==" -ForegroundColor Cyan }
    }
    if (-not (Get-Command Write-Success -ErrorAction SilentlyContinue)) {
        function global:Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
    }
    if (-not (Get-Command Write-WarningMessage -ErrorAction SilentlyContinue)) {
        function global:Write-WarningMessage { param([string]$Message) Write-Warning $Message }
    }
    if (-not (Get-Command Test-IsAdmin -ErrorAction SilentlyContinue)) {
        function global:Test-IsAdmin {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]::new($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
    }
    if (-not (Get-Command Confirm-Continue -ErrorAction SilentlyContinue)) {
        function global:Confirm-Continue { param([string]$Prompt = "Continue?") $answer = Read-Host "$Prompt [y/N]"; return ($answer -match '^(y|yes)$') }
    }
}

Import-CommonHelpers
Add-CommonFallbacks

Write-Host "Windows Script Distribution - Uninstall" -ForegroundColor Yellow
Write-Host "This placeholder does not remove files, apps, settings, or accounts."

Write-Section "Environment"
$adminText = if (Test-IsAdmin) { "Yes" } else { "No" }
Write-Host "Running as admin: $adminText"
Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

Write-Section "Confirmation"
if (-not (Confirm-Continue -Prompt "Continue with the uninstall placeholder?")) {
    Write-WarningMessage "Uninstall placeholder cancelled by user."
    return
}

Write-Section "Uninstall Plan"
Write-Host "Future uninstall step placeholder: inspect installed project artifacts."
Write-Host "Future uninstall step placeholder: prompt before removing generated files."
Write-Host "Future uninstall step placeholder: report what was left in place."

Write-Section "Complete"
Write-Success "Uninstall placeholder completed without removing anything."
