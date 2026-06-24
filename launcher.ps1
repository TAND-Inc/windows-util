#Requires -Version 5.1
<#
.SYNOPSIS
    Public WAN bootstrapper for the shared WPF Windows Setup Toolkit engine.

.DESCRIPTION
    Intended public entry point:

        irm https://get.tand.us/launcher | iex

    This bootstrapper fetches the shared WPF engine from the public base URL and
    runs it in WAN mode. The engine itself is also exportable for LAN offline use.
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

$engineUrl = "$($WanBaseUrl.TrimEnd('/'))/lib/wpf-menu-engine.ps1"
$engine = Invoke-RestMethod -Uri $engineUrl -UseBasicParsing

& ([scriptblock]::Create($engine)) `
    -Mode $Mode `
    -ManifestUrl $ManifestUrl `
    -BaseUrl $BaseUrl `
    -LanBaseUrl $LanBaseUrl `
    -WanBaseUrl $WanBaseUrl `
    -OfflinePreferred:$OfflinePreferred
