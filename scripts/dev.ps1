#Requires -Version 5.1
<#
.SYNOPSIS
    Development and testing entry point for the Windows script distribution project.

.DESCRIPTION
    This script is intended for non-destructive validation while developing the
    distribution project. It can be run locally or through:

        irm https://scripts.example.com/dev | iex

.EXAMPLE
    .\dev.ps1

.EXAMPLE
    irm https://scripts.example.com/dev | iex
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

Write-Host "Windows Script Distribution - Development/Test" -ForegroundColor Magenta
Write-Host "This entry point is for development and validation only."

Write-Section "Environment"
$adminText = if (Test-IsAdmin) { "Yes" } else { "No" }
Write-Host "Running as admin: $adminText"
Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

Write-Section "Placeholder Test"
Write-Host "Checking that the script can load helpers or fallback helpers."
Write-Success "Development placeholder test completed without changes."

Write-Section "Complete"
Write-Success "Dev/test script completed cleanly."
