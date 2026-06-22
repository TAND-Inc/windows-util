#Requires -Version 5.1
<#
.SYNOPSIS
    Public install entry point for the Windows script distribution project.

.DESCRIPTION
    This script is safe to run locally or through:

        irm https://scripts.example.com/install | iex

    It prints environment details and placeholder setup sections. It does not
    make destructive changes.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    irm https://scripts.example.com/install | iex
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

Write-Host "Windows Script Distribution - Install" -ForegroundColor Cyan
Write-Host "Placeholder domain: scripts.example.com"

Write-Section "Environment"
$isAdmin = Test-IsAdmin
$adminText = if ($isAdmin) { "Yes" } else { "No" }
Write-Host "Running as admin: $adminText"
Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

if (-not $isAdmin) {
    Write-WarningMessage "Some future setup steps may require an elevated PowerShell session."
}

Write-Section "Setup Plan"
Write-Host "No destructive changes are performed by this placeholder installer."
Write-Host "Future setup step placeholder: validate prerequisites."
Write-Host "Future setup step placeholder: apply selected Windows configuration."
Write-Host "Future setup step placeholder: install approved tools."

Write-Section "Complete"
Write-Success "Install placeholder completed cleanly."
