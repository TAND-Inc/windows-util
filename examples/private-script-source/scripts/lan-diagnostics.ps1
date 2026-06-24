#Requires -Version 5.1
Write-Host "Example LAN diagnostics placeholder." -ForegroundColor Cyan
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "Current user: $env:USERDOMAIN\$env:USERNAME"
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "OS version: $([System.Environment]::OSVersion.VersionString)"
