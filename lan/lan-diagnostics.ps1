#Requires -Version 5.1
<#
.SYNOPSIS
    Safe LAN-only diagnostic script.

.DESCRIPTION
    Intended LAN-only usage:

        irm http://scripts.home.arpa:8085/lan/lan-diagnostics.ps1 | iex

    This script prints local environment details and makes no changes.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'TAND LAN Diagnostics' -ForegroundColor Cyan
Write-Host ''
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "Current user: $env:USERDOMAIN\$env:USERNAME"
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "OS version: $([System.Environment]::OSVersion.VersionString)"

Write-Host ''
Write-Host 'Local IP addresses:'
try {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*'
        } |
        Sort-Object InterfaceAlias, IPAddress |
        ForEach-Object {
            Write-Host " - $($_.IPAddress) ($($_.InterfaceAlias))"
        }
} catch {
    [System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME) |
        Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
        ForEach-Object {
            Write-Host " - $($_.IPAddressToString)"
        }
}
